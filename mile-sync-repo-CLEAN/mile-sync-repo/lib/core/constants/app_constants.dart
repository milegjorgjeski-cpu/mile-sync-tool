class AppConstants {
  AppConstants._();

  // ── Supported formats ──────────────────────────────────────────────────
  static const List<String> audioExtensions = ['mp3', 'wav', 'flac', 'aac', 'm4a'];
  static const List<String> lyricsExtensions = ['txt', 'lrc'];
  static const List<String> stemNames = ['vocals', 'drums', 'bass', 'other'];

  // ── Transpose limits ───────────────────────────────────────────────────
  static const int transposeMin = -12;
  static const int transposeMax = 12;

  // ── Whisper models ─────────────────────────────────────────────────────
  static const List<String> whisperModels = ['tiny', 'base', 'small', 'medium'];
  static const String defaultWhisperModel = 'base';

  // ── Crossfade limits (ms) ──────────────────────────────────────────────
  static const int crossfadeMin = 0;
  static const int crossfadeMax = 10000;
  static const int crossfadeDefault = 2000;

  // ── Export formats ─────────────────────────────────────────────────────
  static const List<String> exportBitrates = ['128k', '192k', '256k', '320k'];
  static const String defaultBitrate = '256k';

  // ── Hive box names ─────────────────────────────────────────────────────
  static const String projectsBox = 'projects';
  static const String settingsBox = 'settings';
  static const String recentFilesBox = 'recentFiles';

  // ── Settings keys ──────────────────────────────────────────────────────
  static const String keyDefaultBitrate = 'defaultBitrate';
  static const String keyDefaultModel = 'defaultWhisperModel';
  static const String keyOutputPath = 'outputPath';
  static const String keyKetronMode = 'ketronMode';

  // ── File structure ─────────────────────────────────────────────────────
  static const String exportFolderName = 'MileSyncExport';
  static const String ketronFolderName = 'Ketron';
  static const String stemsFolderName = 'stems';

  // ── UI ─────────────────────────────────────────────────────────────────
  static const double buttonHeight = 56.0;
  static const double cardRadius = 12.0;
  static const double pagePadding = 20.0;
  static const double sectionSpacing = 24.0;
}
