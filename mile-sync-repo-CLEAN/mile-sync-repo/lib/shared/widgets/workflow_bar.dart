// lib/shared/widgets/workflow_bar.dart
// Top workflow step indicator for the 5-step pipeline

import 'package:flutter/material.dart';
import '../../core/models.dart';
import '../theme/app_theme.dart';

class WorkflowBar extends StatelessWidget {
  final WorkflowStep currentStep;
  final Function(WorkflowStep) onStepTap;

  const WorkflowBar({
    super.key,
    required this.currentStep,
    required this.onStepTap,
  });

  @override
  Widget build(BuildContext context) {
    final steps = WorkflowStep.values;
    final currentIdx = steps.indexOf(currentStep);

    return Container(
      color: MileColors.bg1,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Row(
        children: steps.asMap().entries.map((entry) {
          final idx = entry.key;
          final step = entry.value;
          final isDone = idx < currentIdx;
          final isActive = idx == currentIdx;

          return Expanded(
            child: GestureDetector(
              onTap: () => onStepTap(step),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Step dot + connector line
                  Row(
                    children: [
                      if (idx > 0)
                        Expanded(
                          child: Container(
                            height: 1.5,
                            color: isDone || isActive
                                ? MileColors.accent.withOpacity(0.6)
                                : const Color(0xFF2A2D35),
                          ),
                        ),
                      _StepDot(isDone: isDone, isActive: isActive, index: idx),
                      if (idx < steps.length - 1)
                        Expanded(
                          child: Container(
                            height: 1.5,
                            color: isDone
                                ? MileColors.accent.withOpacity(0.6)
                                : const Color(0xFF2A2D35),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Label
                  Text(
                    step.label,
                    style: TextStyle(
                      color: isActive
                          ? MileColors.accent
                          : isDone
                              ? MileColors.textSecondary
                              : MileColors.textDim,
                      fontSize: 9,
                      fontWeight: isActive
                          ? FontWeight.w800
                          : FontWeight.w500,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final bool isDone;
  final bool isActive;
  final int index;

  const _StepDot({
    required this.isDone,
    required this.isActive,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color border;
    Widget child;

    if (isDone) {
      bg = MileColors.success.withOpacity(0.2);
      border = MileColors.success;
      child = const Icon(Icons.check, color: MileColors.success, size: 10);
    } else if (isActive) {
      bg = MileColors.accent.withOpacity(0.2);
      border = MileColors.accent;
      child = Container(
        width: 6,
        height: 6,
        decoration: const BoxDecoration(
          color: MileColors.accent,
          shape: BoxShape.circle,
        ),
      );
    } else {
      bg = MileColors.bg2;
      border = const Color(0xFF2A2D35);
      child = Text(
        '${index + 1}',
        style: const TextStyle(
          color: MileColors.textDim,
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: border, width: 1.5),
      ),
      child: Center(child: child),
    );
  }
}
