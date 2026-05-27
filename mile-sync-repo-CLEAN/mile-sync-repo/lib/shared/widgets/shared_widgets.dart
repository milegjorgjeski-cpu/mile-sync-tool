import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

// ─── MstCard ────────────────────────────────────────────────────────────────

class MstCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? borderColor;
  final VoidCallback? onTap;

  const MstCard({
    super.key,
    required this.child,
    this.padding,
    this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget card = Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor ?? AppColors.surfaceBorder,
          width: 1,
        ),
      ),
      child: child,
    );

    if (onTap != null) {
      card = InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: card,
      );
    }

    return card;
  }
}

// ─── MstButton ──────────────────────────────────────────────────────────────

enum MstButtonVariant { primary, secondary, danger, ghost }

class MstButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final MstButtonVariant variant;
  final IconData? icon;
  final bool loading;
  final bool fullWidth;

  const MstButton({
    super.key,
    required this.label,
    this.onTap,
    this.variant = MstButtonVariant.primary,
    this.icon,
    this.loading = false,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _resolveColors();
    final disabled = onTap == null || loading;

    Widget content = Row(
      mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colors.$2,
            ),
          )
        else if (icon != null) ...[
          Icon(icon, size: 18, color: colors.$2),
          const SizedBox(width: 8),
        ],
        Text(
          label,
          style: AppTextStyles.labelLarge.copyWith(
            color: colors.$2,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );

    return Opacity(
      opacity: disabled ? 0.45 : 1.0,
      child: Material(
        color: colors.$1,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: disabled ? null : onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: variant == MstButtonVariant.secondary || variant == MstButtonVariant.ghost
                  ? Border.all(color: AppColors.surfaceBorder)
                  : null,
            ),
            child: Center(child: content),
          ),
        ),
      ),
    );
  }

  (Color, Color) _resolveColors() {
    switch (variant) {
      case MstButtonVariant.primary:
        return (AppColors.primary, AppColors.background);
      case MstButtonVariant.secondary:
        return (AppColors.surfaceHigh, AppColors.textPrimary);
      case MstButtonVariant.danger:
        return (AppColors.danger, Colors.white);
      case MstButtonVariant.ghost:
        return (Colors.transparent, AppColors.textSecondary);
    }
  }
}

// ─── SectionHeader ───────────────────────────────────────────────────────────

class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final String? subtitle;

  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.toUpperCase(),
                style: AppTextStyles.titleMedium,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: AppTextStyles.bodyMedium),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

// ─── StatusBadge ─────────────────────────────────────────────────────────────

class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label.toUpperCase(),
            style: AppTextStyles.mono.copyWith(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── MstSlider ───────────────────────────────────────────────────────────────

class MstSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String displayValue;
  final ValueChanged<double> onChanged;
  final Color? activeColor;

  const MstSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.displayValue,
    required this.onChanged,
    this.divisions,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppTextStyles.bodyMedium),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: Text(
                displayValue,
                style: AppTextStyles.mono.copyWith(
                  color: activeColor ?? AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: activeColor ?? AppColors.primary,
            inactiveTrackColor: AppColors.waveformFill,
            thumbColor: activeColor ?? AppColors.primary,
            overlayColor: (activeColor ?? AppColors.primary).withOpacity(0.2),
            trackHeight: 3,
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${min.toInt()}', style: AppTextStyles.mono),
            Text('${max.toInt()}', style: AppTextStyles.mono),
          ],
        ),
      ],
    );
  }
}

// ─── MstTextField ────────────────────────────────────────────────────────────

class MstTextField extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final int maxLines;

  const MstTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.onChanged,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.bodyMedium),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          onChanged: onChanged,
          maxLines: maxLines,
          style: AppTextStyles.bodyLarge,
          decoration: InputDecoration(
            hintText: hint,
          ),
        ),
      ],
    );
  }
}

// ─── EmptyState ──────────────────────────────────────────────────────────────

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 56, color: AppColors.textDisabled),
            const SizedBox(height: 16),
            Text(
              title,
              style: AppTextStyles.titleLarge.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: AppTextStyles.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

// ─── StemColorDot ────────────────────────────────────────────────────────────

class StemColorDot extends StatelessWidget {
  final String stemName;
  final bool hasFile;

  const StemColorDot({super.key, required this.stemName, required this.hasFile});

  static Color colorFor(String name) {
    switch (name) {
      case 'vocals': return AppColors.stemVocals;
      case 'drums': return AppColors.stemDrums;
      case 'bass': return AppColors.stemBass;
      case 'other': return AppColors.stemOther;
      default: return AppColors.textDisabled;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = colorFor(stemName);
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: hasFile ? color : Colors.transparent,
        border: Border.all(
          color: hasFile ? color : AppColors.textDisabled,
          width: 1.5,
        ),
      ),
    );
  }
}
