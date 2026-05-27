// GENERATED CODE - Manual stub (run build_runner for full generation)
// ignore_for_file: type=lint

part of 'models.dart';

// ─── LyricLineAdapter ──────────────────────────────────────────────────────
class LyricLineAdapter extends TypeAdapter<LyricLine> {
  @override
  final int typeId = 0;

  @override
  LyricLine read(BinaryReader reader) {
    return LyricLine(
      index: reader.read() as int,
      text: reader.read() as String,
      startMs: reader.read() as int?,
      endMs: reader.read() as int?,
      isChorus: reader.read() as bool,
      words: (reader.read() as List?)?.cast<WordTimestamp>(),
    );
  }

  @override
  void write(BinaryWriter writer, LyricLine obj) {
    writer.write(obj.index);
    writer.write(obj.text);
    writer.write(obj.startMs);
    writer.write(obj.endMs);
    writer.write(obj.isChorus);
    writer.write(obj.words);
  }
}

// ─── WordTimestampAdapter ──────────────────────────────────────────────────
class WordTimestampAdapter extends TypeAdapter<WordTimestamp> {
  @override
  final int typeId = 1;

  @override
  WordTimestamp read(BinaryReader reader) {
    return WordTimestamp(
      word: reader.read() as String,
      startMs: reader.read() as int,
      endMs: reader.read() as int,
    );
  }

  @override
  void write(BinaryWriter writer, WordTimestamp obj) {
    writer.write(obj.word);
    writer.write(obj.startMs);
    writer.write(obj.endMs);
  }
}

// ─── StemSetAdapter ────────────────────────────────────────────────────────
class StemSetAdapter extends TypeAdapter<StemSet> {
  @override
  final int typeId = 2;

  @override
  StemSet read(BinaryReader reader) {
    return StemSet(
      vocalsPath: reader.read() as String?,
      drumsPath: reader.read() as String?,
      bassPath: reader.read() as String?,
      otherPath: reader.read() as String?,
      source: StemSource.values[reader.read() as int],
    );
  }

  @override
  void write(BinaryWriter writer, StemSet obj) {
    writer.write(obj.vocalsPath);
    writer.write(obj.drumsPath);
    writer.write(obj.bassPath);
    writer.write(obj.otherPath);
    writer.write(obj.source.index);
  }
}

// ─── TransposeSettingsAdapter ──────────────────────────────────────────────
class TransposeSettingsAdapter extends TypeAdapter<TransposeSettings> {
  @override
  final int typeId = 3;

  @override
  TransposeSettings read(BinaryReader reader) {
    return TransposeSettings(
      semitones: reader.read() as int,
      preserveTempo: reader.read() as bool,
      skipDrums: reader.read() as bool,
    );
  }

  @override
  void write(BinaryWriter writer, TransposeSettings obj) {
    writer.write(obj.semitones);
    writer.write(obj.preserveTempo);
    writer.write(obj.skipDrums);
  }
}

// ─── TrimSettingsAdapter ───────────────────────────────────────────────────
class TrimSettingsAdapter extends TypeAdapter<TrimSettings> {
  @override
  final int typeId = 4;

  @override
  TrimSettings read(BinaryReader reader) {
    return TrimSettings(
      startMs: reader.read() as int,
      endMs: reader.read() as int,
      removeSilence: reader.read() as bool,
    );
  }

  @override
  void write(BinaryWriter writer, TrimSettings obj) {
    writer.write(obj.startMs);
    writer.write(obj.endMs);
    writer.write(obj.removeSilence);
  }
}

// ─── CrossfadeSettingsAdapter ─────────────────────────────────────────────
class CrossfadeSettingsAdapter extends TypeAdapter<CrossfadeSettings> {
  @override
  final int typeId = 5;

  @override
  CrossfadeSettings read(BinaryReader reader) {
    return CrossfadeSettings(
      fadeInMs: reader.read() as int,
      fadeOutMs: reader.read() as int,
      enabled: reader.read() as bool,
    );
  }

  @override
  void write(BinaryWriter writer, CrossfadeSettings obj) {
    writer.write(obj.fadeInMs);
    writer.write(obj.fadeOutMs);
    writer.write(obj.enabled);
  }
}

// ─── ExportSettingsAdapter ────────────────────────────────────────────────
class ExportSettingsAdapter extends TypeAdapter<ExportSettings> {
  @override
  final int typeId = 6;

  @override
  ExportSettings read(BinaryReader reader) {
    return ExportSettings(
      embedSylt: reader.read() as bool,
      embedUslt: reader.read() as bool,
      exportLrc: reader.read() as bool,
      exportTxt: reader.read() as bool,
      ketronStructure: reader.read() as bool,
      bitrate: reader.read() as String,
      exportStems: reader.read() as bool,
    );
  }

  @override
  void write(BinaryWriter writer, ExportSettings obj) {
    writer.write(obj.embedSylt);
    writer.write(obj.embedUslt);
    writer.write(obj.exportLrc);
    writer.write(obj.exportTxt);
    writer.write(obj.ketronStructure);
    writer.write(obj.bitrate);
    writer.write(obj.exportStems);
  }
}

// ─── ProjectAdapter ───────────────────────────────────────────────────────
class ProjectAdapter extends TypeAdapter<Project> {
  @override
  final int typeId = 7;

  @override
  Project read(BinaryReader reader) {
    return Project(
      id: reader.read() as String,
      name: reader.read() as String,
      audioPath: reader.read() as String?,
      audioFormat: reader.read() != null
          ? AudioFormat.values[reader.read() as int]
          : null,
      durationMs: reader.read() as int,
      lyrics: (reader.read() as List).cast<LyricLine>(),
      stems: reader.read() as StemSet?,
      transpose: reader.read() as TransposeSettings,
      trim: reader.read() as TrimSettings,
      crossfade: reader.read() as CrossfadeSettings,
      exportSettings: reader.read() as ExportSettings,
      createdAt: reader.read() as DateTime,
      updatedAt: reader.read() as DateTime,
      artist: reader.read() as String?,
      album: reader.read() as String?,
      lyricsAreSynced: reader.read() as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Project obj) {
    writer.write(obj.id);
    writer.write(obj.name);
    writer.write(obj.audioPath);
    writer.write(obj.audioFormat?.index);
    writer.write(obj.durationMs);
    writer.write(obj.lyrics);
    writer.write(obj.stems);
    writer.write(obj.transpose);
    writer.write(obj.trim);
    writer.write(obj.crossfade);
    writer.write(obj.exportSettings);
    writer.write(obj.createdAt);
    writer.write(obj.updatedAt);
    writer.write(obj.artist);
    writer.write(obj.album);
    writer.write(obj.lyricsAreSynced);
  }
}
