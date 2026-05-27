// lib/core/models.dart
// Central data models for Mile Sync Tool

// ─────────────────────────────────────────────────────────────
// Audio Track Model
// ─────────────────────────────────────────────────────────────

class AudioTrack {
  final String id;
  final String filePath;
  final String fileName;
  final AudioTrackType type;
  final Duration? duration;
  final int? sampleRate;
  final int? bitrate;

  const AudioTrack({
    required this.id,
    required this.filePath,
    required this.fileName,
    required this.type,
    this.duration,
    this.sampleRate,
    this.bitrate,
  });

  AudioTrack copyWith({
    Duration? duration,
    int? sampleRate,
    int? bitrate,
  }) {
    return AudioTrack(
      id: id,
      filePath: filePath,
      fileName: fileName,
      type: type,
      duration: duration ?? this.duration,
      sampleRate: sampleRate ?? this.sampleRate,
      bitrate: bitrate ?? this.bitrate,
    );
  }
}

enum AudioTrackType { main, vocalStem, drumsStem, bassStem, otherStem }

extension AudioTrackTypeLabel on AudioTrackType {
  String get label {
    switch (this) {
      case AudioTrackType.main:
        return 'Main Track';
      case AudioTrackType.vocalStem:
        return 'Vocals';
      case AudioTrackType.drumsStem:
        return 'Drums';
      case AudioTrackType.bassStem:
        return 'Bass';
      case AudioTrackType.otherStem:
        return 'Other';
    }
  }

  bool get isTransposable {
    return this == AudioTrackType.bassStem || this == AudioTrackType.otherStem;
  }
}

// ─────────────────────────────────────────────────────────────
// Lyrics Models
// ─────────────────────────────────────────────────────────────

class LyricsLine {
  final int index;
  final String text;
  Duration? startTime;
  Duration? endTime;
  bool isEdited;

  LyricsLine({
    required this.index,
    required this.text,
    this.startTime,
    this.endTime,
    this.isEdited = false,
  });

  bool get isSynced => startTime != null;

  LyricsLine copyWith({
    Duration? startTime,
    Duration? endTime,
    bool? isEdited,
  }) {
    return LyricsLine(
      index: index,
      text: text,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isEdited: isEdited ?? this.isEdited,
    );
  }

  /// Format as LRC line: [mm:ss.xx]text
  String toLrcLine() {
    if (startTime == null) return text;
    final t = startTime!;
    final mins = t.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = t.inSeconds.remainder(60).toString().padLeft(2, '0');
    final cents =
        (t.inMilliseconds.remainder(1000) ~/ 10).toString().padLeft(2, '0');
    return '[$mins:$secs.$cents]$text';
  }
}

class LyricsDocument {
  final String? rawText;
  final List<LyricsLine> lines;
  final LyricsFormat format;

  const LyricsDocument({
    this.rawText,
    required this.lines,
    required this.format,
  });

  bool get isSynced => lines.any((l) => l.isSynced);

  int get syncedCount => lines.where((l) => l.isSynced).length;

  String toLrc() {
    final buffer = StringBuffer();
    buffer.writeln('[ti:]');
    buffer.writeln('[ar:]');
    buffer.writeln('[by:Mile Sync Tool]');
    buffer.writeln();
    for (final line in lines) {
      buffer.writeln(line.toLrcLine());
    }
    return buffer.toString();
  }

  String toPlainText() {
    return lines.map((l) => l.text).join('\n');
  }
}

enum LyricsFormat { plain, lrc, srt }

// ─────────────────────────────────────────────────────────────
// Project Model
// ─────────────────────────────────────────────────────────────

class MileProject {
  final String id;
  String title;
  String artist;

  // Audio files
  AudioTrack? mainTrack;
  AudioTrack? vocalStem;
  AudioTrack? drumsStem;
  AudioTrack? bassStem;
  AudioTrack? otherStem;

  // Lyrics
  LyricsDocument? lyrics;

  // Processing state
  int transposeSemitones;
  TrimSettings trimSettings;
  CrossfadeSettings crossfadeSettings;

  // Project status
  ProjectStatus status;
  DateTime createdAt;
  DateTime updatedAt;

  MileProject({
    required this.id,
    required this.title,
    required this.artist,
    this.mainTrack,
    this.vocalStem,
    this.drumsStem,
    this.bassStem,
    this.otherStem,
    this.lyrics,
    this.transposeSemitones = 0,
    TrimSettings? trimSettings,
    CrossfadeSettings? crossfadeSettings,
    this.status = ProjectStatus.idle,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : trimSettings = trimSettings ?? TrimSettings(),
        crossfadeSettings = crossfadeSettings ?? CrossfadeSettings(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get hasAudio =>
      mainTrack != null ||
      vocalStem != null ||
      drumsStem != null ||
      bassStem != null ||
      otherStem != null;

  bool get hasStems =>
      vocalStem != null ||
      drumsStem != null ||
      bassStem != null ||
      otherStem != null;

  bool get hasLyrics => lyrics != null;

  bool get isSynced => lyrics?.isSynced ?? false;
}

enum ProjectStatus { idle, processing, done, error }

// ─────────────────────────────────────────────────────────────
// Trim Settings
// ─────────────────────────────────────────────────────────────

class TrimSettings {
  Duration startPoint;
  Duration? endPoint;
  bool removeLeadingSilence;

  TrimSettings({
    this.startPoint = Duration.zero,
    this.endPoint,
    this.removeLeadingSilence = false,
  });

  bool get hasTrim =>
      startPoint > Duration.zero ||
      endPoint != null ||
      removeLeadingSilence;
}

// ─────────────────────────────────────────────────────────────
// Crossfade Settings
// ─────────────────────────────────────────────────────────────

class CrossfadeSettings {
  double fadeInSeconds;
  double fadeOutSeconds;
  bool enabled;

  CrossfadeSettings({
    this.fadeInSeconds = 0.0,
    this.fadeOutSeconds = 0.0,
    this.enabled = false,
  });
}

// ─────────────────────────────────────────────────────────────
// Export Settings
// ─────────────────────────────────────────────────────────────

class ExportSettings {
  bool exportMp3;
  bool exportLrc;
  bool exportTxt;
  bool embedSylt;
  bool embedUslt;
  bool embedId3Metadata;
  bool exportStems;
  bool ketronFolderStructure;
  int mp3Bitrate; // kbps

  ExportSettings({
    this.exportMp3 = true,
    this.exportLrc = true,
    this.exportTxt = false,
    this.embedSylt = true,
    this.embedUslt = false,
    this.embedId3Metadata = true,
    this.exportStems = false,
    this.ketronFolderStructure = false,
    this.mp3Bitrate = 320,
  });
}

// ─────────────────────────────────────────────────────────────
// Processing Result
// ─────────────────────────────────────────────────────────────

class ProcessingResult {
  final bool success;
  final String? message;
  final String? outputPath;
  final List<String> warnings;

  const ProcessingResult({
    required this.success,
    this.message,
    this.outputPath,
    this.warnings = const [],
  });

  factory ProcessingResult.ok(String outputPath, {String? message}) {
    return ProcessingResult(
      success: true,
      outputPath: outputPath,
      message: message,
    );
  }

  factory ProcessingResult.fail(String message) {
    return ProcessingResult(success: false, message: message);
  }
}

// ─────────────────────────────────────────────────────────────
// Workflow Step
// ─────────────────────────────────────────────────────────────

enum WorkflowStep {
  importAudio,
  syncLyrics,
  transpose,
  cutAndCrossfade,
  export,
}

extension WorkflowStepLabel on WorkflowStep {
  String get label {
    switch (this) {
      case WorkflowStep.importAudio:
        return 'IMPORT';
      case WorkflowStep.syncLyrics:
        return 'SYNC';
      case WorkflowStep.transpose:
        return 'TRANSPOSE';
      case WorkflowStep.cutAndCrossfade:
        return 'CUT';
      case WorkflowStep.export:
        return 'EXPORT';
    }
  }

  String get description {
    switch (this) {
      case WorkflowStep.importAudio:
        return 'Import audio and lyrics files';
      case WorkflowStep.syncLyrics:
        return 'Auto-sync lyrics to vocal stem';
      case WorkflowStep.transpose:
        return 'Transpose pitch (stems only)';
      case WorkflowStep.cutAndCrossfade:
        return 'Trim, cut and crossfade';
      case WorkflowStep.export:
        return 'Export with ID3 / SYLT tags';
    }
  }
}
