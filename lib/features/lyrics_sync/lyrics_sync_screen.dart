import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/lyrics_service.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/models.dart';
import '../../data/repositories/project_repository.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../transpose/transpose_screen.dart';

class LyricsSyncScreen extends StatefulWidget {
  final Project project;
  const LyricsSyncScreen({super.key, required this.project});

  @override
  State<LyricsSyncScreen> createState() => _LyricsSyncScreenState();
}

class _LyricsSyncScreenState extends State<LyricsSyncScreen> {
  late Project _project;
  final _repo = ProjectRepository();
  final _lyricsSvc = LyricsService();

  bool _syncing = false;
  double _syncProgress = 0.0;
  String _syncStatus = '';
  int _playPositionMs = 0;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _project = widget.project;
  }

  Future<void> _runAutoSync() async {
    if (_project.lyrics.isEmpty) {
      _showSnack('Import lyrics first', isError: true);
      return;
    }
    setState(() { _syncing = true; _syncProgress = 0.0; _syncStatus = 'Starting…'; });
    try {
      final vocalPath = _project.stems?.vocalsPath ?? _project.audioPath!;
      final aligned = await _lyricsSvc.autoAlignLyrics(
        vocalStemPath: vocalPath,
        rawLyrics: _project.lyrics,
        model: AppConstants.defaultWhisperModel,
        onProgress: (p, s) { if (mounted) setState(() { _syncProgress = p; _syncStatus = s; }); },
      );
      await _repo.updateLyrics(_project.id, aligned, synced: true);
      setState(() { _project = _repo.getById(_project.id)!; _syncing = false; });
      _showSnack('Auto-sync complete ✓');
    } catch (e) {
      setState(() => _syncing = false);
      _showSnack('Sync failed: $e', isError: true);
    }
  }

  void _tapToSync(int lineIndex) {
    final updated = _lyricsSvc.setLineTiming(_project.lyrics, lineIndex, _playPositionMs);
    _repo.updateLyrics(_project.id, updated, synced: true);
    setState(() { _project = _repo.getById(_project.id)!; });
  }

  void _shiftAll(int offsetMs) {
    final shifted = _lyricsSvc.shiftAllTimings(_project.lyrics, offsetMs);
    _repo.updateLyrics(_project.id, shifted, synced: _project.lyricsAreSynced);
    setState(() { _project = _repo.getById(_project.id)!; });
  }

  void _proceedToTranspose() {
    Navigator.push(context,
      MaterialPageRoute(builder: (_) => TransposeScreen(project: _project)),
    ).then((_) {
      final u = _repo.getById(_project.id);
      if (u != null && mounted) setState(() => _project = u);
    });
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.dangerDim : null,
    ));
  }

  String _fmt(int ms) {
    final m = (ms ~/ 60000).toString().padLeft(2, '0');
    final s = ((ms % 60000) ~/ 1000).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final activeIndex = _lyricsSvc.findActiveLineIndex(_project.lyrics, _playPositionMs);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Lyrics Sync'),
        actions: [
          TextButton(
            onPressed: _proceedToTranspose,
            child: Row(children: [
              Text('TRANSPOSE', style: AppTextStyles.labelLarge.copyWith(color: AppColors.primary)),
              const Icon(Icons.chevron_right, color: AppColors.primary, size: 18),
            ]),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.surface,
            child: Column(
              children: [
                if (_syncing) ...[
                  Text(_syncStatus, style: AppTextStyles.bodyMedium),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: _syncProgress),
                ] else
                  Row(
                    children: [
                      Expanded(
                        child: MstButton(
                          label: _project.lyricsAreSynced ? 'Re-sync' : 'Auto Sync',
                          icon: Icons.auto_fix_high,
                          onTap: _project.lyrics.isNotEmpty ? _runAutoSync : null,
                          variant: _project.lyricsAreSynced ? MstButtonVariant.secondary : MstButtonVariant.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton(
                        onPressed: () => _shiftAll(-200),
                        child: const Text('-200ms'),
                      ),
                      const SizedBox(width: 6),
                      OutlinedButton(
                        onPressed: () => _shiftAll(200),
                        child: const Text('+200ms'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _project.lyrics.isEmpty
                ? const EmptyState(icon: Icons.text_fields, title: 'No lyrics imported')
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _project.lyrics.length,
                    itemBuilder: (ctx, i) {
                      final line = _project.lyrics[i];
                      final isActive = i == activeIndex && _project.lyricsAreSynced;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isActive ? AppColors.primaryGlow : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: isActive ? Border.all(color: AppColors.primary.withOpacity(0.4)) : null,
                        ),
                        child: Row(
                          children: [
                            Text(line.lrcTimestamp, style: AppTextStyles.mono.copyWith(
                              color: isActive ? AppColors.primary : AppColors.textDisabled)),
                            const SizedBox(width: 10),
                            Expanded(child: Text(line.text,
                              style: isActive ? AppTextStyles.lyricsLineActive
                                  : AppTextStyles.lyricsLine.copyWith(fontSize: 15))),
                            GestureDetector(
                              onTap: () => _tapToSync(i),
                              child: const Icon(Icons.touch_app, size: 16, color: AppColors.primary),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppColors.surface,
            child: Row(
              children: [
                Text('${_project.lyrics.where((l) => l.isSynced).length} / ${_project.lyrics.length} synced',
                    style: AppTextStyles.mono),
                const Spacer(),
                SizedBox(
                  width: 120,
                  child: LinearProgressIndicator(
                    value: _project.lyrics.isEmpty ? 0
                        : _project.lyrics.where((l) => l.isSynced).length / _project.lyrics.length,
                    backgroundColor: AppColors.waveformFill,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
