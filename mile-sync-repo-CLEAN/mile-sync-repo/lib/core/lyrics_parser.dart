// lib/core/lyrics_parser.dart
// Parses .txt and .lrc lyrics files into LyricsDocument

import 'dart:io';
import 'models.dart';

class LyricsParser {
  // ── Parse from file path ──────────────────────────────────
  static Future<LyricsDocument?> parseFile(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) return null;

    final content = await file.readAsString();
    final ext = filePath.toLowerCase().split('.').last;

    if (ext == 'lrc') {
      return parseLrc(content);
    } else {
      return parsePlainText(content);
    }
  }

  // ── Parse plain text ─────────────────────────────────────
  static LyricsDocument parsePlainText(String text) {
    final rawLines = text.split('\n');
    final lines = <LyricsLine>[];
    int idx = 0;

    for (final raw in rawLines) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) continue;
      lines.add(LyricsLine(index: idx++, text: trimmed));
    }

    return LyricsDocument(
      rawText: text,
      lines: lines,
      format: LyricsFormat.plain,
    );
  }

  // ── Parse LRC ─────────────────────────────────────────────
  // Format: [mm:ss.xx]Lyric text
  static LyricsDocument parseLrc(String lrcContent) {
    final lines = <LyricsLine>[];
    final rawLines = lrcContent.split('\n');
    int idx = 0;

    for (final raw in rawLines) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) continue;

      // Skip metadata tags like [ti:], [ar:], [by:]
      if (RegExp(r'^\[(?:ti|ar|al|by|offset|re|ve):').hasMatch(trimmed)) {
        continue;
      }

      // Parse time tag(s) + text
      final match = RegExp(r'^\[(\d+):(\d+)\.(\d+)\](.*)$').firstMatch(trimmed);
      if (match != null) {
        final mins = int.parse(match.group(1)!);
        final secs = int.parse(match.group(2)!);
        final centis = int.parse(match.group(3)!.padRight(2, '0').substring(0, 2));
        final text = match.group(4)!.trim();

        if (text.isEmpty) continue;

        final startTime = Duration(
          minutes: mins,
          seconds: secs,
          milliseconds: centis * 10,
        );

        lines.add(LyricsLine(
          index: idx++,
          text: text,
          startTime: startTime,
        ));
      } else if (!trimmed.startsWith('[')) {
        // Plain line without timestamp
        lines.add(LyricsLine(index: idx++, text: trimmed));
      }
    }

    // Fill in end times from next line's start time
    for (int i = 0; i < lines.length - 1; i++) {
      if (lines[i].startTime != null && lines[i + 1].startTime != null) {
        lines[i].endTime = lines[i + 1].startTime;
      }
    }

    return LyricsDocument(
      rawText: lrcContent,
      lines: lines,
      format: LyricsFormat.lrc,
    );
  }

  // ── Auto-align: apply Whisper timestamps to lyrics lines ──
  /// whisperSegments: List of {text, start(seconds), end(seconds)}
  static LyricsDocument applyWhisperAlignment(
    LyricsDocument original,
    List<WhisperSegment> segments,
  ) {
    final lines = List<LyricsLine>.from(original.lines);

    // Simple matching: match each lyrics line to nearest Whisper segment
    // by text similarity or sequential order
    final used = <int>{};

    for (int li = 0; li < lines.length; li++) {
      final lyricText = lines[li].text.toLowerCase().trim();

      // Try to find matching segment
      int bestMatch = -1;
      double bestScore = 0;

      for (int si = 0; si < segments.length; si++) {
        if (used.contains(si)) continue;
        final segText = segments[si].text.toLowerCase().trim();
        final score = _textSimilarity(lyricText, segText);
        if (score > bestScore) {
          bestScore = score;
          bestMatch = si;
        }
      }

      if (bestMatch >= 0 && bestScore > 0.3) {
        used.add(bestMatch);
        lines[li] = lines[li].copyWith(
          startTime: Duration(
            milliseconds: (segments[bestMatch].startSeconds * 1000).round(),
          ),
          endTime: Duration(
            milliseconds: (segments[bestMatch].endSeconds * 1000).round(),
          ),
        );
      }
    }

    // Fallback: fill unmatched lines sequentially from remaining segments
    final unusedSegs = segments
        .asMap()
        .entries
        .where((e) => !used.contains(e.key))
        .map((e) => e.value)
        .toList();

    int segIdx = 0;
    for (int li = 0; li < lines.length; li++) {
      if (!lines[li].isSynced && segIdx < unusedSegs.length) {
        lines[li] = lines[li].copyWith(
          startTime: Duration(
            milliseconds: (unusedSegs[segIdx].startSeconds * 1000).round(),
          ),
          endTime: Duration(
            milliseconds: (unusedSegs[segIdx].endSeconds * 1000).round(),
          ),
        );
        segIdx++;
      }
    }

    return LyricsDocument(
      rawText: original.rawText,
      lines: lines,
      format: original.format,
    );
  }

  // ── Simple text similarity (Jaccard on words) ─────────────
  static double _textSimilarity(String a, String b) {
    final setA = a.split(' ').toSet();
    final setB = b.split(' ').toSet();
    if (setA.isEmpty && setB.isEmpty) return 1.0;
    final intersection = setA.intersection(setB).length;
    final union = setA.union(setB).length;
    return union == 0 ? 0.0 : intersection / union;
  }
}

// ── Whisper segment model ─────────────────────────────────────
class WhisperSegment {
  final String text;
  final double startSeconds;
  final double endSeconds;

  const WhisperSegment({
    required this.text,
    required this.startSeconds,
    required this.endSeconds,
  });

  factory WhisperSegment.fromJson(Map<String, dynamic> json) {
    return WhisperSegment(
      text: json['text'] as String? ?? '',
      startSeconds: (json['start'] as num?)?.toDouble() ?? 0.0,
      endSeconds: (json['end'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
