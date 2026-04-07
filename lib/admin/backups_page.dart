import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';

import '/theme/theme.dart';
import 'backup_service.dart';

TextStyle _uiStyle({
  Color? color,
  double? fontSize,
  FontWeight? fontWeight,
  double? height,
}) {
  return TextStyle(
    color: color,
    fontSize: fontSize,
    fontWeight: fontWeight,
    height: height,
  );
}

TextStyle _monoStyle({
  Color? color,
  double? fontSize,
  FontWeight? fontWeight,
  double? height,
}) {
  return TextStyle(
    color: color,
    fontSize: fontSize,
    fontWeight: fontWeight,
    height: height,
    fontFamily: 'monospace',
  );
}

class BackupsPage extends StatefulWidget {
  const BackupsPage({super.key});

  static const accent = Color(0xFF10B981);

  @override
  State<BackupsPage> createState() => _BackupsPageState();
}

class _BackupsPageState extends State<BackupsPage> {
  final _service = BackupService.instance;

  bool _loading = true;
  bool _saving = false;
  BackupSettings _settings = const BackupSettings();
  String _recommendedPath = '';
  String _appFolderPath = '';
  String _resolvedRootPath = '';
  String _resolvedBackupsPath = '';

  @override
  void initState() {
    super.initState();
    _service.addListener(_onServiceChanged);
    _load();
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceChanged);
    super.dispose();
  }

  void _onServiceChanged() {
    if (!mounted) return;
    setState(() => _settings = _service.settings);
  }

  Future<void> _load() async {
    final settings = await _service.loadSettings();
    final recommended = await _service.recommendedRootPath();
    final appFolder = await _service.appFolderPath();
    final resolvedRoot = await _service.resolveRootPath(settings);
    final resolvedBackups = await _service.resolveBackupsRootPath(settings);
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _recommendedPath = recommended;
      _appFolderPath = appFolder;
      _resolvedRootPath = resolvedRoot;
      _resolvedBackupsPath = resolvedBackups;
      _loading = false;
    });
  }

  Future<void> _refreshResolvedPaths([BackupSettings? settings]) async {
    final target = settings ?? _settings;
    final resolvedRoot = await _service.resolveRootPath(target);
    final resolvedBackups = await _service.resolveBackupsRootPath(target);
    if (!mounted) return;
    setState(() {
      _resolvedRootPath = resolvedRoot;
      _resolvedBackupsPath = resolvedBackups;
    });
  }

  Future<void> _applySettings(BackupSettings next, {String? successMessage}) async {
    setState(() {
      _saving = true;
      _settings = next;
    });
    try {
      await _service.applySettings(next);
      await _refreshResolvedPaths(next);
      if (successMessage != null && mounted) {
        _snack(successMessage, AppDS.green);
      }
    } catch (e) {
      if (mounted) _snack('Could not save backup settings: $e', AppDS.red);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _chooseCustomFolder() async {
    final selected = await FilePicker.getDirectoryPath(
      dialogTitle: 'Choose backup folder',
      lockParentWindow: true,
    );
    if (selected == null || selected.trim().isEmpty) return;
    await _applySettings(
      _settings.copyWith(
        locationMode: BackupLocationMode.custom,
        customPath: selected,
      ),
      successMessage: 'Backup folder updated.',
    );
  }

  Future<void> _selectLocationMode(BackupLocationMode mode) async {
    if (mode == BackupLocationMode.custom &&
        (_settings.customPath == null || _settings.customPath!.trim().isEmpty)) {
      await _chooseCustomFolder();
      return;
    }
    await _applySettings(
      _settings.copyWith(locationMode: mode),
      successMessage: 'Backup destination updated.',
    );
  }

  Future<void> _openBackupFolder() async {
    try {
      final dir = Directory(_resolvedBackupsPath);
      await dir.create(recursive: true);
      await OpenFilex.open(dir.path);
    } catch (e) {
      if (mounted) _snack('Could not open backup folder: $e', AppDS.red);
    }
  }

  Future<void> _runScheduledNow() async {
    try {
      final message = await _service.runSelectedBackupsNow();
      await _refreshResolvedPaths();
      if (mounted) _snack(message, AppDS.green);
    } catch (e) {
      if (mounted) _snack('Scheduled backup failed: $e', AppDS.red);
    }
  }

  Future<void> _runOfflineNow() async {
    try {
      final message = await _service.refreshLocalMirror(reason: 'manual');
      await _refreshResolvedPaths();
      if (mounted) _snack(message, AppDS.green);
    } catch (e) {
      if (mounted) _snack('Local mirror failed: $e', AppDS.red);
    }
  }

  void _snack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }

  String _dt(DateTime? value) {
    if (value == null) return 'Not yet';
    return DateFormat('yyyy-MM-dd HH:mm').format(value.toLocal());
  }

  Future<void> _showErrorsDialog() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        final errors = _service.errors;
        return AlertDialog(
          backgroundColor: context.appSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: AppDS.red, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Backup Errors',
                  style: _uiStyle(
                    color: context.appTextPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 640,
            child: errors.isEmpty
                ? Text(
                    'No saved backup errors.',
                    style: _uiStyle(
                      color: context.appTextSecondary,
                      fontSize: 13,
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: errors.length,
                    separatorBuilder: (_, _) =>
                        Divider(color: context.appBorder, height: 18),
                    itemBuilder: (_, index) {
                      final error = errors[index];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            error.message,
                            style: _uiStyle(
                              color: context.appTextPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${error.scope} • ${_dt(error.createdAt)}',
                            style: _monoStyle(
                              color: context.appTextMuted,
                              fontSize: 11,
                            ),
                          ),
                          if (error.detail.trim().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            SelectableText(
                              error.detail,
                              style: _monoStyle(
                                color: context.appTextSecondary,
                                fontSize: 11,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
            FilledButton.tonal(
              onPressed: errors.isEmpty
                  ? null
                  : () async {
                      await _service.clearErrors();
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        _snack('Backup errors cleared.', AppDS.green);
                      }
                    },
              child: const Text('Clear Errors'),
            ),
          ],
        );
      },
    );
  }

  Map<String, Set<String>> _cloneTablesByTarget() => {
        for (final entry in _settings.tablesByTarget.entries)
          entry.key: Set<String>.from(entry.value),
      };

  Future<void> _toggleFrequency(BackupFrequency frequency, bool enabled) async {
    final next = Set<BackupFrequency>.from(_settings.frequencies);
    if (enabled) {
      next.add(frequency);
    } else {
      next.remove(frequency);
    }
    await _applySettings(
      _settings.copyWith(frequencies: next),
      successMessage: '${frequency.label} backup preference updated.',
    );
  }

  Future<void> _toggleTableForFrequency(
    BackupFrequency frequency,
    String table,
    bool enabled,
  ) async {
    final nextTargets = _cloneTablesByTarget();
    final selected = Set<String>.from(_settings.tablesForFrequency(frequency));
    if (enabled) {
      selected.add(table);
    } else {
      selected.remove(table);
    }
    nextTargets[frequency.name] = selected;
    await _applySettings(
      _settings.copyWith(tablesByTarget: nextTargets),
      successMessage: '${frequency.label} table selection updated.',
    );
  }

  Future<void> _toggleOfflineTable(String table, bool enabled) async {
    final nextTargets = _cloneTablesByTarget();
    final selected = Set<String>.from(_settings.offlineTables);
    if (enabled) {
      selected.add(table);
    } else {
      selected.remove(table);
    }
    nextTargets['local_mirror'] = selected;
    await _applySettings(
      _settings.copyWith(tablesByTarget: nextTargets),
      successMessage: 'Local mirror table selection updated.',
    );
  }

  bool get _isMobile => Platform.isAndroid || Platform.isIOS;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.appBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 56,
            decoration: BoxDecoration(
              color: context.appSurface2,
              border: Border(bottom: BorderSide(color: context.appBorder)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                if (MediaQuery.of(context).size.width < 700) ...[
                  IconButton(
                    icon: const Icon(Icons.menu_rounded, size: 20),
                    color: context.appTextSecondary,
                    tooltip: 'Menu',
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
                ],
                const Icon(Icons.backup_outlined, color: BackupsPage.accent, size: 20),
                const SizedBox(width: 10),
                Text(
                  'Backups',
                  style: _uiStyle(
                    color: context.appTextPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (_settings.localMirrorEnabled) ...[
                  IconButton(
                    tooltip: 'Refresh local mirror',
                    onPressed: (_isMobile || _saving || _service.isBusy) ? null : _runOfflineNow,
                    icon: Icon(
                      Icons.sync_rounded,
                      color: (_saving || _service.isBusy)
                          ? context.appTextMuted
                          : BackupsPage.accent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      tooltip: 'Saved backup errors',
                      onPressed: _showErrorsDialog,
                      icon: Icon(
                        Icons.error_outline_rounded,
                        color: _service.errorCount > 0
                            ? AppDS.red
                            : context.appTextMuted,
                        size: 20,
                      ),
                    ),
                    if (_service.errorCount > 0)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 18),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppDS.red,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _service.errorCount > 99
                                ? '99+'
                                : _service.errorCount.toString(),
                            textAlign: TextAlign.center,
                            style: _uiStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                if (_saving || _service.isBusy)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: BackupsPage.accent,
                    ),
                  ),
              ],
            ),
          ),
          if (_isMobile)
            Container(
              width: double.infinity,
              color: const Color(0xFFF59E0B),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.black87, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Backups are only supported on desktop (Windows / macOS / Linux). '
                      'All options are disabled on this device.',
                      style: _uiStyle(
                        color: Colors.black87,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : AbsorbPointer(
                    absorbing: _isMobile,
                    child: Opacity(
                      opacity: _isMobile ? 0.45 : 1.0,
                      child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1040),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _activationCard(context),
                            const SizedBox(height: 16),
                            _locationCard(context),
                            const SizedBox(height: 16),
                            _scheduleCard(context),
                            const SizedBox(height: 16),
                            _statusCard(context),
                            const SizedBox(height: 16),
                            _actionsCard(context),
                          ],
                        ),
                      ),
                    ),
                  ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _activationCard(BuildContext context) {
    return _SectionCard(
      title: '1. Activate Backups',
      subtitle: 'Choose which backup systems this machine should run. Both switches start disabled by default. Audit Log is reserved for the local mirror only.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ToggleRow(
            icon: Icons.event_repeat_outlined,
            title: 'Scheduled backups on login',
            subtitle: 'Checks the current day, week, month, and year after login and writes any missing snapshots.',
            value: _settings.scheduledEnabled,
            accent: BackupsPage.accent,
            onChanged: (value) => _applySettings(
              _settings.copyWith(scheduledEnabled: value),
              successMessage: value
                  ? 'Scheduled backups enabled.'
                  : 'Scheduled backups disabled.',
            ),
          ),
          Divider(color: context.appBorder, height: 1),
          _ToggleRow(
            icon: Icons.cloud_sync_outlined,
            title: 'Local database mirror',
            subtitle: 'Keeps a fresh full export in Backups/local_mirror at login and after database changes.',
            value: _settings.localMirrorEnabled,
            accent: const Color(0xFF0EA5E9),
            onChanged: (value) => _applySettings(
              _settings.copyWith(localMirrorEnabled: value),
              successMessage: value
                  ? 'Local mirror enabled.'
                  : 'Local mirror disabled.',
            ),
          ),
          const SizedBox(height: 12),
          _TableSelectorPanel(
            title: 'Local mirror tables',
            subtitle: 'These tables are exported into Backups/local_mirror. Audit Log can be selected only here.',
            tables: _service.offlineSelectableTables,
            selected: _settings.offlineTables,
            enabled: _settings.localMirrorEnabled,
            labelForTable: _service.tableLabel,
            onToggle: _toggleOfflineTable,
          ),
        ],
      ),
    );
  }

  Widget _locationCard(BuildContext context) {
    return _SectionCard(
      title: '2. Backup Location',
      subtitle: 'Pick where the root backup folder lives. The app creates Backups/Daily, Weekly, Monthly, Yearly, and local_mirror inside that root.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _LocationChoice(
                label: 'Documents',
                description: 'Recommended',
                selected: _settings.locationMode == BackupLocationMode.documents,
                onTap: () => _selectLocationMode(BackupLocationMode.documents),
              ),
              _LocationChoice(
                label: 'App Folder',
                description: 'Installed app path',
                selected: _settings.locationMode == BackupLocationMode.appFolder,
                onTap: () => _selectLocationMode(BackupLocationMode.appFolder),
              ),
              _LocationChoice(
                label: 'Custom',
                description: 'Choose your own folder',
                selected: _settings.locationMode == BackupLocationMode.custom,
                onTap: () => _selectLocationMode(BackupLocationMode.custom),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _PathBlock(
            title: 'Suggested path',
            value: _recommendedPath,
            hint: 'Documents/LIMSSphere',
          ),
          const SizedBox(height: 12),
          _PathBlock(
            title: 'App folder path',
            value: _appFolderPath,
            hint: 'Installed app folder',
          ),
          if (_settings.locationMode == BackupLocationMode.custom) ...[
            const SizedBox(height: 12),
            _PathBlock(
              title: 'Custom folder',
              value: (_settings.customPath?.trim().isNotEmpty ?? false)
                  ? _settings.customPath!
                  : 'No custom folder selected yet.',
              hint: 'Choose a folder',
            ),
          ],
          const SizedBox(height: 12),
          _PathBlock(
            title: 'Active backups root',
            value: _resolvedBackupsPath,
            hint: 'Where the backup folders will be written',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: _chooseCustomFolder,
                icon: const Icon(Icons.folder_open_outlined, size: 16),
                label: const Text('Choose Folder'),
              ),
              OutlinedButton.icon(
                onPressed: _openBackupFolder,
                icon: const Icon(Icons.launch_outlined, size: 16),
                label: const Text('Open Folder'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _scheduleCard(BuildContext context) {
    final enabled = _settings.scheduledEnabled;
    return _SectionCard(
      title: '3. Scheduled Cadence',
      subtitle: 'Select which folders should be checked and created at login, then choose which tables each cadence should export.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FrequencyRow(
            frequency: BackupFrequency.daily,
            description: 'Stored in Backups/Daily when today has no snapshot yet.',
            enabled: enabled,
            selected: _settings.frequencies.contains(BackupFrequency.daily),
            onChanged: (value) => _toggleFrequency(BackupFrequency.daily, value),
          ),
          if (_settings.frequencies.contains(BackupFrequency.daily)) ...[
            const SizedBox(height: 10),
            _TableSelectorPanel(
              title: 'Daily tables',
              subtitle: 'Choose which tables should be exported into Backups/Daily.',
              tables: _service.scheduledSelectableTables,
              selected: _settings.tablesForFrequency(BackupFrequency.daily),
              enabled: enabled,
              labelForTable: _service.tableLabel,
              onToggle: (table, value) =>
                  _toggleTableForFrequency(BackupFrequency.daily, table, value),
            ),
          ],
          Divider(color: context.appBorder, height: 1),
          _FrequencyRow(
            frequency: BackupFrequency.weekly,
            description: 'Stored in Backups/Weekly when the current week has no snapshot yet.',
            enabled: enabled,
            selected: _settings.frequencies.contains(BackupFrequency.weekly),
            onChanged: (value) => _toggleFrequency(BackupFrequency.weekly, value),
          ),
          if (_settings.frequencies.contains(BackupFrequency.weekly)) ...[
            const SizedBox(height: 10),
            _TableSelectorPanel(
              title: 'Weekly tables',
              subtitle: 'Choose which tables should be exported into Backups/Weekly.',
              tables: _service.scheduledSelectableTables,
              selected: _settings.tablesForFrequency(BackupFrequency.weekly),
              enabled: enabled,
              labelForTable: _service.tableLabel,
              onToggle: (table, value) =>
                  _toggleTableForFrequency(BackupFrequency.weekly, table, value),
            ),
          ],
          Divider(color: context.appBorder, height: 1),
          _FrequencyRow(
            frequency: BackupFrequency.monthly,
            description: 'Stored in Backups/Monthly when the current month has no snapshot yet.',
            enabled: enabled,
            selected: _settings.frequencies.contains(BackupFrequency.monthly),
            onChanged: (value) => _toggleFrequency(BackupFrequency.monthly, value),
          ),
          if (_settings.frequencies.contains(BackupFrequency.monthly)) ...[
            const SizedBox(height: 10),
            _TableSelectorPanel(
              title: 'Monthly tables',
              subtitle: 'Choose which tables should be exported into Backups/Monthly.',
              tables: _service.scheduledSelectableTables,
              selected: _settings.tablesForFrequency(BackupFrequency.monthly),
              enabled: enabled,
              labelForTable: _service.tableLabel,
              onToggle: (table, value) =>
                  _toggleTableForFrequency(BackupFrequency.monthly, table, value),
            ),
          ],
          Divider(color: context.appBorder, height: 1),
          _FrequencyRow(
            frequency: BackupFrequency.yearly,
            description: 'Stored in Backups/Yearly when the current year has no snapshot yet.',
            enabled: enabled,
            selected: _settings.frequencies.contains(BackupFrequency.yearly),
            onChanged: (value) => _toggleFrequency(BackupFrequency.yearly, value),
          ),
          if (_settings.frequencies.contains(BackupFrequency.yearly)) ...[
            const SizedBox(height: 10),
            _TableSelectorPanel(
              title: 'Yearly tables',
              subtitle: 'Choose which tables should be exported into Backups/Yearly.',
              tables: _service.scheduledSelectableTables,
              selected: _settings.tablesForFrequency(BackupFrequency.yearly),
              enabled: enabled,
              labelForTable: _service.tableLabel,
              onToggle: (table, value) =>
                  _toggleTableForFrequency(BackupFrequency.yearly, table, value),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusCard(BuildContext context) {
    return _SectionCard(
      title: '4. Backup Status',
      subtitle: 'See the last known automatic exports for each cadence and the local mirror.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _StatusTile(title: 'Daily', value: _dt(_settings.lastDailyBackupAt)),
              _StatusTile(title: 'Weekly', value: _dt(_settings.lastWeeklyBackupAt)),
              _StatusTile(title: 'Monthly', value: _dt(_settings.lastMonthlyBackupAt)),
              _StatusTile(title: 'Yearly', value: _dt(_settings.lastYearlyBackupAt)),
              _StatusTile(title: 'Local mirror', value: _dt(_settings.lastOfflineSyncAt)),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.appSurface2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.appBorder),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _service.isBusy ? Icons.sync_rounded : Icons.info_outline_rounded,
                  color: BackupsPage.accent,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _service.statusMessage ?? 'No backup action has been triggered in this session yet.',
                    style: _uiStyle(
                      color: context.appTextSecondary,
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionsCard(BuildContext context) {
    return _SectionCard(
      title: '5. Run Now',
      subtitle: 'Manual controls for immediate export without waiting for the next login.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: _service.isBusy ||
                        !_settings.scheduledEnabled ||
                        _settings.frequencies.isEmpty
                    ? null
                    : _runScheduledNow,
                icon: const Icon(Icons.playlist_add_check_rounded, size: 16),
                label: const Text('Run Selected Backups'),
              ),
              FilledButton.tonalIcon(
                onPressed: _service.isBusy || !_settings.localMirrorEnabled
                    ? null
                    : _runOfflineNow,
                icon: const Icon(Icons.cloud_download_outlined, size: 16),
                label: const Text('Refresh Local Mirror'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Folder layout: $_resolvedRootPath',
            style: _monoStyle(
              color: context.appTextPrimary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Backups/Daily  |  Backups/Weekly  |  Backups/Monthly  |  Backups/Yearly  |  Backups/local_mirror',
            style: _monoStyle(
              color: context.appTextSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.appBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: _uiStyle(
              color: context.appTextPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: _uiStyle(
              color: context.appTextSecondary,
              fontSize: 12,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final Color accent;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.accent,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: _uiStyle(
                    color: context.appTextPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: _uiStyle(
                    color: context.appTextSecondary,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: accent,
          ),
        ],
      ),
    );
  }
}

class _LocationChoice extends StatelessWidget {
  final String label;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  const _LocationChoice({
    required this.label,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = selected ? BackupsPage.accent : context.appTextMuted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 180,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? BackupsPage.accent.withValues(alpha: 0.10)
              : context.appSurface2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? BackupsPage.accent : context.appBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: _uiStyle(
                color: context.appTextPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: _uiStyle(
                color: accent,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PathBlock extends StatelessWidget {
  final String title;
  final String value;
  final String hint;

  const _PathBlock({
    required this.title,
    required this.value,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appSurface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: _uiStyle(
              color: context.appTextMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          SelectableText(
            value,
            style: _monoStyle(
              color: context.appTextPrimary,
              fontSize: 11,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hint,
            style: _uiStyle(
              color: context.appTextSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _FrequencyRow extends StatelessWidget {
  final BackupFrequency frequency;
  final String description;
  final bool enabled;
  final bool selected;
  final ValueChanged<bool> onChanged;

  const _FrequencyRow({
    required this.frequency,
    required this.description,
    required this.enabled,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    frequency.label,
                    style: _uiStyle(
                      color: context.appTextPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: _uiStyle(
                      color: context.appTextSecondary,
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Checkbox(
              value: enabled ? selected : false,
              onChanged: enabled ? (value) => onChanged(value ?? false) : null,
              activeColor: BackupsPage.accent,
            ),
          ],
        ),
      ),
    );
  }
}

class _TableSelectorPanel extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<String> tables;
  final Set<String> selected;
  final bool enabled;
  final String Function(String table) labelForTable;
  final Future<void> Function(String table, bool enabled) onToggle;

  const _TableSelectorPanel({
    required this.title,
    required this.subtitle,
    required this.tables,
    required this.selected,
    required this.enabled,
    required this.labelForTable,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appSurface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appBorder),
      ),
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$title (${selected.length})',
              style: _uiStyle(
                color: context.appTextPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: _uiStyle(
                color: context.appTextSecondary,
                fontSize: 11,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final table in tables)
                  FilterChip(
                    label: Text(
                      labelForTable(table),
                      style: _uiStyle(
                        color: selected.contains(table)
                            ? BackupsPage.accent
                            : context.appTextPrimary,
                        fontSize: 11,
                        fontWeight: selected.contains(table)
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                    selected: selected.contains(table),
                    onSelected: enabled
                        ? (value) {
                            onToggle(table, value);
                          }
                        : null,
                    selectedColor: BackupsPage.accent.withValues(alpha: 0.12),
                    backgroundColor: context.appSurface,
                    side: BorderSide(
                      color: selected.contains(table)
                          ? BackupsPage.accent
                          : context.appBorder,
                    ),
                    checkmarkColor: BackupsPage.accent,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusTile extends StatelessWidget {
  final String title;
  final String value;

  const _StatusTile({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appSurface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: _uiStyle(
              color: context.appTextMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: _monoStyle(
              color: context.appTextPrimary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
