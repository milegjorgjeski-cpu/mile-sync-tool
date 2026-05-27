import 'package:hive/hive.dart';

part 'models.g.dart';

// ─── Enums ─────────────────────────────────────────────────────────────────

enum AudioFormat { mp3, wav, flac, aac, m4a }
enum StemSource { moises, uvr, demucs, manual }
enum LyricsFormat { txt, lrc }
enum ExportFormat { mp3WithSylt, mp3Plain, lrcFile, txtFile, allFormats }
enum ProjectStatus { empty, hasAudio, hasLyrics, hasSynced, hasStems, readyToExport }

// ─── LyricLine ─────────────────────────────────────────────────────────────

@HiveType(typeId: 0)
class LyricLine extends HiveObject {
  @HiveField(0)
  final int index;

  @HiveField(1)
  String text;

  @HiveField(2)
  int? startMs;   // milliseconds from track start

  @HiveField(3)
  int? endMs;

  @HiveField(4)
  bool isChorus;

  @HiveField(5)
  List<WordTimestamp>? words;  // optional word-level sync

  LyricLine({
    required this.index,
    required this.text,
    this.startMs,
    this.endMs,
    this.isChorus = false,
    this.words,
  });

  bool get isSynced => startMs != null;

  String get lrcTimestamp {
    if (startMs == null) return '[00:00.00]';
    final m = startMs! ~/ 60000;
    final s = (startMs! % 60000) ~/ 1000;
    final cs = (startMs! % 1000) ~/ 10;
    return '[${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}.${cs.toString().padLeft(2, '0')}]';
  }

  LyricLine copyWith({
    String? text,
    int? startMs,
    int? endMs,
    bool? isChorus,
    List<WordTimestamp>? words,
  }) {
    return LyricLine(
      index: index,
      text: text ?? this.text,
      startMs: startMs ?? this.startMs,
      endMs: endMs ?? this.endMs,
      isChorus: isChorus ?? this.isChorus,
      words: words ?? this.words,
    );
  }
}

// ─── WordTimestamp ──────────────────────────────────────────────────────────

@HiveType(typeId: 1)
class WordTimestamp extends HiveObject {
  @HiveField(0)
  final String word;

  @HiveField(1)
  final int startMs;

  @HiveField(2)
  final int endMs;

  WordTimestamp({
    required this.word,
    required this.startMs,
    required this.endMs,
  });
}

// ─── StemSet ────────────────────────────────────────────────────────────────

@HiveType(typeId: 2)
class StemSet extends HiveObject {
  @HiveField(0)
  String? vocalsPath;

  @HiveField(1)
  String? drumsPath;

  @HiveField(2)
  String? bassPath;

  @HiveField(3)
  String? otherPath;

  @HiveField(4)
  StemSource source;

  StemSet({
    this.vocalsPath,
    this.drumsPath,
    this.bassPath,
    this.otherPath,
    this.source = StemSource.manual,
  });

  bool get hasVocals => vocalsPath != null;
  bool get hasDrums => drumsPath != null;
  bool get hasBass => bassPath != null;
  bool get hasOther => otherPath != null;

  bool get hasAll => hasVocals && hasDrums && hasBass && hasOther;

  List<String> get availableStems {
    final stems = <String>[];
    if (hasVocals) stems.add('vocals');
    if (hasDrums) stems.add('drums');
    if (hasBass) stems.add('bass');
    if (hasOther) stems.add('other');
    return stems;
  }

  String? pathForStem(String name) {
    switch (name) {
      case 'vocals': return vocalsPath;
      case 'drums': return drumsPath;
      case 'bass': return bassPath;
      case 'other': return otherPath;
      default: return null;
    }
  }
}

// ─── TransposeSettings ──────────────────────────────────────────────────────

@HiveType(typeId: 3)
class TransposeSettings extends HiveObject {
  @HiveField(0)
  int semitones;  // -12 to +12

  @HiveField(1)
  bool preserveTempo;

  @HiveField(2)
  bool skipDrums;  // Always true by design

  TransposeSettings({
    this.semitones = 0,
    this.preserveTempo = true,
    this.skipDrums = true,
  });
}

// ─── TrimSettings ───────────────────────────────────────────────────────────

@HiveType(typeId: 4)
class TrimSettings extends HiveObject {
  @HiveField(0)
  int startMs;

  @HiveField(1)
  int endMs;

  @HiveField(2)
  bool removeSilence;

  TrimSettings({
    this.startMs = 0,
    this.endMs = 0,
    this.removeSilence = false,
  });

  Duration get startDuration => Duration(milliseconds: startMs);
  Duration get endDuration => Duration(milliseconds: endMs);
}

// ─── CrossfadeSettings ──────────────────────────────────────────────────────

@HiveType(typeId: 5)
class CrossfadeSettings extends HiveObject {
  @HiveField(0)
  int fadeInMs;

  @HiveField(1)
  int fadeOutMs;

  @HiveField(2)
  bool enabled;

  CrossfadeSettings({
    this.fadeInMs = 0,
    this.fadeOutMs = 0,
    this.enabled = false,
  });
}

// ─── ExportSettings ─────────────────────────────────────────────────────────

@HiveType(typeId: 6)
class ExportSettings extends HiveObject {
  @HiveField(0)
  bool embedSylt;

  @HiveField(1)
  bool embedUslt;

  @HiveField(2)
  bool exportLrc;

  @HiveField(3)
  bool exportTxt;

  @HiveField(4)
  bool ketronStructure;

  @HiveField(5)
  String bitrate;

  @HiveField(6)
  bool exportStems;

  ExportSettings({
    this.embedSylt = true,
    this.embedUslt = true,
    this.exportLrc = true,
    this.exportTxt = false,
    this.ketronStructure = false,
    this.bitrate = '256k',
    this.exportStems = false,
  });
}

// ─── Project ────────────────────────────────────────────────────────────────

@HiveType(typeId: 7)
class Project extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String? audioPath;

  @HiveField(3)
  AudioFormat? audioFormat;

  @HiveField(4)
  int durationMs;

  @HiveField(5)
  List<LyricLine> lyrics;

  @HiveField(6)
  StemSet? stems;

  @HiveField(7)
  TransposeSettings transpose;

  @HiveField(8)
  TrimSettings trim;

  @HiveField(9)
  CrossfadeSettings crossfade;

  @HiveField(10)
  ExportSettings exportSettings;

  @HiveField(11)
  DateTime createdAt;

  @HiveField(12)
  DateTime updatedAt;

  @HiveField(13)
  String? artist;

  @HiveField(14)
  String? album;

  @HiveField(15)
  bool lyricsAreSynced;

  Project({
    required this.id,
    required this.name,
    this.audioPath,
    this.audioFormat,
    this.durationMs = 0,
    List<LyricLine>? lyrics,
    this.stems,
    TransposeSettings? transpose,
    TrimSettings? trim,
    CrossfadeSettings? crossfade,
    ExportSettings? exportSettings,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.artist,
    this.album,
    this.lyricsAreSynced = false,
  })  : lyrics = lyrics ?? [],
        transpose = transpose ?? TransposeSettings(),
        trim = trim ?? TrimSettings(),
        crossfade = crossfade ?? CrossfadeSettings(),
        exportSettings = exportSettings ?? ExportSettings(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  ProjectStatus get status {
    if (audioPath == null) return ProjectStatus.empty;
    if (stems != null && stems!.hasAll) {
      if (lyricsAreSynced) return ProjectStatus.readyToExport;
      return ProjectStatus.hasStems;
    }
    if (lyricsAreSynced) return ProjectStatus.hasSynced;
    if (lyrics.isNotEmpty) return ProjectStatus.hasLyrics;
    return ProjectStatus.hasAudio;
  }

  Duration get duration => Duration(milliseconds: durationMs);
}
