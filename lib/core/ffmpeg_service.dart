// lib/core/ffmpeg_service.dart
// Wraps ffmpeg_kit_flutter for all audio operations

import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'models.dart';

/// Thin wrapper around ffmpeg-kit that runs ffmpeg commands
/// via Process.run (requires ffmpeg binary on device, or ffmpeg_kit_flutter).
///
/// On Android, use ffmpeg_kit_flutter in pubspec.yaml:
///   ffmpeg_kit_flutter: ^6.0.3
/// and replace Process.run with FFmpegKit.execute
class FfmpegService {
  static Future<Directory> get _workDir async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'mile_work'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  static Future<String> get _workPath async {
    return (await _workDir).path;
  }

  // ── Private: run command ──────────────────────────────────
  static Future<ProcessingResult> _run(List<String> args) async {
    try {
      // When using ffmpeg_kit_flutter, replace with:
      // final session = await FFmpegKit.execute(args.join(' '));
      // final rc = await session.getReturnCode();
      // return ProcessingResult(success: ReturnCode.isSuccess(rc), ...);
      final result = await Process.run('ffmpeg', args);
      if (result.exitCode == 0) {
        return ProcessingResult(success: true);
      } else {
        return ProcessingResult.fail(result.stderr.toString());
      }
    } catch (e) {
      return ProcessingResult.fail('FFmpeg error: $e');
    }
  }

  // ── Probe duration ─────────────────────────────────────────
  static Future<Duration?> probeDuration(String filePath) async {
    try {
      final result = await Process.run('ffprobe', [
        '-v', 'quiet',
        '-show_entries', 'format=duration',
        '-of', 'default=noprint_wrappers=1:nokey=1',
        filePath,
      ]);
      if (result.exitCode == 0) {
        final secs = double.tryParse(result.stdout.toString().trim());
        if (secs != null) {
          return Duration(milliseconds: (secs * 1000).round());
        }
      }
    } catch (_) {}
    return null;
  }

  // ── Convert to MP3 ─────────────────────────────────────────
  static Future<ProcessingResult> toMp3(
    String inputPath,
    String outputPath, {
    int bitrateKbps = 320,
  }) async {
    return _run([
      '-y', '-i', inputPath,
      '-codec:a', 'libmp3lame',
      '-b:a', '${bitrateKbps}k',
      '-id3v2_version', '3',
      outputPath,
    ]);
  }

  // ── Transpose pitch (pitch shift without tempo change) ────
  static Future<ProcessingResult> transposePitch(
    String inputPath,
    String outputPath, {
    required int semitones,
    int bitrateKbps = 320,
  }) async {
    // rubberband filter: pitch shift by semitones
    // tempo=1 (preserve tempo), pitch=2^(semitones/12)
    final pitchRatio = _semitoneRatio(semitones);
    return _run([
      '-y', '-i', inputPath,
      '-filter:a',
      'rubberband=pitch=$pitchRatio:tempo=1',
      '-codec:a', 'libmp3lame',
      '-b:a', '${bitrateKbps}k',
      outputPath,
    ]);
  }

  static double _semitoneRatio(int semitones) {
    return (semitones >= 0)
        ? 1.0 * (1 << (semitones ~/ 12)) * _semitoneFraction(semitones % 12)
        : 1.0 / _semitoneRatio(-semitones);
  }

  static double _semitoneFraction(int s) {
    // 2^(s/12) approximation
    return (s == 0) ? 1.0 : _pow2(s / 12.0);
  }

  static double _pow2(double exp) => double.parse(
        (1.0 * (1 << exp.floor()) * (1 + (exp - exp.floor()) * 0.693)).toStringAsFixed(6),
      );

  // ── Trim audio ────────────────────────────────────────────
  static Future<ProcessingResult> trim(
    String inputPath,
    String outputPath, {
    required Duration start,
    Duration? end,
  }) async {
    final args = [
      '-y',
      '-i', inputPath,
      '-ss', _durationToFfmpeg(start),
    ];
    if (end != null) {
      final duration = end - start;
      args.addAll(['-t', _durationToFfmpeg(duration)]);
    }
    args.addAll(['-codec:a', 'copy', outputPath]);
    return _run(args);
  }

  // ── Apply fade in/out ────────────────────────────────────
  static Future<ProcessingResult> applyFades(
    String inputPath,
    String outputPath, {
    double fadeInSeconds = 0,
    double fadeOutSeconds = 0,
    Duration? totalDuration,
  }) async {
    var filter = '';
    final parts = <String>[];

    if (fadeInSeconds > 0) {
      parts.add('afade=t=in:st=0:d=$fadeInSeconds');
    }
    if (fadeOutSeconds > 0 && totalDuration != null) {
      final startTime =
          totalDuration.inMilliseconds / 1000.0 - fadeOutSeconds;
      if (startTime > 0) {
        parts.add('afade=t=out:st=${startTime.toStringAsFixed(3)}:d=$fadeOutSeconds');
      }
    }

    if (parts.isEmpty) {
      return ProcessingResult.ok(inputPath, message: 'No fades to apply');
    }

    filter = parts.join(',');
    return _run([
      '-y', '-i', inputPath,
      '-filter:a', filter,
      '-codec:a', 'libmp3lame', '-b:a', '320k',
      outputPath,
    ]);
  }

  // ── Mix stems back to stereo ──────────────────────────────
  static Future<ProcessingResult> mixStems(
    List<String> stemPaths,
    String outputPath, {
    int bitrateKbps = 320,
  }) async {
    if (stemPaths.isEmpty) return ProcessingResult.fail('No stems to mix');

    final args = <String>['-y'];
    for (final path in stemPaths) {
      args.addAll(['-i', path]);
    }

    // amix filter
    final count = stemPaths.length;
    args.addAll([
      '-filter_complex',
      'amix=inputs=$count:duration=longest:normalize=0',
      '-codec:a', 'libmp3lame',
      '-b:a', '${bitrateKbps}k',
      outputPath,
    ]);
    return _run(args);
  }

  // ── Remove silence from start ────────────────────────────
  static Future<ProcessingResult> removeLeadingSilence(
    String inputPath,
    String outputPath, {
    double silenceThresholdDb = -50,
    double minSilenceDuration = 0.5,
  }) async {
    return _run([
      '-y', '-i', inputPath,
      '-filter:a',
      'silenceremove=start_periods=1:start_silence=${minSilenceDuration}:start_threshold=${silenceThresholdDb}dB',
      '-codec:a', 'libmp3lame', '-b:a', '320k',
      outputPath,
    ]);
  }

  // ── Embed ID3 metadata ────────────────────────────────────
  static Future<ProcessingResult> embedMetadata(
    String inputPath,
    String outputPath, {
    String? title,
    String? artist,
    String? album,
    String? comment,
  }) async {
    final metaArgs = <String>[];
    if (title != null) metaArgs.addAll(['-metadata', 'title=$title']);
    if (artist != null) metaArgs.addAll(['-metadata', 'artist=$artist']);
    if (album != null) metaArgs.addAll(['-metadata', 'album=$album']);
    if (comment != null) metaArgs.addAll(['-metadata', 'comment=$comment']);

    return _run([
      '-y', '-i', inputPath,
      ...metaArgs,
      '-codec:a', 'copy',
      '-id3v2_version', '3',
      outputPath,
    ]);
  }

  // ── Helper ───────────────────────────────────────────────
  static String _durationToFfmpeg(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final ms = d.inMilliseconds.remainder(1000).toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }

  static Future<String> tempFile(String name) async {
    return p.join(await _workPath, name);
  }
}
