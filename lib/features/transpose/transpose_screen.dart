import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../../data/repositories/project_repository.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../cut_trim/cut_trim_screen.dart';

class TransposeScreen extends StatefulWidget {
  final Project project;
  const TransposeScreen({super.key, required this.project});

  @override
  State<TransposeScreen> createState() => _TransposeScreenState();
}

class _TransposeScreenState extends State<TransposeScreen> {
  late Project _project;
  final _repo = ProjectRepository();
  late int _semitones;
  late bool _preserveTempo;

  @override
  void initState() {
    super.initState();
    _project = widget.project;
    _semitones = _project.transpose.semitones;
    _preserveTempo = _project.transpose.preserveTempo;
  }

  Future<void> _save() async {
    final settings = TransposeSettings(
      semitones: _semitones,
      preserveTempo: _preserveTempo,
      skipDrums: true,
    );
    await _repo.updateTranspose(_project.id, settings);
    setState(() { _project = _repo.getById(_project.id)!; });
  }

  void _proceedToTrim() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CutTrimScreen(project: _project)),
    ).then((_) {
      final updated = _repo.getById(_project.id);
      if (updated != null && mounted) setState(() => _project = updated);
    });
  }

  String _noteForSemitone(int s) {
    const notes = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    if (s == 0) return 'No change';
    final sign = s > 0 ? '+' : '';
    return '$sign$s st';
  }

  @override
  Widget build(BuildContext context) {
    final hasStems = _project.stems != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Transpose'),
        actions: [
          TextButton(
            onPressed: () async { await _save(); _proceedToTrim(); },
            child: Row(children: [
              Text('TRIM', style: AppTextStyles.labelLarge.copyWith(color: AppColors.primary)),
              const Icon(Icons.chevron_right, color: AppColors.primary, size: 18),
            ]),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Drum safety notice
          MstCard(
            borderColor: AppColors.stemDrums.withOpacity(0.4),
            child: Row(
              children: [
                const Icon(Icons.security, color: AppColors.stemDrums, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Drum Protection Active', style: AppTextStyles.titleLarge.copyWith(color: AppColors.stemDrums)),
                      const SizedBox(height: 4),
                      Text(
                        'Drums, cymbals, kick, and snare are NEVER transposed. '
                        'Only bass, melodic, and harmonic stems will be pitch-shifted.',
                        style: AppTextStyles.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          if (!hasStems) ...[
            MstCard(
              borderColor: AppColors.primary.withOpacity(0.3),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: AppColors.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'No stems loaded. Transpose will apply to the full mix '
                      '(drums included). Import stems to transpose safely.',
                      style: AppTextStyles.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          const SectionHeader(title: 'Pitch Shift'),
          const SizedBox(height: 16),

          // Large semitone display
          Center(
            child: Column(
              children: [
                Text(
                  _semitones == 0 ? '0' : (_semitones > 0 ? '+$_semitones' : '$_semitones'),
                  style: AppTextStyles.displayLarge.copyWith(
                    fontSize: 64,
                    color: _semitones == 0 ? AppColors.textSecondary : AppColors.primary,
                  ),
                ),
                Text('SEMITONES', style: AppTextStyles.titleMedium),
                const SizedBox(height: 4),
                Text(_noteForSemitone(_semitones), style: AppTextStyles.bodyMedium),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Semitone slider
          MstSlider(
            label: 'Semitones',
            value: _semitones.toDouble(),
            min: -12,
            max: 12,
            divisions: 24,
            displayValue: _semitones > 0 ? '+$_semitones' : '$_semitones',
            activeColor: _semitones == 0 ? AppColors.textDisabled : AppColors.primary,
            onChanged: (v) => setState(() => _semitones = v.round()),
          ),

          const SizedBox(height: 12),

          // Quick step buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final step in [-2, -1])
                _StepBtn(label: '$step', onTap: () {
                  setState(() => _semitones = (_semitones + step).clamp(-12, 12));
                }),
              const SizedBox(width: 12),
              _StepBtn(
                label: 'RESET',
                onTap: () => setState(() => _semitones = 0),
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 12),
              for (final step in [1, 2])
                _StepBtn(label: '+$step', onTap: () {
                  setState(() => _semitones = (_semitones + step).clamp(-12, 12));
                }),
            ],
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 20),

          // Options
          const SectionHeader(title: 'Options'),
          const SizedBox(height: 12),

          MstCard(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Preserve Tempo', style: AppTextStyles.bodyLarge),
                        Text('Keep original speed after pitch shift', style: AppTextStyles.bodyMedium),
                      ],
                    ),
                    Switch(
                      value: _preserveTempo,
                      onChanged: (v) => setState(() => _preserveTempo = v),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Stems status
          if (hasStems) ...[
            const SizedBox(height: 20),
            const SectionHeader(title: 'Stem Status'),
            const SizedBox(height: 12),
            MstCard(
              child: Column(
                children: ['vocals', 'drums', 'bass', 'other'].map((name) {
                  final has = _project.stems!.pathForStem(name) != null;
                  final isDrums = name == 'drums';
                  final color = StemColorDot.colorFor(name);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        StemColorDot(stemName: name, hasFile: has),
                        const SizedBox(width: 12),
                        Text(name.toUpperCase(), style: AppTextStyles.titleMedium.copyWith(
                          color: has ? color : AppColors.textDisabled, fontSize: 11)),
                        const Spacer(),
                        StatusBadge(
                          label: isDrums ? 'LOCKED' : (_semitones == 0 ? 'NO CHANGE' : '${_semitones > 0 ? "+" : ""}$_semitones st'),
                          color: isDrums ? AppColors.stemDrums
                              : _semitones == 0 ? AppColors.textDisabled
                              : AppColors.primary,
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          const SizedBox(height: 32),

          MstButton(
            label: 'Save & Continue to Trim →',
            icon: Icons.arrow_forward,
            onTap: () async { await _save(); _proceedToTrim(); },
            fullWidth: true,
          ),
        ],
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _StepBtn({required this.label, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.surfaceBorder),
          ),
          child: Text(
            label,
            style: AppTextStyles.mono.copyWith(color: color ?? AppColors.textPrimary),
          ),
        ),
      ),
    );
  }
}
