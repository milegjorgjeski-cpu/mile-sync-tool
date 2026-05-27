import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../../core/constants/app_constants.dart';

class ProjectRepository {
  static final ProjectRepository _instance = ProjectRepository._internal();
  factory ProjectRepository() => _instance;
  ProjectRepository._internal();

  late Box<Project> _box;
  final _uuid = const Uuid();

  Future<void> init() async {
    _box = await Hive.openBox<Project>(AppConstants.projectsBox);
  }

  // ── CRUD ────────────────────────────────────────────────────────────────

  List<Project> getAll() {
    final projects = _box.values.toList();
    projects.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return projects;
  }

  Project? getById(String id) {
    return _box.values.firstWhere(
      (p) => p.id == id,
      orElse: () => throw StateError('Project not found: $id'),
    );
  }

  Future<Project> create({required String name}) async {
    final project = Project(
      id: _uuid.v4(),
      name: name,
    );
    await _box.put(project.id, project);
    return project;
  }

  Future<void> save(Project project) async {
    project.updatedAt = DateTime.now();
    await _box.put(project.id, project);
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
  }

  Future<void> deleteAll() async {
    await _box.clear();
  }

  // ── Convenience updaters ────────────────────────────────────────────────

  Future<void> updateAudio(String id, {
    required String audioPath,
    required AudioFormat format,
    required int durationMs,
  }) async {
    final project = getById(id);
    if (project == null) return;
    project.audioPath = audioPath;
    project.audioFormat = format;
    project.durationMs = durationMs;
    // Init trim end to full duration
    project.trim.endMs = durationMs;
    await save(project);
  }

  Future<void> updateLyrics(String id, List<LyricLine> lyrics, {bool synced = false}) async {
    final project = getById(id);
    if (project == null) return;
    project.lyrics = lyrics;
    project.lyricsAreSynced = synced;
    await save(project);
  }

  Future<void> updateStems(String id, StemSet stems) async {
    final project = getById(id);
    if (project == null) return;
    project.stems = stems;
    await save(project);
  }

  Future<void> updateTranspose(String id, TransposeSettings settings) async {
    final project = getById(id);
    if (project == null) return;
    project.transpose = settings;
    await save(project);
  }

  Future<void> updateTrim(String id, TrimSettings settings) async {
    final project = getById(id);
    if (project == null) return;
    project.trim = settings;
    await save(project);
  }

  Future<void> updateCrossfade(String id, CrossfadeSettings settings) async {
    final project = getById(id);
    if (project == null) return;
    project.crossfade = settings;
    await save(project);
  }

  Future<void> updateExportSettings(String id, ExportSettings settings) async {
    final project = getById(id);
    if (project == null) return;
    project.exportSettings = settings;
    await save(project);
  }

  int get count => _box.length;
}
