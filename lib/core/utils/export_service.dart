import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../data/models/models.dart';
import 'audio_service.dart';
import 'lyrics_service.dart';

class ExportResult {
  final bool success;
  final String? outputDir;
  final List<String> exportedFiles;
  final String? errorMessage;

  const ExportResult({
    required this.success,
    this.outputDir,
    this.exportedFiles = const [],
    this.errorMessage,
  });
}

class ExportService {
  static final ExportService _instance = ExportService._internal();
  factory ExportService() => _instance;
  ExportService._internal();

  final _audio = AudioService();
  final _lyrics = LyricsService();

  // ── Main export entry point ───────────────────────────────────────────────

  Future<ExportResult> exportProject({
    required Project project,
    void Function(double progress, String status)? onProgress,
  }) async {
    try {
      onProgress?.call(0.0, 'Preparing export…');

      final outputDir = await _createOutputDir(project.name, project.exportSettings.ketronStructure);
      final exportedFiles = <String>[];
      final safeTitle = _sanitizeFilename(project.name);

      // Step 1: Build audio (apply trim + fades)
      onProgress?.call(0.1, 'Processing audio…');
      String? audioPath = project.audioPath;
      if (audioPath == null) {
        return const ExportResult(success: false, errorMessage: 'No audio file');
      }

      // Trim
      if (project.trim.startMs > 0 || project.trim.endMs > 0) {
        onProgress?.call(0.2, 'Trimming audio…');
        final trimmed = await _audio.trimAudio(
          inputPath: audioPath,
          startMs: project.trim.startMs,
          endMs: project.trim.endMs > 0 ? project.trim.endMs : project.durationMs,
          bitrate: project.exportSettings.bitrate,
        );
        if (trimmed != null) audioPath = trimmed;
      }

      // Fades
      if (project.crossfade.enabled) {
        onProgress?.call(0.3, 'Applying fades…');
        final faded = await _audio.applyFades(
          inputPath: audioPath,
          fadeInMs: project.crossfade.fadeInMs,
          fadeOutMs: project.crossfade.fadeOutMs,
          totalDurationMs: project.durationMs,
          bitrate: project.exportSettings.bitrate,
        );
        if (faded != null) audioPath = faded;
      }

      // Transpose (only if stems available)
      if (project.transpose.semitones != 0 && project.stems != null) {
        onProgress?.call(0.4, 'Transposing (drums excluded)…');
        audioPath = await _buildTransposedMix(
          project: project,
          onProgress: onProgress,
        ) ?? audioPath;
      }

      // Step 2: Export MP3
      onProgress?.call(0.6, 'Writing MP3…');
      final mp3Dir = project.exportSettings.ketronStructure
          ? p.join(outputDir, 'audio')
          : outputDir;
      await Directory(mp3Dir).create(recursive: true);

      final finalMp3Path = p.join(mp3Dir, '$safeTitle.mp3');

      if (project.exportSettings.embedSylt && project.lyricsAreSynced) {
        // Export with embedded SYLT
        final tempMp3 = await _convertToMp3Clean(audioPath, project.exportSettings.bitrate);
        if (tempMp3 != null) {
          await _embedId3Tags(
            inputPath: tempMp3,
            outputPath: finalMp3Path,
            project: project,
          );
          exportedFiles.add(finalMp3Path);
        }
      } else {
        // Copy/convert to output
        final converted = await _audio.convertToMp3(
          inputPath: audioPath,
          bitrate: project.exportSettings.bitrate,
        );
        if (converted != null) {
          await File(converted).copy(finalMp3Path);
          exportedFiles.add(finalMp3Path);
        }
      }

      // Step 3: LRC file
      if (project.exportSettings.exportLrc && project.lyricsAreSynced) {
        onProgress?.call(0.8, 'Exporting LRC…');
        final lrcDir = project.exportSettings.ketronStructure
            ? p.join(outputDir, 'lyrics')
            : outputDir;
        await Directory(lrcDir).create(recursive: true);
        final lrcFile = await _lyrics.saveLrcFile(
          project.lyrics,
          outputDir: lrcDir,
          fileName: safeTitle,
          title: project.name,
          artist: project.artist,
        );
        exportedFiles.add(lrcFile.path);
      }

      // Step 4: TXT file
      if (project.exportSettings.exportTxt) {
        final txtFile = await _lyrics.saveTxtFile(
          project.lyrics,
          outputDir: outputDir,
          fileName: safeTitle,
        );
        exportedFiles.add(txtFile.path);
      }

      // Step 5: Stems
      if (project.exportSettings.exportStems && project.stems != null) {
        onProgress?.call(0.9, 'Copying stems…');
        await _copyStems(project, outputDir, exportedFiles);
      }

      onProgress?.call(1.0, 'Export complete!');

      return ExportResult(
        success: true,
        outputDir: outputDir,
        exportedFiles: exportedFiles,
      );
    } catch (e) {
      return ExportResult(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }

  // ── Transpose + Mix ───────────────────────────────────────────────────────

  Future<String?> _buildTransposedMix({
    required Project project,
    void Function(double, String)? onProgress,
  }) async {
    final stems = project.stems!;
    final semitones = project.transpose.semitones;
    final bitrate = project.exportSettings.bitrate;
    final stemPaths = <String>[];

    // DRUMS: pass through unchanged — NEVER transpose
    if (stems.hasDrums) {
      stemPaths.add(stems.drumsPath!);
    }

    // BASS: transpose
    if (stems.hasBass) {
      onProgress?.call(0.42, 'Transposing bass…');
      final transposed = await _audio.transposeStem(
        inputPath: stems.bassPath!,
        semitones: semitones,
        preserveTempo: project.transpose.preserveTempo,
        bitrate: bitrate,
      );
      if (transposed != null) stemPaths.add(transposed);
    }

    // OTHER (melodic/harmonic): transpose
    if (stems.hasOther) {
      onProgress?.call(0.45, 'Transposing melodic stems…');
      final transposed = await _audio.transposeStem(
        inputPath: stems.otherPath!,
        semitones: semitones,
        preserveTempo: project.transpose.preserveTempo,
        bitrate: bitrate,
      );
      if (transposed != null) stemPaths.add(transposed);
    }

    // VOCALS: optionally transpose for backing track
    if (stems.hasVocals && project.transpose.semitones != 0) {
      onProgress?.call(0.48, 'Processing vocals…');
      // Keep original vocals unless karaoke mode
      stemPaths.add(stems.vocalsPath!);
    }

    if (stemPaths.isEmpty) return null;

    // Mix all stems
    return _audio.mixStems(stemPaths: stemPaths, outputBitrate: bitrate);
  }

  // ── ID3 SYLT embedding ────────────────────────────────────────────────────

  Future<void> _embedId3Tags({
    required String inputPath,
    required String outputPath,
    required Project project,
  }) async {
    // Read the source MP3
    final sourceBytes = await File(inputPath).readAsBytes();

    // Build ID3v2.4 tag with SYLT and USLT frames
    final id3Bytes = _buildId3v2Tag(project);

    // Remove existing ID3v2 header if present
    int audioDataOffset = 0;
    if (sourceBytes.length > 10 &&
        sourceBytes[0] == 0x49 && sourceBytes[1] == 0x44 && sourceBytes[2] == 0x33) {
      // ID3v2 found — skip it
      final tagSize = ((sourceBytes[6] & 0x7F) << 21) |
          ((sourceBytes[7] & 0x7F) << 14) |
          ((sourceBytes[8] & 0x7F) << 7) |
          (sourceBytes[9] & 0x7F);
      audioDataOffset = 10 + tagSize;
    }

    final audioData = sourceBytes.sublist(audioDataOffset);

    // Write: new ID3 tag + audio data
    final output = File(outputPath);
    final sink = output.openWrite();
    sink.add(id3Bytes);
    sink.add(audioData);
    await sink.close();
  }

  List<int> _buildId3v2Tag(Project project) {
    final frames = <List<int>>[];

    // TIT2 — Title
    frames.add(_buildTextFrame('TIT2', project.name));

    // TPE1 — Artist
    if (project.artist != null) {
      frames.add(_buildTextFrame('TPE1', project.artist!));
    }

    // TALB — Album
    if (project.album != null) {
      frames.add(_buildTextFrame('TALB', project.album!));
    }

    // TKEY — Key (from transpose)
    if (project.transpose.semitones != 0) {
      final sign = project.transpose.semitones > 0 ? '+' : '';
      frames.add(_buildTextFrame('TKEY', '$sign${project.transpose.semitones}st'));
    }

    // SYLT — Synchronized Lyrics
    if (project.exportSettings.embedSylt && project.lyricsAreSynced) {
      final syltPayload = LyricsService().buildSyltFrame(project.lyrics);
      frames.add(_buildId3Frame('SYLT', syltPayload));
    }

    // USLT — Unsynchronized Lyrics
    if (project.exportSettings.embedUslt && project.lyrics.isNotEmpty) {
      final usltPayload = LyricsService().buildUsltFrame(project.lyrics);
      frames.add(_buildId3Frame('USLT', usltPayload));
    }

    // Combine frames
    final frameData = frames.expand((f) => f).toList();

    // ID3v2.4 header
    final header = <int>[];
    header.addAll([0x49, 0x44, 0x33]);  // "ID3"
    header.addAll([0x04, 0x00]);         // version 2.4, no flags
    header.add(0x00);                    // flags

    // Syncsafe size encoding
    final size = frameData.length;
    header.add((size >> 21) & 0x7F);
    header.add((size >> 14) & 0x7F);
    header.add((size >> 7) & 0x7F);
    header.add(size & 0x7F);

    return [...header, ...frameData];
  }

  List<int> _buildTextFrame(String frameId, String text) {
    final encoded = [0x03, ...text.codeUnits.expand((c) => [c & 0xFF])];
    return _buildId3Frame(frameId, encoded);
  }

  List<int> _buildId3Frame(String frameId, List<int> payload) {
    final frame = <int>[];
    // Frame ID: 4 ASCII bytes
    frame.addAll(frameId.codeUnits);
    // Size: 4 bytes big-endian
    final size = payload.length;
    frame.add((size >> 24) & 0xFF);
    frame.add((size >> 16) & 0xFF);
    frame.add((size >> 8) & 0xFF);
    frame.add(size & 0xFF);
    // Flags: 2 bytes
    frame.addAll([0x00, 0x00]);
    // Payload
    frame.addAll(payload);
    return frame;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<String?> _convertToMp3Clean(String inputPath, String bitrate) async {
    if (inputPath.toLowerCase().endsWith('.mp3')) return inputPath;
    return _audio.convertToMp3(inputPath: inputPath, bitrate: bitrate);
  }

  Future<String> _createOutputDir(String projectName, bool ketronStructure) async {
    final docsDir = await getExternalStorageDirectory() ??
        await getApplicationDocumentsDirectory();
    final baseDir = p.join(docsDir.path, 'MileSyncExport', _sanitizeFilename(projectName));
    await Directory(baseDir).create(recursive: true);
    return baseDir;
  }

  Future<void> _copyStems(Project project, String outputDir, List<String> files) async {
    final stemsDir = p.join(outputDir, 'stems');
    await Directory(stemsDir).create(recursive: true);
    final stems = project.stems!;
    for (final name in stems.availableStems) {
      final src = stems.pathForStem(name);
      if (src != null) {
        final dst = p.join(stemsDir, '$name${p.extension(src)}');
        await File(src).copy(dst);
        files.add(dst);
      }
    }
  }

  String _sanitizeFilename(String name) {
    return name
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
  }
}
