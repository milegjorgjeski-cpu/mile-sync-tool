// lib/core/project_provider.dart
// Central app state using Provider

import 'package:flutter/foundation.dart';
import 'models.dart';
import 'package:uuid/uuid.dart';

class ProjectProvider extends ChangeNotifier {
  MileProject? _project;
  WorkflowStep _currentStep = WorkflowStep.importAudio;
  bool _isProcessing = false;
  String? _processingMessage;
  String? _errorMessage;
  double _processingProgress = 0.0;

  // ── Getters ──────────────────────────────────────────────
  MileProject? get project => _project;
  WorkflowStep get currentStep => _currentStep;
  bool get isProcessing => _isProcessing;
  String? get processingMessage => _processingMessage;
  String? get errorMessage => _errorMessage;
  double get processingProgress => _processingProgress;
  bool get hasProject => _project != null;

  // ── Project lifecycle ─────────────────────────────────────
  void createNewProject({String title = 'New Project', String artist = ''}) {
    _project = MileProject(
      id: const Uuid().v4(),
      title: title,
      artist: artist,
    );
    _currentStep = WorkflowStep.importAudio;
    _errorMessage = null;
    notifyListeners();
  }

  void updateProjectMeta({String? title, String? artist}) {
    if (_project == null) return;
    if (title != null) _project!.title = title;
    if (artist != null) _project!.artist = artist;
    _project!.updatedAt = DateTime.now();
    notifyListeners();
  }

  // ── Audio import ──────────────────────────────────────────
  void setMainTrack(AudioTrack track) {
    _project?.mainTrack = track;
    _project?.updatedAt = DateTime.now();
    notifyListeners();
  }

  void setVocalStem(AudioTrack track) {
    _project?.vocalStem = track;
    _project?.updatedAt = DateTime.now();
    notifyListeners();
  }

  void setDrumsStem(AudioTrack track) {
    _project?.drumsStem = track;
    _project?.updatedAt = DateTime.now();
    notifyListeners();
  }

  void setBassStem(AudioTrack track) {
    _project?.bassStem = track;
    _project?.updatedAt = DateTime.now();
    notifyListeners();
  }

  void setOtherStem(AudioTrack track) {
    _project?.otherStem = track;
    _project?.updatedAt = DateTime.now();
    notifyListeners();
  }

  void removeTrack(AudioTrackType type) {
    if (_project == null) return;
    switch (type) {
      case AudioTrackType.main:
        _project!.mainTrack = null;
        break;
      case AudioTrackType.vocalStem:
        _project!.vocalStem = null;
        break;
      case AudioTrackType.drumsStem:
        _project!.drumsStem = null;
        break;
      case AudioTrackType.bassStem:
        _project!.bassStem = null;
        break;
      case AudioTrackType.otherStem:
        _project!.otherStem = null;
        break;
    }
    notifyListeners();
  }

  // ── Lyrics ────────────────────────────────────────────────
  void setLyrics(LyricsDocument doc) {
    _project?.lyrics = doc;
    _project?.updatedAt = DateTime.now();
    notifyListeners();
  }

  void updateLyricsLine(int index, LyricsLine line) {
    if (_project?.lyrics == null) return;
    final lines = List<LyricsLine>.from(_project!.lyrics!.lines);
    if (index >= 0 && index < lines.length) {
      lines[index] = line;
      _project!.lyrics = LyricsDocument(
        rawText: _project!.lyrics!.rawText,
        lines: lines,
        format: _project!.lyrics!.format,
      );
      notifyListeners();
    }
  }

  void clearLyricsTiming() {
    if (_project?.lyrics == null) return;
    final lines = _project!.lyrics!.lines
        .map((l) => LyricsLine(index: l.index, text: l.text))
        .toList();
    _project!.lyrics = LyricsDocument(
      rawText: _project!.lyrics!.rawText,
      lines: lines,
      format: _project!.lyrics!.format,
    );
    notifyListeners();
  }

  // ── Transpose ─────────────────────────────────────────────
  void setTransposeSemitones(int semitones) {
    if (_project == null) return;
    _project!.transposeSemitones = semitones.clamp(-12, 12);
    notifyListeners();
  }

  // ── Trim ─────────────────────────────────────────────────
  void setTrimSettings(TrimSettings settings) {
    _project?.trimSettings = settings;
    notifyListeners();
  }

  // ── Crossfade ─────────────────────────────────────────────
  void setCrossfadeSettings(CrossfadeSettings settings) {
    _project?.crossfadeSettings = settings;
    notifyListeners();
  }

  // ── Workflow navigation ───────────────────────────────────
  void goToStep(WorkflowStep step) {
    _currentStep = step;
    _errorMessage = null;
    notifyListeners();
  }

  void nextStep() {
    final steps = WorkflowStep.values;
    final idx = steps.indexOf(_currentStep);
    if (idx < steps.length - 1) {
      _currentStep = steps[idx + 1];
      _errorMessage = null;
      notifyListeners();
    }
  }

  void previousStep() {
    final steps = WorkflowStep.values;
    final idx = steps.indexOf(_currentStep);
    if (idx > 0) {
      _currentStep = steps[idx - 1];
      _errorMessage = null;
      notifyListeners();
    }
  }

  // ── Processing state ──────────────────────────────────────
  void startProcessing(String message) {
    _isProcessing = true;
    _processingMessage = message;
    _processingProgress = 0.0;
    _errorMessage = null;
    notifyListeners();
  }

  void updateProgress(double progress, {String? message}) {
    _processingProgress = progress.clamp(0.0, 1.0);
    if (message != null) _processingMessage = message;
    notifyListeners();
  }

  void finishProcessing({String? message}) {
    _isProcessing = false;
    _processingMessage = message;
    _processingProgress = 1.0;
    notifyListeners();
  }

  void setError(String message) {
    _isProcessing = false;
    _errorMessage = message;
    _processingProgress = 0.0;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ── Reset ─────────────────────────────────────────────────
  void reset() {
    _project = null;
    _currentStep = WorkflowStep.importAudio;
    _isProcessing = false;
    _processingMessage = null;
    _errorMessage = null;
    _processingProgress = 0.0;
    notifyListeners();
  }
}
