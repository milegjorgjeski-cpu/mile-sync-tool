import 'dart:io';
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

  Future<ExportResult> exportProject({
    required Project project,
    void Function(double progress, String status)? onProgress,
  }) async {
    try {
      onProgress?.call(0.0, 'Preparing export…');

      final outputDir = await _createOutputDir(project.name, project.exportSettings.ketronStructure);
      final exportedFiles = <String>[];
      final safeTitle = _sanitizeFilename(project.name);

      onProgress?.call(0.1, 'Processing audio…');
      String? audioPath = project.audioPath;
      if (audioPath == null) {
        return const ExportResult(success: false, errorMessage: 'No audio file');
      }

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

      if (project.transpose.semitones != 0 && project.stems != null) {
        onProgress?.call(0.4, 'Transposing (drums excluded)…');
        audioPath = await _buildTransposedMix(project: project, onProgress: onProgress) ?? audioPath;
      }

      onProgress?.call(0.6, 'Writing MP3…');
      final mp3Dir = project.exportSettings.ketronStructure
          ? p.join(outputDir, 'audio')
          : outputDir;
      await Directory(mp3Dir).create(recursive: true);

      final finalMp3Path = p.join(mp3Dir, '$safeTitle.mp3');

      if (project.exportSettings.embedSylt && project.lyricsAreSynced) {
        final tempMp3 = await _convertToMp3Clean(audioPath, project.exportSettings.bitrate);
        if (tempMp3 != null) {
          await _embedId3Tags(inputPath: tempMp3, outputPath: finalMp3Path, project: project);
          exportedFiles.add(finalMp3Path);
        }
      } else {
        final converted = await _audio.convertToMp3(inputPath: audioPath, bitrate: project.exportSettings.bitrate);
        if (converted != null) {
          await File(converted).copy(finalMp3Path);
          exportedFiles.add(finalMp3Path);
        }
      }

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

      if (project.exportSettings.exportTxt) {
        final txtFile = await _lyrics.saveTxtFile(
          project.lyrics,
          outputDir: outputDir,
          fileName: safeTitle,
        );
        exportedFiles.add(txtFile.path);
      }

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
      return ExportResult(success: false, errorMessage: e.toString());
    }
  }

  Future<String?> _buildTransposedMix({
    required Project project,
    void Function(double, String)? onProgress,
  }) async {
    final stems = project.stems!;
    final semitones = project.transpose.semitones;
    final bitrate = project.exportSettings.bitrate;
    final stemPaths = <String>[];

    if (stems.hasDrums) stemPaths.add(stems.drumsPath!);

    if (stems.hasBass) {
      final transposed = await _audio.transposeStem(
        inputPath: stems.bassPath!, semitones: semitones,
        preserveTempo: project.transpose.preserveTempo, bitrate: bitrate);
      if (transposed != null) stemPaths.add(transposed);
    }

    if (stems.hasOther) {
      final transposed = await _audio.transposeStem(
        inputPath: stems.otherPath!, semitones: semitones,
        preserveTempo: project.transpose.preserveTempo, bitrate: bitrate);
      if (transposed != null) stemPaths.add(transposed);
    }

    if (stems.hasVocals) stemPaths.add(stems.vocalsPath!);

    if (stemPaths.isEmpty) return null;
    return _audio.mixStems(stemPaths: stemPaths, outputBitrate: bitrate);
  }

  Future<void> _embedId3Tags({
    required String inputPath,
    required String outputPath,
    required Project project,
  }) async {
    final sourceBytes = await File(inputPath).readAsBytes();
    final id3Bytes = _buildId3v2Tag(project);

    int audioDataOffset = 0;
    if (sourceBytes.length > 10 &&
        sourceBytes[0] == 0x49 && sourceBytes[1] == 0x44 && sourceBytes[2] == 0x33) {
      final tagSize = ((sourceBytes[6] & 0x7F) << 21) |
          ((sourceBytes[7] & 0x7F) << 14) |
          ((sourceBytes[8] & 0x7F) << 7) |
          (sourceBytes[9] & 0x7F);
      audioDataOffset = 10 + tagSize;
    }

    final audioData = sourceBytes.sublist(audioDataOffset);
    final output = File(outputPath);
    final sink = output.openWrite();
    sink.add(id3Bytes);
    sink.add(audioData);
    await sink.close();
  }

  List<int> _buildId3v2Tag(Project project) {
    final frames = <List<int>>[];
    frames.add(_buildTextFrame('TIT2', project.name));
    if (project.artist != null) frames.add(_buildTextFrame('TPE1', project.artist!));
    if (project.album != null) frames.add(_buildTextFrame('TALB', project.album!));
    if (project.transpose.semitones != 0) {
      final sign = project.transpose.semitones > 0 ? '+' : '';
      frames.add(_buildTextFrame('TKEY', '$sign${project.transpose.semitones}st'));
    }
    if (project.exportSettings.embedSylt && project.lyricsAreSynced) {
      frames.add(_buildId3Frame('SYLT', LyricsService().buildSyltFrame(project.lyrics)));
    }
    if (project.exportSettings.embedUslt && project.lyrics.isNotEmpty) {
      frames.add(_buildId3Frame('USLT', LyricsService().buildUsltFrame(project.lyrics)));
    }

    final frameData = frames.expand((f) => f).toList();
    final header = <int>[];
    header.addAll([0x49, 0x44, 0x33]);
    header.addAll([0x04, 0x00]);
    header.add(0x00);
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
    frame.addAll(frameId.codeUnits);
    final size = payload.length;
    frame.add((size >> 24) & 0xFF);
    frame.add((size >> 16) & 0xFF);
    frame.add((size >> 8) & 0xFF);
    frame.add(size & 0xFF);
    frame.addAll([0x00, 0x00]);
    frame.addAll(payload);
    return frame;
  }

  Future<String?> _convertToMp3Clean(String inputPath, String bitrate) async {
    if (inputPath.toLowerCase().endsWith('.mp3')) return inputPath;
    return _audio.convertToMp3(inputPath: inputPath, bitrate: bitrate);
  }

  Future<String> _createOutputDir(String projectName, bool ketronStructure) async {
    final baseDir = Directory(
      '/storage/emulated/0/Music/MileSync/${_sanitizeFilename(projectName)}',
    );
    await baseDir.create(recursive: true);
    return baseDir.path;
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
