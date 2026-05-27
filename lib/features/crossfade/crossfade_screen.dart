import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../../data/repositories/project_repository.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../export/export_screen.dart';

class CrossfadeScreen extends StatefulWidget {
  final Project project;
  const CrossfadeScreen({super.key, required this.project});

  @override
  State<CrossfadeScreen> createState() => _CrossfadeScreenState();
}

class _CrossfadeScreenState extends State<CrossfadeScreen> {
  late Project _project;
  final _repo = ProjectRepository();
  late bool _enabled;
  late double _fadeInMs;
  late double _fadeOutMs;

  @override
  void initState() {
    super.initState();
    _project = widget.project;
    _enabled = _project.crossfade.enabled;
    _fadeInMs = _project.crossfade.fadeInMs.toDouble();
    _fadeOutMs = _project.crossfade.fadeOutMs.toDouble();
  }

  Future<void> _save() async {
    await _repo.updateCrossfade(_project.id, CrossfadeSettings(
      enabled: _enabled, fadeInMs: _fadeInMs.round(), fadeOutMs: _fadeOutMs.round()));
    setState(() { _project = _repo.getById(_project.id)!; });
  }

  void _proceedToExport() async {
    await _save();
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => ExportScreen(project: _project)));
  }

  String _fmtMs(double ms) {
    if (ms < 1000) return '${ms.round()}ms';
    return '${(ms / 1000).toStringAsFixed(1)}s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Fade / Crossfade'),
        actions: [
          TextButton(
            onPressed: _proceedToExport,
            child: Row(children: [
              Text('EXPORT', style: AppTextStyles.labelLarge.copyWith(color: AppColors.primary)),
              const Icon(Icons.chevron_right, color: AppColors.primary, size: 18),
            ]),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          MstCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Enable Fades', style: AppTextStyles.bodyLarge),
                  Text('Apply fade in / fade out to export', style: AppTextStyles.bodyMedium),
                ]),
                Switch(value: _enabled, onChanged: (v) => setState(() => _enabled = v)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          AnimatedOpacity(
            opacity: _enabled ? 1.0 : 0.35,
            duration: const Duration(milliseconds: 200),
            child: MstCard(
              child: Column(
                children: [
                  // Visual fade preview
                  _FadePreview(fadeInMs: _fadeInMs, fadeOutMs: _fadeOutMs,
                      totalMs: _project.durationMs.toDouble()),
                  const SizedBox(height: 20),
                  MstSlider(
                    label: 'Fade In',
                    value: _fadeInMs,
                    min: 0,
                    max: 10000,
                    displayValue: _fmtMs(_fadeInMs),
                    activeColor: AppColors.accent,
                    onChanged: _enabled ? (v) => setState(() => _fadeInMs = v) : (_) {},
                  ),
                  const SizedBox(height: 16),
                  MstSlider(
                    label: 'Fade Out',
                    value: _fadeOutMs,
                    min: 0,
                    max: 10000,
                    displayValue: _fmtMs(_fadeOutMs),
                    activeColor: AppColors.stemVocals,
                    onChanged: _enabled ? (v) => setState(() => _fadeOutMs = v) : (_) {},
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          MstButton(label: 'Save & Continue to Export →', icon: Icons.arrow_forward,
              onTap: _proceedToExport, fullWidth: true),
        ],
      ),
    );
  }
}

class _FadePreview extends StatelessWidget {
  final double fadeInMs, fadeOutMs, totalMs;
  const _FadePreview({required this.fadeInMs, required this.fadeOutMs, required this.totalMs});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: CustomPaint(painter: _FadePainter(
        fadeInFraction: totalMs > 0 ? (fadeInMs / totalMs).clamp(0.0, 0.5) : 0,
        fadeOutFraction: totalMs > 0 ? (fadeOutMs / totalMs).clamp(0.0, 0.5) : 0,
      )),
    );
  }
}

class _FadePainter extends CustomPainter {
  final double fadeInFraction, fadeOutFraction;
  _FadePainter({required this.fadeInFraction, required this.fadeOutFraction});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.waveformActive..style = PaintingStyle.fill;
    final path = Path();
    path.moveTo(0, size.height);
    path.lineTo(fadeInFraction * size.width, 0);
    path.lineTo((1 - fadeOutFraction) * size.width, 0);
    path.lineTo(size.width, size.height);
    path.close();
    canvas.drawPath(path, paint..color = AppColors.waveformActive.withOpacity(0.3));
    final linePaint = Paint()..color = AppColors.primary..strokeWidth = 2..style = PaintingStyle.stroke;
    final linePath = Path();
    linePath.moveTo(0, size.height);
    linePath.lineTo(fadeInFraction * size.width, 0);
    linePath.lineTo((1 - fadeOutFraction) * size.width, 0);
    linePath.lineTo(size.width, size.height);
    canvas.drawPath(linePath, linePaint);
  }

  @override
  bool shouldRepaint(_FadePainter old) =>
      old.fadeInFraction != fadeInFraction || old.fadeOutFraction != fadeOutFraction;
}
