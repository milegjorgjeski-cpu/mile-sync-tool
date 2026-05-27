import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../../data/repositories/project_repository.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../import/import_screen.dart';

// ── Provider ─────────────────────────────────────────────────────────────────

final projectsProvider = StateNotifierProvider<ProjectsNotifier, List<Project>>((ref) {
  return ProjectsNotifier();
});

class ProjectsNotifier extends StateNotifier<List<Project>> {
  final _repo = ProjectRepository();

  ProjectsNotifier() : super([]) {
    _load();
  }

  void _load() {
    state = _repo.getAll();
  }

  Future<Project> createProject(String name) async {
    final project = await _repo.create(name: name);
    _load();
    return project;
  }

  Future<void> deleteProject(String id) async {
    await _repo.delete(id);
    _load();
  }

  void refresh() => _load();
}

// ── Screen ───────────────────────────────────────────────────────────────────

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.music_note, color: AppColors.background, size: 16),
            ),
            const SizedBox(width: 10),
            const Text('MILE SYNC'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showNewProjectDialog(context, ref),
            color: AppColors.primary,
            iconSize: 24,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: projects.isEmpty
          ? EmptyState(
              icon: Icons.music_note_outlined,
              title: 'No projects yet',
              subtitle: 'Create your first project to get started',
              action: MstButton(
                label: 'New Project',
                icon: Icons.add,
                onTap: () => _showNewProjectDialog(context, ref),
              ),
            )
          : _ProjectList(projects: projects),
    );
  }

  void _showNewProjectDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.surfaceBorder),
        ),
        title: const Text('New Project', style: AppTextStyles.titleLarge),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: AppTextStyles.bodyLarge,
          decoration: const InputDecoration(
            hintText: 'Song title…',
          ),
          onSubmitted: (_) => _createAndOpen(ctx, context, ref, controller.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
          ),
          MstButton(
            label: 'Create',
            onTap: () => _createAndOpen(ctx, context, ref, controller.text),
          ),
        ],
      ),
    );
  }

  Future<void> _createAndOpen(
    BuildContext dialogCtx,
    BuildContext screenCtx,
    WidgetRef ref,
    String name,
  ) async {
    if (name.trim().isEmpty) return;
    Navigator.pop(dialogCtx);
    final project = await ref.read(projectsProvider.notifier).createProject(name.trim());
    if (screenCtx.mounted) {
      _openProject(screenCtx, project);
    }
  }

  void _openProject(BuildContext context, Project project) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ImportScreen(project: project)),
    );
  }
}

// ── Project List ─────────────────────────────────────────────────────────────

class _ProjectList extends StatelessWidget {
  final List<Project> projects;
  const _ProjectList({required this.projects});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: projects.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) => _ProjectCard(project: projects[i]),
    );
  }
}

// ── Project Card ─────────────────────────────────────────────────────────────

class _ProjectCard extends ConsumerWidget {
  final Project project;
  const _ProjectCard({required this.project});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: ValueKey(project.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.dangerDim,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: AppColors.danger),
      ),
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) {
        ref.read(projectsProvider.notifier).deleteProject(project.id);
      },
      child: MstCard(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ImportScreen(project: project)),
          );
        },
        child: Row(
          children: [
            _StatusIcon(status: project.status),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(project.name, style: AppTextStyles.bodyLarge),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _statusBadge(project.status),
                      const SizedBox(width: 8),
                      if (project.audioPath != null)
                        Text(
                          _formatDuration(project.durationMs),
                          style: AppTextStyles.mono,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (project.stems != null) ...[
              _StemDots(stems: project.stems!),
              const SizedBox(width: 12),
            ],
            const Icon(Icons.chevron_right, color: AppColors.textDisabled, size: 18),
          ],
        ),
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.surfaceBorder),
        ),
        title: const Text('Delete project?', style: AppTextStyles.titleLarge),
        content: Text(
          'This cannot be undone.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(ProjectStatus status) {
    switch (status) {
      case ProjectStatus.empty:
        return const StatusBadge(label: 'Empty', color: AppColors.textDisabled);
      case ProjectStatus.hasAudio:
        return const StatusBadge(label: 'Audio', color: AppColors.stemBass);
      case ProjectStatus.hasLyrics:
        return const StatusBadge(label: 'Lyrics', color: AppColors.stemVocals);
      case ProjectStatus.hasSynced:
        return const StatusBadge(label: 'Synced', color: AppColors.accent);
      case ProjectStatus.hasStems:
        return const StatusBadge(label: 'Stems', color: AppColors.primary);
      case ProjectStatus.readyToExport:
        return const StatusBadge(label: 'Ready', color: AppColors.accent, icon: Icons.check);
    }
  }

  String _formatDuration(int ms) {
    final duration = Duration(milliseconds: ms);
    final m = duration.inMinutes;
    final s = duration.inSeconds.remainder(60);
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

// ── Status icon ──────────────────────────────────────────────────────────────

class _StatusIcon extends StatelessWidget {
  final ProjectStatus status;
  const _StatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;
    switch (status) {
      case ProjectStatus.empty:
        icon = Icons.radio_button_unchecked;
        color = AppColors.textDisabled;
      case ProjectStatus.hasAudio:
        icon = Icons.audiotrack;
        color = AppColors.stemBass;
      case ProjectStatus.hasLyrics:
        icon = Icons.text_fields;
        color = AppColors.stemVocals;
      case ProjectStatus.hasSynced:
        icon = Icons.sync;
        color = AppColors.accent;
      case ProjectStatus.hasStems:
        icon = Icons.layers;
        color = AppColors.primary;
      case ProjectStatus.readyToExport:
        icon = Icons.check_circle;
        color = AppColors.accent;
    }
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

// ── Stem dots preview ─────────────────────────────────────────────────────────

class _StemDots extends StatelessWidget {
  final StemSet stems;
  const _StemDots({required this.stems});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: ['vocals', 'drums', 'bass', 'other'].map((name) {
        final has = stems.pathForStem(name) != null;
        return Padding(
          padding: const EdgeInsets.only(left: 4),
          child: StemColorDot(stemName: name, hasFile: has),
        );
      }).toList(),
    );
  }
}
