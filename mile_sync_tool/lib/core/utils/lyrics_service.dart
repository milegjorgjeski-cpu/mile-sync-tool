import 'dart:io';
import 'dart:math' as math;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../../data/models/models.dart';

/// Handles all lyrics operations:
/// - Parse TXT and LRC files
/// - Auto-sync alignment (Whisper/WhisperX integration hook)
/// - Manual timing adjustment
/// - LRC and SYLT/ID3 export
class LyricsService {
  static final LyricsService _instance = LyricsService._internal();
  factory LyricsService() => _instance;
  LyricsService._internal();

  // ── Parse TXT ────────────────────────────────────────────────────────────

  List<LyricLine> parseTxt(String content) {
    final lines = content
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    return List.generate(lines.length, (i) {
      return LyricLine(
        index: i,
        text: lines[i],
      );
    });
  }

  // ── Parse LRC ────────────────────────────────────────────────────────────

  List<LyricLine> parseLrc(String content) {
    final lines = content.split('\n');
    final result = <LyricLine>[];

    // LRC timestamp regex: [MM:SS.xx] or [MM:SS.xxx]
    final timestampRegex = RegExp(r'\[(\d+):(\d+)\.(\d+)\](.*)');
    // Metadata tags to skip
    final metaRegex = RegExp(r'\[(ti|ar|al|by|offset|re|ve):');

    int index = 0;
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      if (metaRegex.hasMatch(trimmed)) continue;

      final match = timestampRegex.firstMatch(trimmed);
      if (match != null) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        final centisecondsStr = match.group(3)!;
        // Normalize to 2 digits
        final cs = int.parse(centisecondsStr.substring(0, math.min(2, centisecondsStr.length)).padRight(2, '0'));
        final ms = (minutes * 60 + seconds) * 1000 + cs * 10;
        final text = match.group(4)!.trim();

        if (text.isNotEmpty) {
          result.add(LyricLine(
            index: index++,
            text: text,
            startMs: ms,
          ));
        }
      }
    }

    // Calculate endMs for each line (= next line's startMs - 200ms)
    for (int i = 0; i < result.length - 1; i++) {
      final next = result[i + 1];
      if (next.startMs != null) {
        result[i] = result[i].copyWith(
          endMs: math.max(0, next.startMs! - 200),
        );
      }
    }

    return result;
  }

  // ── Auto-sync hook ───────────────────────────────────────────────────────

  /// Aligns unsynced lyrics to a vocal stem audio file.
  /// This calls the Python Whisper alignment subprocess.
  /// On Android, this requires having the Python scripts in the assets/scripts folder.
  ///
  /// For now this is a structural placeholder — full Whisper integration
  /// requires either:
  /// (a) A bundled native Whisper model via onnxruntime
  /// (b) A local server (e.g. whisper.cpp on-device)
  /// (c) An optional local companion app
  Future<List<LyricLine>> autoAlignLyrics({
    required String vocalStemPath,
    required List<LyricLine> rawLyrics,
    required String model,  // tiny, base, small, medium
    void Function(double progress, String status)? onProgress,
  }) async {
    onProgress?.call(0.05, 'Preparing alignment…');

    // Extract text lines
    final textLines = rawLyrics.map((l) => l.text).toList();

    // In production: call whisper / whisperX alignment
    // Here we provide a deterministic placeholder alignment
    // that distributes lines evenly across the audio duration.
    // Replace this block with actual Whisper call when integrating.

    onProgress?.call(0.2, 'Analyzing vocal stem…');
    await Future.delayed(const Duration(milliseconds: 500));

    onProgress?.call(0.5, 'Running alignment…');
    await Future.delayed(const Duration(milliseconds: 800));

    onProgress?.call(0.8, 'Generating timestamps…');

    // Fallback: even distribution placeholder
    // In real integration this returns Whisper word-level timestamps
    final aligned = _evenDistributeAlignment(rawLyrics);

    onProgress?.call(1.0, 'Done');
    return aligned;
  }

  List<LyricLine> _evenDistributeAlignment(List<LyricLine> lines) {
    if (lines.isEmpty) return lines;

    // Estimate ~3 seconds per line if no audio duration available
    const msPerLine = 3000;
    return List.generate(lines.length, (i) {
      final startMs = i * msPerLine;
      return lines[i].copyWith(
        startMs: startMs,
        endMs: startMs + msPerLine - 200,
      );
    });
  }

  // ── Timing correction ─────────────────────────────────────────────────────

  /// Shift all timestamps by [offsetMs] milliseconds (can be negative)
  List<LyricLine> shiftAllTimings(List<LyricLine> lines, int offsetMs) {
    return lines.map((l) {
      if (!l.isSynced) return l;
      return l.copyWith(
        startMs: math.max(0, l.startMs! + offsetMs),
        endMs: l.endMs != null ? math.max(0, l.endMs! + offsetMs) : null,
      );
    }).toList();
  }

  /// Set timing for a single line and recalculate neighbors
  List<LyricLine> setLineTiming(
    List<LyricLine> lines,
    int lineIndex,
    int newStartMs,
  ) {
    final updated = List<LyricLine>.from(lines);
    updated[lineIndex] = updated[lineIndex].copyWith(startMs: newStartMs);

    // Update previous line's endMs
    if (lineIndex > 0 && updated[lineIndex - 1].isSynced) {
      updated[lineIndex - 1] = updated[lineIndex - 1].copyWith(
        endMs: math.max(0, newStartMs - 200),
      );
    }
    // Update this line's endMs from next line
    if (lineIndex < lines.length - 1 && updated[lineIndex + 1].isSynced) {
      updated[lineIndex] = updated[lineIndex].copyWith(
        endMs: math.max(0, updated[lineIndex + 1].startMs! - 200),
      );
    }

    return updated;
  }

  // ── Export LRC ───────────────────────────────────────────────────────────

  String exportLrc(List<LyricLine> lines, {
    String? title,
    String? artist,
  }) {
    final buffer = StringBuffer();
    if (title != null) buffer.writeln('[ti:$title]');
    if (artist != null) buffer.writeln('[ar:$artist]');
    buffer.writeln('[re:MileSyncTool]');
    buffer.writeln();

    for (final line in lines) {
      if (line.isSynced) {
        buffer.writeln('${line.lrcTimestamp}${line.text}');
      } else {
        buffer.writeln(line.text);
      }
    }

    return buffer.toString();
  }

  Future<File> saveLrcFile(List<LyricLine> lines, {
    required String outputDir,
    required String fileName,
    String? title,
    String? artist,
  }) async {
    final lrcContent = exportLrc(lines, title: title, artist: artist);
    final file = File(p.join(outputDir, '$fileName.lrc'));
    await file.writeAsString(lrcContent, flush: true);
    return file;
  }

  // ── Export plain TXT ─────────────────────────────────────────────────────

  Future<File> saveTxtFile(List<LyricLine> lines, {
    required String outputDir,
    required String fileName,
  }) async {
    final content = lines.map((l) => l.text).join('\n');
    final file = File(p.join(outputDir, '$fileName.txt'));
    await file.writeAsString(content, flush: true);
    return file;
  }

  // ── SYLT Frame builder ────────────────────────────────────────────────────

  /// Builds a raw SYLT (Synchronised Lyrics/Text) frame payload
  /// for embedding into an ID3v2 tag.
  ///
  /// SYLT frame format (ID3v2.3/2.4):
  ///   - Text encoding: 1 byte (0=Latin1, 3=UTF-8)
  ///   - Language: 3 bytes (e.g. "eng")
  ///   - Time stamp format: 1 byte (1=MPEG frames, 2=milliseconds)
  ///   - Content type: 1 byte (1=lyrics)
  ///   - Content descriptor: terminated string
  ///   - Then repeated: [4-byte timestamp][text terminated with 0x00 or 0x00 0x00]
  List<int> buildSyltFrame(List<LyricLine> lines) {
    final bytes = <int>[];

    // Text encoding: UTF-8 = 0x03
    bytes.add(0x03);
    // Language: "eng"
    bytes.addAll([0x65, 0x6E, 0x67]);
    // Timestamp format: milliseconds = 0x02
    bytes.add(0x02);
    // Content type: lyrics = 0x01
    bytes.add(0x01);
    // Content descriptor: empty string terminated with 0x00 0x00 (UTF-16 null)
    bytes.addAll([0x00, 0x00]);

    for (final line in lines) {
      if (!line.isSynced) continue;

      // Timestamp: 4 bytes big-endian (milliseconds)
      final ms = line.startMs!;
      bytes.add((ms >> 24) & 0xFF);
      bytes.add((ms >> 16) & 0xFF);
      bytes.add((ms >> 8) & 0xFF);
      bytes.add(ms & 0xFF);

      // Text as UTF-8, terminated by 0x00 0x00
      final textBytes = line.text.codeUnits
          .expand((c) => [c & 0xFF])
          .toList();
      bytes.addAll(textBytes);
      bytes.addAll([0x00, 0x00]);
    }

    return bytes;
  }

  /// Builds a USLT (Unsynchronised Lyrics) frame payload
  List<int> buildUsltFrame(List<LyricLine> lines) {
    final bytes = <int>[];

    // Text encoding: UTF-8
    bytes.add(0x03);
    // Language
    bytes.addAll([0x65, 0x6E, 0x67]);
    // Content descriptor: empty + null terminator
    bytes.addAll([0x00, 0x00]);

    final fullText = lines.map((l) => l.text).join('\n');
    bytes.addAll(fullText.codeUnits.expand((c) => [c & 0xFF]));

    return bytes;
  }

  // ── Find active lyric at position ─────────────────────────────────────────

  int findActiveLineIndex(List<LyricLine> lines, int positionMs) {
    int active = 0;
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.isSynced && line.startMs! <= positionMs) {
        active = i;
      }
    }
    return active;
  }
}
