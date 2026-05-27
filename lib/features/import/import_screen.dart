import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/audio_service.dart';
import '../../core/utils/lyrics_service.dart';
import '../../data/models/models.dart';
import '../../data/repositories/project_repository.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../lyrics_sync/lyrics_sync_screen.dart';

class ImportScreen extends StatefulWidget {
  final Project project;
  const ImportScreen({super.key, required this.project});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  late Project _project;
  final _repo = ProjectRepository();
  final _audioSvc = AudioService();
  final _lyricsSvc = LyricsService();
  bool _loadingAudio = false;
  bool _loadingLyrics = false;
  bool _loadingStem = false;

  @override
  void initState() {
    super.initState();
    _project = widget.project;
  }

  Future<void> _importAudio() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: AppConstants.audioExtensions,
    );
    if (result == null || result.files.isEmpty) return;
    setState(() => _loadingAudio = true);
    try {
      final filePath = result.files.first.path!;
      final ext = p.extension(filePath).replaceAll('.', '').toLowerCase();
      final format = _extensionToFormat(ext);
      final durationMs = await _audioSvc.getDurationMs(filePath);
      await _repo.updateAudio(_project.id, audioPath: filePath, format: format, durationMs: durationMs);
      setState(() { _project = _repo.getById(_project.id)!; });
      _showSnack('Audio loaded ✓');
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    } finally {
      setState(() => _loadingAudio = false);
    }
  }

  Future<void> _importLyrics() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: AppConstants.lyricsExtensions,
    );
    if (result == null || result.files.isEmpty) return;
    setState(() => _loadingLyrics = true);
    try {
      final filePath = result.files.first.path!;
      final content = await File(filePath).readAsString();
      final ext = p.extension(filePath).replaceAll('.', '').toLowerCase();
      List<LyricLine> lines;
      bool isSynced = false;
      if (ext == 'lrc') {
        lines = _lyricsSvc.parseLrc(content);
        isSynced = lines.any((l) => l.isSynced);
      } else {
        lines = _lyricsSvc.parseTxt(content);
      }
      await _repo.updateLyrics(_project.id, lines, synced: isSynced);
      setState(() { _project = _repo.getById(_project.id)!; });
      _showSnack('Lyrics loaded (${lines.length} lines) ✓');
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    } finally {
      setState(() => _loadingLyrics = false);
    }
  }

  Future<void> _importStem(String stemName) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['wav', 'mp3', 'flac'],
    );
    if (result == null || result.files.isEmpty) return;
    setState(() => _loadingStem = true);
    try {
      final filePath = result.files.first.path!;
      final stems = _project.stems ?? StemSet();
      switch (stemName) {
        case 'vocals': stems.vocalsPath = filePath;
        case 'drums': stems.drumsPath = filePath;
        case 'bass': stems.bassPath = filePath;
        case 'other': stems.otherPath = filePath;
      }
      await _repo.updateStems(_project.id, stems);
      setState(() { _project = _repo.getById(_project.id)!; });
      _showSnack('$stemName stem loaded ✓');
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    } finally {
      setState(() => _loadingStem = false);
    }
  }

  Future<void> _importStemFolder() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['wav', 'mp3', 'flac'],
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;
    setState(() => _loadingStem = true);
    try {
      final stems = _project.stems ?? StemSet();
      for (final file in result.files) {
        final path = file.path!;
        final name = p.basenameWithoutExtension(path).toLowerCase();
        if (name.contains('vocal')) stems.vocalsPath = path;
        else if (name.contains('drum')) stems.drumsPath = path;
        else if (name.contains('bass')) stems.bassPath = path;
        else if (name.contains('other') || name.contains('instr')) stems.otherPath = path;
      }
      await _repo.updateStems(_project.id, stems);
      setState(() { _project = _repo.getById(_project.id)!; });
      _showSnack('Stems auto-detected ✓');
    } finally {
      setState(() => _loadingStem = false);
    }
  }

  void _proceedToSync() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LyricsSyncScreen(project: _project)),
    ).then((_) {
      final updated = _repo.getById(_project.id);
      if (updated != null) setState(() => _project = updated);
    });
  }

  AudioFormat _extensionToFormat(String ext) {
    switch (ext) {
      case 'wav': return AudioFormat.wav;
      case 'flac': return AudioFormat.flac;
      case 'aac': return AudioFormat.aac;
      case 'm4a': return AudioFormat.m4a;
      default: return AudioFormat.mp3;
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.dangerDim : null,
    ));
  }

  String _fmt(int ms) {
    final d = Duration(milliseconds: ms);
    return '${d.inMinutes.toString().padLeft(2,'0')}:${d.inSeconds.remainder(60).toString().padLeft(2,'0')}';
  }

  @override
  Widget build(BuildContext context) {
    final hasAudio = _project.audioPath != null;
    final hasLyrics = _project.lyrics.isNotEmpty;
    final stems = _project.stems;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_project.name),
        actions: [
          if (hasAudio)
            TextButton(
              onPressed: _proceedToSync,
              child: Row(
                children: [
                  Text('SYNC', style: AppTextStyles.labelLarge.copyWith(color: AppColors.primary)),
                  const Icon(Icons.chevron_right, color: AppColors.primary, size: 18),
                ],
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _WorkflowBreadcrumb(currentStep: 0),
          const SizedBox(height: 24),

          const SectionHeader(title: 'Audio File'),
          const SizedBox(height: 12),
          MstCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasAudio) ...[
                  Row(
                    children: [
                      const Icon(Icons.audiotrack, color: AppColors.primary, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          p.basename(_project.audioPath!),
                          style: AppTextStyles.bodyLarge,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      StatusBadge(label: _fmt(_project.durationMs), color: AppColors.accent),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                MstButton(
                  label: hasAudio ? 'Change Audio' : 'Import MP3 / WAV / FLAC',
                  icon: Icons.file_upload_outlined,
                  variant: hasAudio ? MstButtonVariant.secondary : MstButtonVariant.primary,
                  loading: _loadingAudio,
                  onTap: _importAudio,
                  fullWidth: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          const SectionHeader(title: 'Lyrics', subtitle: 'TXT or LRC format'),
          const SizedBox(height: 12),
          MstCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasLyrics) ...[
                  Row(
                    children: [
                      Icon(
                        _project.lyricsAreSynced ? Icons.sync : Icons.text_fields,
                        color: _project.lyricsAreSynced ? AppColors.accent : AppColors.stemVocals,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text('${_project.lyrics.length} lines', style: AppTextStyles.bodyLarge),
                      const Spacer(),
                      StatusBadge(
                        label: _project.lyricsAreSynced ? 'Synced' : 'Not synced',
                        color: _project.lyricsAreSynced ? AppColors.accent : AppColors.textSecondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ..._project.lyrics.take(3).map((l) => Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text('${l.lrcTimestamp} ${l.text}',
                      style: AppTextStyles.mono, overflow: TextOverflow.ellipsis),
                  )),
                  if (_project.lyrics.length > 3)
                    Text('+ ${_project.lyrics.length - 3} more…',
                      style: AppTextStyles.mono.copyWith(color: AppColors.textDisabled)),
                  const SizedBox(height: 12),
                ],
                MstButton(
                  label: hasLyrics ? 'Replace Lyrics' : 'Import TXT / LRC',
                  icon: Icons.text_snippet_outlined,
                  variant: hasLyrics ? MstButtonVariant.secondary : MstButtonVariant.primary,
                  loading: _loadingLyrics,
                  onTap: _importLyrics,
                  fullWidth: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          SectionHeader(
            title: 'Stems',
            subtitle: 'From Moises, UVR, or Demucs',
            trailing: TextButton(
              onPressed: _importStemFolder,
              child: Text('AUTO-DETECT', style: AppTextStyles.mono.copyWith(color: AppColors.primary)),
            ),
          ),
          const SizedBox(height: 12),
          MstCard(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: AppColors.stemDrums.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.stemDrums.withOpacity(0.25)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 14, color: AppColors.stemDrums),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Drums are NEVER transposed — only bass & melodic stems.',
                          style: AppTextStyles.mono.copyWith(color: AppColors.stemDrums),
                        ),
                      ),
                    ],
                  ),
                ),
                ...['vocals', 'drums', 'bass', 'other'].map((name) {
                  final hasFile = stems?.pathForStem(name) != null;
                  final filePath = stems?.pathForStem(name);
                  final color = StemColorDot.colorFor(name);
                  final isDrums = name == 'drums';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: _loadingStem ? null : () => _importStem(name),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: hasFile ? color.withOpacity(0.08) : AppColors.surfaceHigh,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: hasFile ? color.withOpacity(0.35) : AppColors.surfaceBorder),
                        ),
                        child: Row(
                          children: [
                            StemColorDot(stemName: name, hasFile: hasFile),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(name.toUpperCase(),
                                        style: AppTextStyles.titleMedium.copyWith(
                                          color: hasFile ? color : AppColors.textDisabled, fontSize: 11)),
                                      if (isDrums) ...[
                                        const SizedBox(width: 6),
                                        const StatusBadge(label: 'NO TRANSPOSE', color: AppColors.stemDrums),
                                      ],
                                    ],
                                  ),
                                  if (filePath != null) ...[
                                    const SizedBox(height: 2),
                                    Text(p.basename(filePath), style: AppTextStyles.mono,
                                      overflow: TextOverflow.ellipsis),
                                  ],
                                ],
                              ),
                            ),
                            Icon(
                              hasFile ? Icons.check_circle : Icons.file_upload_outlined,
                              color: hasFile ? color : AppColors.textDisabled, size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),

          const SizedBox(height: 32),
          if (hasAudio)
            MstButton(
              label: hasLyrics ? 'Continue to Lyrics Sync →' : 'Continue →',
              icon: Icons.arrow_forward,
              onTap: _proceedToSync,
              fullWidth: true,
            ),
        ],
      ),
    );
  }
}

class _WorkflowBreadcrumb extends StatelessWidget {
  final int currentStep;
  const _WorkflowBreadcrumb({required this.currentStep});
  static const steps = ['IMPORT', 'SYNC', 'TRANSPOSE', 'TRIM', 'EXPORT'];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: steps.asMap().entries.map((entry) {
          final i = entry.key;
          final label = entry.value;
          final isActive = i == currentStep;
          final isDone = i < currentStep;
          return Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isActive ? AppColors.primary
                        : isDone ? AppColors.primaryDim
                        : AppColors.surfaceBorder,
                  ),
                ),
                child: Text(label, style: AppTextStyles.mono.copyWith(
                  color: isActive ? AppColors.background
                      : isDone ? AppColors.primaryDim
                      : AppColors.textDisabled,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                )),
              ),
              if (i < steps.length - 1)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(Icons.chevron_right, size: 14, color: AppColors.textDisabled),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
