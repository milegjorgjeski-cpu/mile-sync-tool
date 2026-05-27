// lib/features/trim/trim_screen.dart
// Step 4: Cut / Trim / Crossfade with visual waveform

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models.dart';
import '../../core/project_provider.dart';
import '../../core/ffmpeg_service.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/mile_widgets.dart';

class TrimScreen extends StatefulWidget {
  const TrimScreen({super.key});

  @override
  State<TrimScreen> createState() => _TrimScreenState();
}

class _TrimScreenState extends State<TrimScreen> {
  bool _processing = false;
  String? _result;

  // Start/end as fractions 0.0-1.0 of total duration
  double _startFraction = 0.0;
  double _endFraction = 1.0;

  Future<void> _applyTrimAndFades() async {
    final prov = Provider.of<ProjectProvider>(context, listen: false);
    final project = prov.project;
    if (project == null) return;

    final track = project.mainTrack ?? project.vocalStem;
    if (track == null) {
      setState(() => _result = 'No audio track to trim');
      return;
    }

    final duration = track.duration;
    if (duration == null) {
      setState(() => _result = 'Duration unknown – skipping trim');
      prov.nextStep();
      return;
    }

    setState(() {
      _processing = true;
      _result = null;
    });

    final startMs = (duration.inMilliseconds * _startFraction).round();
    final endMs = (duration.inMilliseconds * _endFraction).round();
    final startDur = Duration(milliseconds: startMs);
    final endDur = Duration(milliseconds: endMs);

    final trim = project.trimSettings;
    final fade = project.crossfadeSettings;

    String currentPath = track.filePath;
    bool anyChange = false;

    // 1. Remove leading silence if requested
    if (trim.removeLeadingSilence) {
      final outPath = await FfmpegService.tempFile('silence_removed.mp3');
      final r = await FfmpegService.removeLeadingSilence(
          currentPath, outPath);
      if (r.success) {
        currentPath = outPath;
        anyChange = true;
      }
    }

    // 2. Trim
    if (_startFraction > 0.0 || _endFraction < 1.0) {
      final outPath = await FfmpegService.tempFile('trimmed.mp3');
      final r = await FfmpegService.trim(
        currentPath,
        outPath,
        start: startDur,
        end: endDur,
      );
      if (r.success) {
        currentPath = outPath;
        anyChange = true;
      }
    }

    // 3. Apply fades
    if (fade.enabled &&
        (fade.fadeInSeconds > 0 || fade.fadeOutSeconds > 0)) {
      final trimDuration = endDur - startDur;
      final outPath = await FfmpegService.tempFile('faded.mp3');
      final r = await FfmpegService.applyFades(
        currentPath,
        outPath,
        fadeInSeconds: fade.fadeInSeconds,
        fadeOutSeconds: fade.fadeOutSeconds,
        totalDuration: trimDuration,
      );
      if (r.success) {
        currentPath = outPath;
        anyChange = true;
      }
    }

    if (anyChange) {
      final updated = AudioTrack(
        id: track.id,
        filePath: currentPath,
        fileName: track.fileName,
        type: track.type,
        duration: endDur - startDur,
      );
      if (project.mainTrack != null) {
        prov.setMainTrack(updated);
      } else {
        prov.setVocalStem(updated);
      }
    }

    setState(() {
      _processing = false;
      _result = anyChange ? '✓ Applied cuts and fades' : 'No changes';
    });
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ProjectProvider>();
    final project = prov.project;
    if (project == null) return const SizedBox();

    final track = project.mainTrack ?? project.vocalStem;
    final duration = track?.duration;
    final trim = project.trimSettings;
    final fade = project.crossfadeSettings;

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Waveform display
              const MileSectionHeader(
                title: 'Waveform',
                subtitle: 'Drag markers to trim start / end',
              ),
              const WaveformPlaceholder(
                height: 100,
                label: 'Waveform (requires audio_waveforms plugin)',
              ),
              const SizedBox(height: 16),

              // Start / End trim sliders
              if (duration != null) ...[
                _TrimSlider(
                  label: 'START',
                  value: _startFraction,
                  max: _endFraction - 0.01,
                  duration: duration,
                  onChanged: (v) => setState(() => _startFraction = v),
                ),
                const SizedBox(height: 12),
                _TrimSlider(
                  label: 'END',
                  value: _endFraction,
                  min: _startFraction + 0.01,
                  max: 1.0,
                  duration: duration,
                  onChanged: (v) => setState(() => _endFraction = v),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    _durationRangeLabel(
                        duration, _startFraction, _endFraction),
                    style: const TextStyle(
                      color: MileColors.textSecondary,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],

              if (duration == null)
                const Text(
                  'Import audio to enable trim',
                  style:
                      TextStyle(color: MileColors.textDim, fontSize: 13),
                ),

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),

              // Remove silence toggle
              const MileSectionHeader(
                title: 'Silence Removal',
                subtitle: 'Strip leading silence automatically',
              ),
              _ToggleRow(
                label: 'Remove leading silence',
                value: trim.removeLeadingSilence,
                onChanged: (v) => prov.setTrimSettings(
                  TrimSettings(
                    startPoint: trim.startPoint,
                    endPoint: trim.endPoint,
                    removeLeadingSilence: v,
                  ),
                ),
              ),

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),

              // Crossfade section
              const MileSectionHeader(
                title: 'Fade In / Fade Out',
                subtitle: 'For live medleys and transitions',
              ),
              _ToggleRow(
                label: 'Enable fades',
                value: fade.enabled,
                onChanged: (v) => prov.setCrossfadeSettings(
                  CrossfadeSettings(
                    fadeInSeconds: fade.fadeInSeconds,
                    fadeOutSeconds: fade.fadeOutSeconds,
                    enabled: v,
                  ),
                ),
              ),
              if (fade.enabled) ...[
                const SizedBox(height: 16),
                _FadeSlider(
                  label: 'FADE IN',
                  value: fade.fadeInSeconds,
                  max: 10,
                  onChanged: (v) => prov.setCrossfadeSettings(
                    CrossfadeSettings(
                      fadeInSeconds: v,
                      fadeOutSeconds: fade.fadeOutSeconds,
                      enabled: true,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _FadeSlider(
                  label: 'FADE OUT',
                  value: fade.fadeOutSeconds,
                  max: 10,
                  onChanged: (v) => prov.setCrossfadeSettings(
                    CrossfadeSettings(
                      fadeInSeconds: fade.fadeInSeconds,
                      fadeOutSeconds: v,
                      enabled: true,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              if (_result != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: _result!.startsWith('✓')
                        ? MileColors.success.withOpacity(0.1)
                        : MileColors.bg3,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _result!.startsWith('✓')
                          ? MileColors.success.withOpacity(0.4)
                          : const Color(0xFF2A2D35),
                    ),
                  ),
                  child: Text(_result!,
                      style: TextStyle(
                          color: _result!.startsWith('✓')
                              ? MileColors.success
                              : MileColors.textSecondary,
                          fontSize: 13)),
                ),

              MileActionButton(
                label: 'Apply Cuts & Fades',
                icon: Icons.content_cut,
                onTap: _processing ? null : _applyTrimAndFades,
                isLoading: _processing,
              ),
            ],
          ),
        ),

        // Bottom nav
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: MileColors.bg1,
              border: Border(top: BorderSide(color: Color(0xFF2A2D35))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => prov.previousStep(),
                    child: const Text('BACK'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () => prov.nextStep(),
                    child: const Text('EXPORT →'),
                  ),
                ),
              ],
            ),
          ),
        ),

        if (_processing)
          const ProcessingOverlay(message: 'Processing audio...'),
      ],
    );
  }

  String _durationRangeLabel(
      Duration total, double start, double end) {
    final startMs = (total.inMilliseconds * start).round();
    final endMs = (total.inMilliseconds * end).round();
    final durMs = endMs - startMs;
    return '${_msToLabel(startMs)} → ${_msToLabel(endMs)}  (${_msToLabel(durMs)})';
  }

  String _msToLabel(int ms) {
    final d = Duration(milliseconds: ms);
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// ── Trim Slider ───────────────────────────────────────────────
class _TrimSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final Duration duration;
  final ValueChanged<double> onChanged;

  const _TrimSlider({
    required this.label,
    required this.value,
    required this.duration,
    required this.onChanged,
    this.min = 0.0,
    this.max = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final ms = (duration.inMilliseconds * value).round();
    final d = Duration(milliseconds: ms);
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label,
                style: const TextStyle(
                  color: MileColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                )),
            const Spacer(),
            Text(
              '$m:$s',
              style: const TextStyle(
                color: MileColors.accent,
                fontSize: 13,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

// ── Fade Slider ───────────────────────────────────────────────
class _FadeSlider extends StatelessWidget {
  final String label;
  final double value;
  final double max;
  final ValueChanged<double> onChanged;

  const _FadeSlider({
    required this.label,
    required this.value,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label,
                style: const TextStyle(
                  color: MileColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                )),
            const Spacer(),
            Text(
              '${value.toStringAsFixed(1)}s',
              style: const TextStyle(
                color: MileColors.accent,
                fontSize: 13,
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: 0,
          max: max,
          divisions: 20,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

// ── Toggle Row ────────────────────────────────────────────────
class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  color: MileColors.textPrimary, fontSize: 14)),
        ),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}
