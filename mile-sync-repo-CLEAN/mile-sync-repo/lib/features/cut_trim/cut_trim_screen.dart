import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../../data/repositories/project_repository.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../crossfade/crossfade_screen.dart';

class CutTrimScreen extends StatefulWidget {
  final Project project;
  const CutTrimScreen({super.key, required this.project});

  @override
  State<CutTrimScreen> createState() => _CutTrimScreenState();
}

class _CutTrimScreenState extends State<CutTrimScreen> {
  late Project _project;
  final _repo = ProjectRepository();
  late double _startFraction;
  late double _endFraction;
  late bool _removeSilence;

  @override
  void initState() {
    super.initState();
    _project = widget.project;
    final dur = _project.durationMs > 0 ? _project.durationMs : 1;
    _startFraction = _project.trim.startMs / dur;
    _endFraction = _project.trim.endMs > 0 ? _project.trim.endMs / dur : 1.0;
    _removeSilence = _project.trim.removeSilence;
  }

  int get _startMs => (_startFraction * _project.durationMs).round();
  int get _endMs => (_endFraction * _project.durationMs).round();

  String _fmt(int ms) {
    final m = (ms ~/ 60000).toString().padLeft(2, '0');
    final s = ((ms % 60000) ~/ 1000).toString().padLeft(2, '0');
    final cs = ((ms % 1000) ~/ 10).toString().padLeft(2, '0');
    return '$m:$s.$cs';
  }

  Future<void> _save() async {
    await _repo.updateTrim(_project.id, TrimSettings(
      startMs: _startMs, endMs: _endMs, removeSilence: _removeSilence));
    setState(() { _project = _repo.getById(_project.id)!; });
  }

  void _proceedToCrossfade() async {
    await _save();
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CrossfadeScreen(project: _project)),
    ).then((_) {
      final u = _repo.getById(_project.id);
      if (u != null && mounted) setState(() => _project = u);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Cut / Trim'),
        actions: [
          TextButton(
            onPressed: _proceedToCrossfade,
            child: Row(children: [
              Text('FADES', style: AppTextStyles.labelLarge.copyWith(color: AppColors.primary)),
              const Icon(Icons.chevron_right, color: AppColors.primary, size: 18),
            ]),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SectionHeader(title: 'Waveform Trim'),
          const SizedBox(height: 12),
          MstCard(
            child: Column(
              children: [
                _WaveformTrimmer(
                  startFraction: _startFraction,
                  endFraction: _endFraction,
                  onStartChanged: (v) => setState(() => _startFraction = v.clamp(0.0, _endFraction - 0.01)),
                  onEndChanged: (v) => setState(() => _endFraction = v.clamp(_startFraction + 0.01, 1.0)),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _TimeBox(label: 'Start', time: _fmt(_startMs), color: AppColors.primary),
                    const Spacer(),
                    _TimeBox(label: 'Length', time: _fmt(_endMs - _startMs), color: AppColors.accent, center: true),
                    const Spacer(),
                    _TimeBox(label: 'End', time: _fmt(_endMs), color: AppColors.primary, right: true),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionHeader(title: 'Fine Tune'),
          const SizedBox(height: 12),
          MstCard(
            child: Column(
              children: [
                MstSlider(
                  label: 'Start',
                  value: _startFraction,
                  min: 0.0,
                  max: 1.0,
                  displayValue: _fmt(_startMs),
                  onChanged: (v) => setState(() => _startFraction = v.clamp(0.0, _endFraction - 0.01)),
                ),
                const SizedBox(height: 16),
                MstSlider(
                  label: 'End',
                  value: _endFraction,
                  min: 0.0,
                  max: 1.0,
                  displayValue: _fmt(_endMs),
                  onChanged: (v) => setState(() => _endFraction = v.clamp(_startFraction + 0.01, 1.0)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          MstCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Remove Silence', style: AppTextStyles.bodyLarge),
                  Text('Auto-remove long silent gaps', style: AppTextStyles.bodyMedium),
                ]),
                Switch(value: _removeSilence, onChanged: (v) => setState(() => _removeSilence = v)),
              ],
            ),
          ),
          const SizedBox(height: 32),
          MstButton(label: 'Save & Continue to Fades →', icon: Icons.arrow_forward,
              onTap: _proceedToCrossfade, fullWidth: true),
        ],
      ),
    );
  }
}

class _WaveformTrimmer extends StatelessWidget {
  final double startFraction;
  final double endFraction;
  final ValueChanged<double> onStartChanged;
  final ValueChanged<double> onEndChanged;

  const _WaveformTrimmer({
    required this.startFraction, required this.endFraction,
    required this.onStartChanged, required this.onEndChanged});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, constraints) {
      final width = constraints.maxWidth;
      return SizedBox(
        height: 80,
        child: Stack(children: [
          Positioned.fill(child: CustomPaint(
            painter: _WaveformPainter(startFraction: startFraction, endFraction: endFraction))),
          Positioned(left: 0, top: 0, bottom: 0, width: startFraction * width,
            child: Container(color: AppColors.background.withOpacity(0.65))),
          Positioned(left: endFraction * width, top: 0, bottom: 0, right: 0,
            child: Container(color: AppColors.background.withOpacity(0.65))),
          Positioned(left: (startFraction * width - 2).clamp(0, width), top: 0, bottom: 0,
            child: GestureDetector(
              onHorizontalDragUpdate: (d) => onStartChanged(startFraction + d.delta.dx / width),
              child: _Handle())),
          Positioned(left: (endFraction * width - 2).clamp(0, width), top: 0, bottom: 0,
            child: GestureDetector(
              onHorizontalDragUpdate: (d) => onEndChanged(endFraction + d.delta.dx / width),
              child: _Handle())),
        ]),
      );
    });
  }
}

class _Handle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 4,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(2),
        boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.5), blurRadius: 8)],
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final double startFraction;
  final double endFraction;
  _WaveformPainter({required this.startFraction, required this.endFraction});

  @override
  void paint(Canvas canvas, Size size) {
    const barCount = 60;
    final barWidth = size.width / barCount;
    for (int i = 0; i < barCount; i++) {
      final x = i * barWidth + barWidth / 2;
      final fraction = i / barCount;
      final isActive = fraction >= startFraction && fraction <= endFraction;
      final paint = Paint()
        ..color = isActive ? AppColors.waveformActive : AppColors.waveformFill
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      final h = (0.15 + (((i * 7 + 13) % 17) / 17.0) * 0.85) * size.height * 0.9;
      canvas.drawLine(Offset(x, size.height / 2 - h / 2), Offset(x, size.height / 2 + h / 2), paint);
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.startFraction != startFraction || old.endFraction != endFraction;
}

class _TimeBox extends StatelessWidget {
  final String label; final String time; final Color color;
  final bool center; final bool right;
  const _TimeBox({required this.label, required this.time, required this.color,
      this.center = false, this.right = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: center ? CrossAxisAlignment.center
          : right ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.mono.copyWith(fontSize: 10)),
        Text(time, style: AppTextStyles.mono.copyWith(color: color, fontWeight: FontWeight.w700)),
      ],
    );
  }
}
