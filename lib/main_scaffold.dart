// lib/main_scaffold.dart
// Main app shell: AppBar + WorkflowBar + screen routing

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/models.dart';
import 'core/project_provider.dart';
import 'features/import/import_screen.dart';
import 'features/lyrics_sync/lyrics_sync_screen.dart';
import 'features/transpose/transpose_screen.dart';
import 'features/trim/trim_screen.dart';
import 'features/export/export_screen.dart';
import 'shared/theme/app_theme.dart';
import 'shared/widgets/workflow_bar.dart';
import 'shared/widgets/mile_widgets.dart';

class MainScaffold extends StatelessWidget {
  const MainScaffold({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ProjectProvider>();

    if (!prov.hasProject) {
      return const _WelcomeScreen();
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('MILE SYNC'),
            const SizedBox(width: 8),
            if (prov.project?.title.isNotEmpty == true)
              Expanded(
                child: Text(
                  '· ${prov.project!.title}',
                  style: const TextStyle(
                    color: MileColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'New project',
            onPressed: () => _confirmNewProject(context, prov),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(58),
          child: WorkflowBar(
            currentStep: prov.currentStep,
            onStepTap: (step) => prov.goToStep(step),
          ),
        ),
      ),
      body: Stack(
        children: [
          _buildScreen(prov.currentStep),
          if (prov.errorMessage != null)
            Positioned(
              top: 8,
              left: 16,
              right: 16,
              child: MileErrorBanner(
                message: prov.errorMessage!,
                onDismiss: () => prov.clearError(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScreen(WorkflowStep step) {
    switch (step) {
      case WorkflowStep.importAudio:
        return const ImportScreen();
      case WorkflowStep.syncLyrics:
        return const LyricsSyncScreen();
      case WorkflowStep.transpose:
        return const TransposeScreen();
      case WorkflowStep.cutAndCrossfade:
        return const TrimScreen();
      case WorkflowStep.export:
        return const ExportScreen();
    }
  }

  Future<void> _confirmNewProject(
      BuildContext context, ProjectProvider prov) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MileColors.bg2,
        title: const Text('New Project',
            style: TextStyle(color: MileColors.textPrimary)),
        content: const Text(
          'Start a new project? Current work will be lost.',
          style: TextStyle(color: MileColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('NEW PROJECT'),
          ),
        ],
      ),
    );
    if (ok == true) {
      prov.createNewProject();
    }
  }
}

// ── Welcome / Home Screen ─────────────────────────────────────
class _WelcomeScreen extends StatelessWidget {
  const _WelcomeScreen();

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<ProjectProvider>(context, listen: false);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),

              // Logo / identity
              Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: MileColors.accent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: MileColors.accent.withOpacity(0.4),
                          width: 1.5),
                    ),
                    child: const Icon(
                      Icons.queue_music,
                      color: MileColors.accent,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'MILE SYNC TOOL',
                    style: TextStyle(
                      color: MileColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 4.0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Balkan Live Performer Workflow',
                    style: TextStyle(
                      color: MileColors.textSecondary,
                      fontSize: 14,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Offline · No Cloud · No Subscriptions',
                    style: TextStyle(
                      color: MileColors.textDim,
                      fontSize: 11,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // Feature bullets
              _FeaturePill(icon: Icons.sync_alt, label: 'Auto Lyrics Sync via Whisper'),
              const SizedBox(height: 8),
              _FeaturePill(icon: Icons.tune, label: 'Pitch Transpose (Drums Protected)'),
              const SizedBox(height: 8),
              _FeaturePill(icon: Icons.content_cut, label: 'Trim · Fade · Cut Silence'),
              const SizedBox(height: 8),
              _FeaturePill(icon: Icons.label, label: 'SYLT + ID3 MP3 Export'),
              const SizedBox(height: 8),
              _FeaturePill(icon: Icons.folder, label: 'Ketron + MobileSheets Ready'),

              const Spacer(),

              // Start
              MileActionButton(
                label: 'New Project',
                icon: Icons.add,
                onTap: () {
                  prov.createNewProject(title: 'New Project', artist: '');
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeaturePill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: MileColors.bg2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2A2D35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: MileColors.accent, size: 18),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              color: MileColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
