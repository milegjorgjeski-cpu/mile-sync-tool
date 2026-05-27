import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/export_service.dart';
import '../../data/models/models.dart';
import '../../data/repositories/project_repository.dart';
import '../../shared/widgets/shared_widgets.dart';

class ExportScreen extends StatefulWidget {
  final Project project;
  const ExportScreen({super.key, required this.project});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  late Project _project;
  final _repo = ProjectRepository();
  final _exportSvc = ExportService();

  bool _exporting = false;
  double _exportProgress = 0.0;
  String _exportStatus = '';
  ExportResult? _lastResult;

  late bool _embedSylt;
  late bool _embedUslt;
  late bool _exportLrc;
  late bool _exportTxt;
  late bool _ketronStructure;
  late bool _exportStems;
  late String _bitrate;

  @override
  void initState() {
    super.initState();
    _project = widget.project;
    final s = _project.exportSettings;
    _embedSylt = s.embedSylt;
    _embedUslt = s.embedUslt;
    _exportLrc = s.exportLrc;
    _exportTxt = s.exportTxt;
    _ketronStructure = s.ketronStructure;
    _exportStems = s.exportStems;
    _bitrate = s.bitrate;
  }

  Future<void> _saveSettings() async {
    await _repo.updateExportSettings(_project.id, ExportSettings(
      embedSylt: _embedSylt, embedUslt: _embedUslt,
      exportLrc: _exportLrc, exportTxt: _exportTxt,
      ketronStructure: _ketronStructure, exportStems: _exportStems,
      bitrate: _bitrate,
    ));
    setState(() { _project = _repo.getById(_project.id)!; });
  }

  Future<void> _runExport() async {
    await _saveSettings();
    setState(() { _exporting = true; _exportProgress = 0; _exportStatus = ''; _lastResult = null; });
    final result = await _exportSvc.exportProject(
      project: _project,
      onProgress: (p, s) { if (mounted) setState(() { _exportProgress = p; _exportStatus = s; }); },
    );
    setState(() { _exporting = false; _lastResult = result; });
    if (result.success) {
      _showSnack('Export complete! ${result.exportedFiles.length} files saved ✓');
    } else {
      _showSnack('Export failed: ${result.errorMessage}', isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.dangerDim : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final hasSynced = _project.lyricsAreSynced;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Export')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Project summary
          MstCard(
            borderColor: AppColors.primary.withOpacity(0.3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_project.name, style: AppTextStyles.displayMedium),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 6, children: [
                  StatusBadge(label: _project.audioPath != null ? 'Audio ✓' : 'No Audio',
                      color: _project.audioPath != null ? AppColors.accent : AppColors.danger),
                  StatusBadge(label: hasSynced ? 'Synced ✓' : 'No Sync',
                      color: hasSynced ? AppColors.accent : AppColors.textSecondary),
                  if (_project.stems != null)
                    StatusBadge(label: 'Stems ✓', color: AppColors.primary),
                  if (_project.transpose.semitones != 0)
                    StatusBadge(label: '${_project.transpose.semitones > 0 ? "+" : ""}${_project.transpose.semitones}st',
                        color: AppColors.primary),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Output format section
          const SectionHeader(title: 'Output Files'),
          const SizedBox(height: 12),
          MstCard(
            child: Column(
              children: [
                _ToggleRow(label: 'MP3 with SYLT (karaoke)', subtitle: 'Embedded synced lyrics in ID3 tag',
                    value: _embedSylt, enabled: hasSynced,
                    onChanged: (v) => setState(() => _embedSylt = v)),
                const Divider(height: 16),
                _ToggleRow(label: 'MP3 with plain lyrics (USLT)', subtitle: 'Unsynced text in ID3 tag',
                    value: _embedUslt, onChanged: (v) => setState(() => _embedUslt = v)),
                const Divider(height: 16),
                _ToggleRow(label: 'LRC file', subtitle: 'Timestamped lyrics file',
                    value: _exportLrc, enabled: hasSynced,
                    onChanged: (v) => setState(() => _exportLrc = v)),
                const Divider(height: 16),
                _ToggleRow(label: 'TXT file', subtitle: 'Plain text lyrics',
                    value: _exportTxt, onChanged: (v) => setState(() => _exportTxt = v)),
                const Divider(height: 16),
                _ToggleRow(label: 'Export stems', subtitle: 'Copy stem files to output folder',
                    value: _exportStems, enabled: _project.stems != null,
                    onChanged: (v) => setState(() => _exportStems = v)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Quality & structure
          const SectionHeader(title: 'Quality & Structure'),
          const SizedBox(height: 12),
          MstCard(
            child: Column(
              children: [
                // Bitrate
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('MP3 Bitrate', style: AppTextStyles.bodyLarge),
                    DropdownButton<String>(
                      value: _bitrate,
                      dropdownColor: AppColors.surfaceHigh,
                      underline: const SizedBox(),
                      style: AppTextStyles.mono.copyWith(color: AppColors.primary),
                      items: AppConstants.exportBitrates.map((b) =>
                        DropdownMenuItem(value: b, child: Text(b))).toList(),
                      onChanged: (v) { if (v != null) setState(() => _bitrate = v); },
                    ),
                  ],
                ),
                const Divider(height: 16),
                _ToggleRow(
                  label: 'Ketron folder structure',
                  subtitle: 'audio/ and lyrics/ subfolders',
                  value: _ketronStructure,
                  onChanged: (v) => setState(() => _ketronStructure = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Progress / result
          if (_exporting) ...[
            MstCard(
              child: Column(
                children: [
                  Text(_exportStatus, style: AppTextStyles.bodyMedium),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(value: _exportProgress),
                  const SizedBox(height: 8),
                  Text('${(_exportProgress * 100).round()}%',
                      style: AppTextStyles.mono.copyWith(color: AppColors.primary)),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          if (_lastResult != null && _lastResult!.success) ...[
            MstCard(
              borderColor: AppColors.accent.withOpacity(0.4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.check_circle, color: AppColors.accent, size: 20),
                    const SizedBox(width: 8),
                    Text('Export complete!', style: AppTextStyles.titleLarge.copyWith(color: AppColors.accent)),
                  ]),
                  const SizedBox(height: 10),
                  Text('Output: ${_lastResult!.outputDir}', style: AppTextStyles.mono),
                  const SizedBox(height: 8),
                  ..._lastResult!.exportedFiles.map((f) {
                    final name = f.split('/').last;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(children: [
                        const Icon(Icons.insert_drive_file, size: 14, color: AppColors.accent),
                        const SizedBox(width: 6),
                        Text(name, style: AppTextStyles.mono),
                      ]),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Export button
          MstButton(
            label: _exporting ? 'Exporting…' : 'EXPORT NOW',
            icon: _exporting ? null : Icons.download,
            loading: _exporting,
            onTap: _exporting ? null : _runExport,
            fullWidth: true,
          ),

          if (_project.audioPath == null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text('⚠ No audio loaded — go back to Import',
                  style: AppTextStyles.mono.copyWith(color: AppColors.danger),
                  textAlign: TextAlign.center),
            ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final String? subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.label, this.subtitle, required this.value,
    this.enabled = true, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: AppTextStyles.bodyLarge),
              if (subtitle != null) Text(subtitle!, style: AppTextStyles.bodyMedium),
            ]),
          ),
          Switch(value: value && enabled, onChanged: enabled ? onChanged : null),
        ],
      ),
    );
  }
}
