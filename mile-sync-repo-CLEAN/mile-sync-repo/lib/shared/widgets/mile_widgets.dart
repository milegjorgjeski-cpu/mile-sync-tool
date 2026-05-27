// lib/shared/widgets/mile_widgets.dart
// Reusable UI components for Mile Sync Tool

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────
// Mile Action Button - large touch-friendly button
// ─────────────────────────────────────────────────────────────
class MileActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool isLoading;
  final bool isSuccess;
  final Color? color;

  const MileActionButton({
    super.key,
    required this.label,
    required this.icon,
    this.onTap,
    this.isLoading = false,
    this.isSuccess = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final bg = color ?? MileColors.accent;
    return Material(
      color: onTap == null
          ? MileColors.bg3
          : (isSuccess ? MileColors.success : bg),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: MileColors.bg0,
                  ),
                )
              else
                Icon(
                  isSuccess ? Icons.check : icon,
                  color: MileColors.bg0,
                  size: 20,
                ),
              const SizedBox(width: 12),
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  color: MileColors.bg0,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 2.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Mile File Drop Card - import tile
// ─────────────────────────────────────────────────────────────
class MileFileCard extends StatelessWidget {
  final String label;
  final String? fileName;
  final String hint;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  final Color? accentColor;

  const MileFileCard({
    super.key,
    required this.label,
    required this.hint,
    required this.icon,
    required this.onTap,
    this.fileName,
    this.onClear,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final hasFile = fileName != null;
    final accent = accentColor ?? MileColors.accent;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: MileColors.bg2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: hasFile ? accent.withOpacity(0.6) : const Color(0xFF2A2D35),
            width: hasFile ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: hasFile
                    ? accent.withOpacity(0.15)
                    : MileColors.bg3,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon,
                  color: hasFile ? accent : MileColors.textDim, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: MileColors.textSecondary,
                      fontSize: 11,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasFile ? fileName! : hint,
                    style: TextStyle(
                      color: hasFile
                          ? MileColors.textPrimary
                          : MileColors.textDim,
                      fontSize: 13,
                      fontWeight:
                          hasFile ? FontWeight.w500 : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (hasFile && onClear != null)
              IconButton(
                icon: const Icon(Icons.close,
                    color: MileColors.textDim, size: 18),
                onTap: onClear,
                constraints: const BoxConstraints(
                    minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
              )
            else
              const Icon(Icons.add,
                  color: MileColors.textDim, size: 18),
          ],
        ),
      ),
    );
  }
}

// Fixing the InkWell → IconButton issue
extension on IconButton {
  // No-op, just keeping onTap-like pattern consistent
}

// ─────────────────────────────────────────────────────────────
// Mile Section Header
// ─────────────────────────────────────────────────────────────
class MileSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const MileSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    color: MileColors.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.5,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: MileColors.textDim,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Mile Status Badge
// ─────────────────────────────────────────────────────────────
class MileStatusBadge extends StatelessWidget {
  final String label;
  final MileStatus status;

  const MileStatusBadge({
    super.key,
    required this.label,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case MileStatus.done:
        color = MileColors.success;
        break;
      case MileStatus.active:
        color = MileColors.accent;
        break;
      case MileStatus.pending:
        color = MileColors.textDim;
        break;
      case MileStatus.error:
        color = MileColors.error;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5), width: 1),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

enum MileStatus { done, active, pending, error }

// ─────────────────────────────────────────────────────────────
// Processing Overlay
// ─────────────────────────────────────────────────────────────
class ProcessingOverlay extends StatelessWidget {
  final String message;
  final double progress;

  const ProcessingOverlay({
    super.key,
    required this.message,
    this.progress = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: MileColors.bg0.withOpacity(0.92),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 56,
              height: 56,
              child: CircularProgressIndicator(
                color: MileColors.accent,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              message,
              style: const TextStyle(
                color: MileColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 200,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress > 0 ? progress : null,
                  backgroundColor: MileColors.bg3,
                  color: MileColors.accent,
                  minHeight: 4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Error Banner
// ─────────────────────────────────────────────────────────────
class MileErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onDismiss;

  const MileErrorBanner({
    super.key,
    required this.message,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MileColors.error.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: MileColors.error.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline,
              color: MileColors.error, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                  color: MileColors.error, fontSize: 13),
            ),
          ),
          if (onDismiss != null)
            GestureDetector(
              onTap: onDismiss,
              child: const Icon(Icons.close,
                  color: MileColors.error, size: 16),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Semitone Stepper
// ─────────────────────────────────────────────────────────────
class SemitoneStepper extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const SemitoneStepper({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _StepButton(
          icon: Icons.remove,
          onTap: value > -12 ? () => onChanged(value - 1) : null,
        ),
        const SizedBox(width: 16),
        Container(
          width: 80,
          height: 56,
          decoration: BoxDecoration(
            color: MileColors.bg2,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: value != 0
                  ? MileColors.accent.withOpacity(0.6)
                  : const Color(0xFF2A2D35),
            ),
          ),
          child: Center(
            child: Text(
              value == 0
                  ? '0'
                  : value > 0
                      ? '+$value'
                      : '$value',
              style: TextStyle(
                color: value != 0
                    ? MileColors.accentGlow
                    : MileColors.textSecondary,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        _StepButton(
          icon: Icons.add,
          onTap: value < 12 ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _StepButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: onTap != null ? MileColors.bg3 : MileColors.bg2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF2A2D35)),
        ),
        child: Icon(
          icon,
          color: onTap != null
              ? MileColors.textPrimary
              : MileColors.textDim,
          size: 24,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Waveform placeholder (replaced by audio_waveforms in screens)
// ─────────────────────────────────────────────────────────────
class WaveformPlaceholder extends StatelessWidget {
  final double height;
  final String label;

  const WaveformPlaceholder({
    super.key,
    this.height = 80,
    this.label = 'No audio loaded',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: MileColors.bg2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2A2D35)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.graphic_eq,
                color: MileColors.textDim, size: 28),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(
                    color: MileColors.textDim, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
