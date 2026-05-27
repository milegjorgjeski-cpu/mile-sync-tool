// lib/features/lyrics_sync/lyrics_sync_screen.dart
// Step 2: Auto-sync lyrics to vocal stem + manual correction

import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models.dart';
import '../../core/project_provider.dart';
import '../../core/lyrics_parser.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/mile_widgets.dart';

class LyricsSyncScreen extends StatefulWidget {
  const LyricsSyncScreen({super.key});

  @override
  State<LyricsSyncScreen> createState() => _LyricsSyncScreenState();
}

class _LyricsSyncScreenState extends State<LyricsSyncScreen> {
  bool _syncing = false;
  String _syncStatus = '';
  int? _editingLineIndex;

  // ── Auto-sync via Whisper ─────────────────────────────────
  Future<void> _runAutoSync() async {
    final prov = Provider.of<ProjectProvider>(context, listen: false);
    final project = prov.project;

    if (project?.vocalStem == null) {
      _showSnack('Please import a vocal stem first');
      return;
    }
    if (project?.lyrics == null) {
      _showSnack('Please import lyrics first');
      return;
    }

    setState(() {
      _syncing = true;
      _syncStatus = 'Running Whisper alignment...';
    });

    try {
      // Run whisper_timestamped or whisperx via Python subprocess
      // The JSON output is parsed for segment timestamps
      final vocalPath = project!.vocalStem!.filePath;
      final segments = await _runWhisper(vocalPath);

      if (segments.isEmpty) {
        setState(() {
          _syncStatus = 'Whisper found no speech. Try manual sync.';
          _syncing = false;
        });
        return;
      }

      final synced = LyricsParser.applyWhisperAlignment(
        project.lyrics!,
        segments,
      );

      prov.setLyrics(synced);

      setState(() {
        _syncing = false;
        _syncStatus =
            '✓ Synced ${synced.syncedCount} of ${synced.lines.length} lines';
      });
    } catch (e) {
      setState(() {
        _syncing = false;
        _syncStatus = 'Error: $e';
      });
    }
  }

  Future<List<WhisperSegment>> _runWhisper(String audioPath) async {
    try {
      // whisper_timestamped: python3 -m whisper_timestamped <audio> --output_format json
      // or: whisperx <audio> --output_format json
      // We call the Python process and parse stdout JSON
      final result = await Process.run('python3', [
        '-m',
        'whisper_timestamped',
        audioPath,
        '--model', 'small',
        '--output_format', 'json',
        '--output_dir', '/tmp',
        '--verbose', 'False',
      ]);

      if (result.exitCode != 0) {
        // Try aeneas as fallback
        return await _runAeneas(audioPath);
      }

      // Parse JSON output
      final jsonStr = result.stdout.toString();
      if (jsonStr.trim().isEmpty) return [];
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      final segs = (data['segments'] as List?)
          ?.map((s) => WhisperSegment.fromJson(s as Map<String, dynamic>))
          .toList() ?? [];
      return segs;
    } catch (_) {
      return _runAeneas(audioPath);
    }
  }

  Future<List<WhisperSegment>> _runAeneas(String audioPath) async {
    // aeneas: python3 -m aeneas.tools.execute_task <audio> <txt> ... <output.json>
    // Simplified: returns empty if aeneas not available
    return [];
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: MileColors.bg3,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ProjectProvider>();
    final project = prov.project;
    final lyrics = project?.lyrics;

    return Stack(
      children: [
        Column(
          children: [
            // Top controls
            _SyncControls(
              hasVocal: project?.vocalStem != null,
              hasLyrics: lyrics != null,
              isSyncing: _syncing,
              syncStatus: _syncStatus,
              syncedCount: lyrics?.syncedCount ?? 0,
              totalCount: lyrics?.lines.length ?? 0,
              onSync: _runAutoSync,
              onClear: lyrics != null && lyrics.isSynced
                  ? () => prov.clearLyricsTiming()
                  : null,
            ),

            const Divider(height: 1),

            // Lyrics list
            if (lyrics == null)
              const Expanded(child: _NoLyricsHint())
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: lyrics.lines.length,
                  itemBuilder: (ctx, i) {
                    final line = lyrics.lines[i];
                    return _LyricsLineRow(
                      line: line,
                      isEditing: _editingLineIndex == i,
                      onTap: () =>
                          setState(() => _editingLineIndex =
                              _editingLineIndex == i ? null : i),
                      onTimeChanged: (start, end) {
                        prov.updateLyricsLine(
                            i, line.copyWith(startTime: start, endTime: end, isEdited: true));
                      },
                    );
                  },
                ),
              ),
          ],
        ),

        // Bottom nav
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _BottomNav(
            canContinue: lyrics != null,
            onBack: () => prov.previousStep(),
            onNext: () => prov.nextStep(),
          ),
        ),

        if (_syncing)
          ProcessingOverlay(
              message: _syncStatus, progress: 0),
      ],
    );
  }
}

// ── Sync Controls Bar ─────────────────────────────────────────
class _SyncControls extends StatelessWidget {
  final bool hasVocal;
  final bool hasLyrics;
  final bool isSyncing;
  final String syncStatus;
  final int syncedCount;
  final int totalCount;
  final VoidCallback onSync;
  final VoidCallback? onClear;

  const _SyncControls({
    required this.hasVocal,
    required this.hasLyrics,
    required this.isSyncing,
    required this.syncStatus,
    required this.syncedCount,
    required this.totalCount,
    required this.onSync,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final canSync = hasVocal && hasLyrics && !isSyncing;

    return Container(
      padding: const EdgeInsets.all(16),
      color: MileColors.bg1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AUTO SYNC',
                      style: TextStyle(
                        color: MileColors.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasVocal
                          ? hasLyrics
                              ? 'Vocal + lyrics ready'
                              : 'Missing: lyrics file'
                          : 'Missing: vocal stem',
                      style: const TextStyle(
                          color: MileColors.textDim, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (onClear != null)
                TextButton(
                  onPressed: onClear,
                  child: const Text('CLEAR TIMING'),
                ),
              const SizedBox(width: 8),
              SizedBox(
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: canSync ? onSync : null,
                  icon: const Icon(Icons.auto_awesome, size: 16),
                  label: const Text('SYNC'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 0),
                  ),
                ),
              ),
            ],
          ),
          if (syncStatus.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              syncStatus,
              style: TextStyle(
                color: syncStatus.startsWith('✓')
                    ? MileColors.success
                    : syncStatus.startsWith('Error')
                        ? MileColors.error
                        : MileColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
          if (totalCount > 0) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: totalCount > 0 ? syncedCount / totalCount : 0,
                backgroundColor: MileColors.bg3,
                color: MileColors.accent,
                minHeight: 3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$syncedCount / $totalCount lines synced',
              style: const TextStyle(
                  color: MileColors.textDim, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}

// ── No Lyrics Hint ────────────────────────────────────────────
class _NoLyricsHint extends StatelessWidget {
  const _NoLyricsHint();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.text_snippet_outlined,
              color: MileColors.textDim, size: 48),
          SizedBox(height: 12),
          Text(
            'No lyrics imported',
            style: TextStyle(
                color: MileColors.textSecondary, fontSize: 15),
          ),
          SizedBox(height: 4),
          Text(
            'Go back and import a .txt or .lrc file',
            style:
                TextStyle(color: MileColors.textDim, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ── Lyrics Line Row ───────────────────────────────────────────
class _LyricsLineRow extends StatelessWidget {
  final LyricsLine line;
  final bool isEditing;
  final VoidCallback onTap;
  final Function(Duration? start, Duration? end) onTimeChanged;

  const _LyricsLineRow({
    required this.line,
    required this.isEditing,
    required this.onTap,
    required this.onTimeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            color: isEditing
                ? MileColors.accent.withOpacity(0.07)
                : Colors.transparent,
            child: Row(
              children: [
                // Time badge
                SizedBox(
                  width: 56,
                  child: line.isSynced
                      ? _TimeBadge(time: line.startTime!)
                      : const Center(
                          child: Text('—',
                              style: TextStyle(
                                  color: MileColors.textDim,
                                  fontSize: 13)),
                        ),
                ),
                const SizedBox(width: 12),
                // Lyrics text
                Expanded(
                  child: Text(
                    line.text,
                    style: TextStyle(
                      color: line.isSynced
                          ? MileColors.textPrimary
                          : MileColors.textSecondary,
                      fontSize: 14,
                      fontWeight: line.isEdited
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
                // Edit indicator
                if (line.isEdited)
                  const Icon(Icons.edit,
                      color: MileColors.accentDim, size: 14),
                Icon(
                  isEditing
                      ? Icons.expand_less
                      : Icons.expand_more,
                  color: MileColors.textDim,
                  size: 18,
                ),
              ],
            ),
          ),
        ),

        // Expanded editor
        if (isEditing)
          _TimeEditor(
            startTime: line.startTime,
            endTime: line.endTime,
            onChanged: onTimeChanged,
          ),

        const Divider(height: 1, indent: 84),
      ],
    );
  }
}

class _TimeBadge extends StatelessWidget {
  final Duration time;
  const _TimeBadge({required this.time});

  @override
  Widget build(BuildContext context) {
    final mins = time.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs =
        time.inSeconds.remainder(60).toString().padLeft(2, '0');
    final tenths =
        (time.inMilliseconds.remainder(1000) ~/ 100).toString();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: MileColors.accent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$mins:$secs.$tenths',
        style: const TextStyle(
          color: MileColors.accent,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          fontFamily: 'monospace',
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _TimeEditor extends StatefulWidget {
  final Duration? startTime;
  final Duration? endTime;
  final Function(Duration? start, Duration? end) onChanged;

  const _TimeEditor({
    this.startTime,
    this.endTime,
    required this.onChanged,
  });

  @override
  State<_TimeEditor> createState() => _TimeEditorState();
}

class _TimeEditorState extends State<_TimeEditor> {
  late TextEditingController _startCtrl;

  @override
  void initState() {
    super.initState();
    _startCtrl = TextEditingController(
      text: widget.startTime != null
          ? _formatDuration(widget.startTime!)
          : '',
    );
  }

  @override
  void dispose() {
    _startCtrl.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final ms = (d.inMilliseconds.remainder(1000) ~/ 100).toString();
    return '$m:$s.$ms';
  }

  Duration? _parseDuration(String s) {
    // Format: mm:ss.t
    final match = RegExp(r'^(\d+):(\d+)\.(\d)$').firstMatch(s.trim());
    if (match == null) return null;
    return Duration(
      minutes: int.parse(match.group(1)!),
      seconds: int.parse(match.group(2)!),
      milliseconds: int.parse(match.group(3)!) * 100,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: MileColors.bg2,
      padding: const EdgeInsets.fromLTRB(84, 8, 16, 12),
      child: Row(
        children: [
          const Text('Start:',
              style: TextStyle(
                  color: MileColors.textSecondary, fontSize: 12)),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            height: 36,
            child: TextField(
              controller: _startCtrl,
              style: const TextStyle(
                  color: MileColors.accent,
                  fontFamily: 'monospace',
                  fontSize: 13),
              decoration: const InputDecoration(
                hintText: '00:00.0',
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
              onSubmitted: (v) {
                final d = _parseDuration(v);
                widget.onChanged(d, widget.endTime);
              },
            ),
          ),
          const SizedBox(width: 8),
          // Quick adjust buttons
          _AdjustButton(
            label: '-0.5s',
            onTap: () {
              if (widget.startTime == null) return;
              final newTime = widget.startTime! -
                  const Duration(milliseconds: 500);
              widget.onChanged(
                  newTime.isNegative ? Duration.zero : newTime,
                  widget.endTime);
              _startCtrl.text = _formatDuration(
                  newTime.isNegative ? Duration.zero : newTime);
            },
          ),
          const SizedBox(width: 4),
          _AdjustButton(
            label: '+0.5s',
            onTap: () {
              if (widget.startTime == null) return;
              final newTime = widget.startTime! +
                  const Duration(milliseconds: 500);
              widget.onChanged(newTime, widget.endTime);
              _startCtrl.text = _formatDuration(newTime);
            },
          ),
        ],
      ),
    );
  }
}

class _AdjustButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _AdjustButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: MileColors.bg3,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFF2A2D35)),
        ),
        child: Text(label,
            style: const TextStyle(
                color: MileColors.textSecondary, fontSize: 11)),
      ),
    );
  }
}

// ── Bottom Navigation ─────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final bool canContinue;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const _BottomNav({
    required this.canContinue,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: MileColors.bg1,
        border: Border(top: BorderSide(color: Color(0xFF2A2D35))),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: onBack,
              child: const Text('BACK'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: onNext,
              child: const Text('TRANSPOSE →'),
            ),
          ),
        ],
      ),
    );
  }
}
