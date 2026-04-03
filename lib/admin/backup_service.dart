import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/supabase_manager.dart';

const _backupUnset = Object();
const _localMirrorTargetKey = 'local_mirror';

enum BackupLocationMode { documents, appFolder, custom }

enum BackupFrequency { daily, weekly, monthly, yearly }

const _backupAllTables = <String>[
  'app_meta',
  'audit_log',
  'equipment',
  'facility_sops',
  'fish_lines',
  'fish_stocks',
  'label_templates',
  'messages',
  'protocols',
  'reagents',
  'requested_strains',
  'requests',
  'reservations',
  'samples',
  'storage_locations',
  'strains',
  'todo_items',
  'users',
  'water_qc',
  'water_qc_maintenance',
  'water_qc_thresholds',
];

const _backupScheduledTables = <String>[
  'app_meta',
  'equipment',
  'facility_sops',
  'fish_lines',
  'fish_stocks',
  'label_templates',
  'messages',
  'protocols',
  'reagents',
  'requested_strains',
  'requests',
  'reservations',
  'samples',
  'storage_locations',
  'strains',
  'todo_items',
  'users',
  'water_qc',
  'water_qc_maintenance',
  'water_qc_thresholds',
];

extension BackupFrequencyX on BackupFrequency {
  String get label => switch (this) {
        BackupFrequency.daily => 'Daily',
        BackupFrequency.weekly => 'Weekly',
        BackupFrequency.monthly => 'Monthly',
        BackupFrequency.yearly => 'Yearly',
      };

  String get folderName => label;

  String get key => name;
}

Map<String, Set<String>> _defaultTablesByTarget() => {
      for (final frequency in BackupFrequency.values)
        frequency.name: Set<String>.from(_backupScheduledTables),
      _localMirrorTargetKey: Set<String>.from(_backupAllTables),
    };

Map<String, Set<String>> _normalizeTablesByTarget(Map<String, Set<String>> raw) {
  final normalized = _defaultTablesByTarget();

  for (final frequency in BackupFrequency.values) {
    final key = frequency.name;
    if (!raw.containsKey(key)) continue;
    normalized[key] = raw[key]!
        .where((table) => _backupScheduledTables.contains(table))
        .toSet();
  }

  if (raw.containsKey(_localMirrorTargetKey)) {
    normalized[_localMirrorTargetKey] = raw[_localMirrorTargetKey]!
        .where((table) => _backupAllTables.contains(table))
        .toSet();
  }

  return normalized;
}

class BackupSettings {
  final bool scheduledEnabled;
  final bool localMirrorEnabled;
  final Set<BackupFrequency> frequencies;
  final Map<String, Set<String>> tablesByTarget;
  final BackupLocationMode locationMode;
  final String? customPath;
  final DateTime? lastDailyBackupAt;
  final DateTime? lastWeeklyBackupAt;
  final DateTime? lastMonthlyBackupAt;
  final DateTime? lastYearlyBackupAt;
  final DateTime? lastOfflineSyncAt;

  const BackupSettings({
    this.scheduledEnabled = false,
    this.localMirrorEnabled = false,
    this.frequencies = const <BackupFrequency>{},
    this.tablesByTarget = const <String, Set<String>>{},
    this.locationMode = BackupLocationMode.documents,
    this.customPath,
    this.lastDailyBackupAt,
    this.lastWeeklyBackupAt,
    this.lastMonthlyBackupAt,
    this.lastYearlyBackupAt,
    this.lastOfflineSyncAt,
  });

  factory BackupSettings.fromJson(Map<String, dynamic> json) {
    final rawFrequencies = json['frequencies'];
    final frequencies = <BackupFrequency>{};
    if (rawFrequencies is List) {
      for (final raw in rawFrequencies) {
        final match = BackupFrequency.values.where((f) => f.name == raw).toList();
        if (match.isNotEmpty) frequencies.add(match.first);
      }
    }

    final rawMode = json['locationMode']?.toString();
    final mode = BackupLocationMode.values
        .where((m) => m.name == rawMode)
        .cast<BackupLocationMode?>()
        .firstWhere((m) => m != null, orElse: () => BackupLocationMode.documents)!;

    DateTime? parseDate(String key) {
      final value = json[key];
      if (value is! String || value.isEmpty) return null;
      return DateTime.tryParse(value);
    }

    final rawTablesByTarget = <String, Set<String>>{};
    final tablesJson = json['tablesByTarget'];
    if (tablesJson is Map) {
      for (final entry in tablesJson.entries) {
        final value = entry.value;
        if (value is List) {
          rawTablesByTarget[entry.key.toString()] =
              value.whereType<String>().toSet();
        }
      }
    }

    return BackupSettings(
      scheduledEnabled: json['scheduledEnabled'] as bool? ?? false,
      localMirrorEnabled: (json['localMirrorEnabled'] ?? json['offlineMirrorEnabled']) as bool? ?? false,
      frequencies: frequencies,
      tablesByTarget: _normalizeTablesByTarget(rawTablesByTarget),
      locationMode: mode,
      customPath: json['customPath'] as String?,
      lastDailyBackupAt: parseDate('lastDailyBackupAt'),
      lastWeeklyBackupAt: parseDate('lastWeeklyBackupAt'),
      lastMonthlyBackupAt: parseDate('lastMonthlyBackupAt'),
      lastYearlyBackupAt: parseDate('lastYearlyBackupAt'),
      lastOfflineSyncAt: parseDate('lastOfflineSyncAt'),
    );
  }

  Map<String, dynamic> toJson() => {
        'scheduledEnabled': scheduledEnabled,
        'localMirrorEnabled': localMirrorEnabled,
        'frequencies': frequencies.map((f) => f.name).toList()..sort(),
        'tablesByTarget': {
          for (final entry in _normalizeTablesByTarget(tablesByTarget).entries)
            entry.key: entry.value.toList()..sort(),
        },
        'locationMode': locationMode.name,
        'customPath': customPath,
        'lastDailyBackupAt': lastDailyBackupAt?.toIso8601String(),
        'lastWeeklyBackupAt': lastWeeklyBackupAt?.toIso8601String(),
        'lastMonthlyBackupAt': lastMonthlyBackupAt?.toIso8601String(),
        'lastYearlyBackupAt': lastYearlyBackupAt?.toIso8601String(),
        'lastOfflineSyncAt': lastOfflineSyncAt?.toIso8601String(),
      };

  BackupSettings copyWith({
    bool? scheduledEnabled,
    bool? localMirrorEnabled,
    Set<BackupFrequency>? frequencies,
    Object? tablesByTarget = _backupUnset,
    BackupLocationMode? locationMode,
    Object? customPath = _backupUnset,
    Object? lastDailyBackupAt = _backupUnset,
    Object? lastWeeklyBackupAt = _backupUnset,
    Object? lastMonthlyBackupAt = _backupUnset,
    Object? lastYearlyBackupAt = _backupUnset,
    Object? lastOfflineSyncAt = _backupUnset,
  }) {
    return BackupSettings(
      scheduledEnabled: scheduledEnabled ?? this.scheduledEnabled,
      localMirrorEnabled: localMirrorEnabled ?? this.localMirrorEnabled,
      frequencies: frequencies ?? this.frequencies,
      tablesByTarget: identical(tablesByTarget, _backupUnset)
          ? this.tablesByTarget
          : _normalizeTablesByTarget(
              Map<String, Set<String>>.from(tablesByTarget as Map<String, Set<String>>),
            ),
      locationMode: locationMode ?? this.locationMode,
      customPath: identical(customPath, _backupUnset) ? this.customPath : customPath as String?,
      lastDailyBackupAt: identical(lastDailyBackupAt, _backupUnset)
          ? this.lastDailyBackupAt
          : lastDailyBackupAt as DateTime?,
      lastWeeklyBackupAt: identical(lastWeeklyBackupAt, _backupUnset)
          ? this.lastWeeklyBackupAt
          : lastWeeklyBackupAt as DateTime?,
      lastMonthlyBackupAt: identical(lastMonthlyBackupAt, _backupUnset)
          ? this.lastMonthlyBackupAt
          : lastMonthlyBackupAt as DateTime?,
      lastYearlyBackupAt: identical(lastYearlyBackupAt, _backupUnset)
          ? this.lastYearlyBackupAt
          : lastYearlyBackupAt as DateTime?,
      lastOfflineSyncAt: identical(lastOfflineSyncAt, _backupUnset)
          ? this.lastOfflineSyncAt
          : lastOfflineSyncAt as DateTime?,
    );
  }

  Set<String> tablesForFrequency(BackupFrequency frequency) =>
      Set<String>.from(
        _normalizeTablesByTarget(tablesByTarget)[frequency.name] ?? const <String>{},
      );

  Set<String> get offlineTables => Set<String>.from(
        _normalizeTablesByTarget(tablesByTarget)[_localMirrorTargetKey] ??
            const <String>{},
      );
}

class BackupErrorEntry {
  final String message;
  final String detail;
  final String scope;
  final DateTime createdAt;

  const BackupErrorEntry({
    required this.message,
    required this.detail,
    required this.scope,
    required this.createdAt,
  });

  factory BackupErrorEntry.fromJson(Map<String, dynamic> json) {
    return BackupErrorEntry(
      message: json['message']?.toString() ?? 'Unknown backup error',
      detail: json['detail']?.toString() ?? '',
      scope: json['scope']?.toString() ?? 'backup',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'message': message,
        'detail': detail,
        'scope': scope,
        'createdAt': createdAt.toIso8601String(),
      };
}

class BackupService extends ChangeNotifier {
  BackupService._();

  static final BackupService instance = BackupService._();

  static const _prefsKey = 'backup_settings_v1';
  static const _errorsPrefsKey = 'backup_errors_v1';
  static const _pageSize = 1000;
  static const _tables = _backupAllTables;
  static const _tableLabels = <String, String>{
    'app_meta': 'App Meta',
    'audit_log': 'Audit Log',
    'equipment': 'Equipment',
    'facility_sops': 'Facility SOPs',
    'fish_lines': 'Fish Lines',
    'fish_stocks': 'Fish Stocks',
    'label_templates': 'Label Templates',
    'messages': 'Messages',
    'protocols': 'Protocols',
    'reagents': 'Reagents',
    'requested_strains': 'Requested Strains',
    'requests': 'Requests',
    'reservations': 'Reservations',
    'samples': 'Samples',
    'storage_locations': 'Storage Locations',
    'strains': 'Strains',
    'todo_items': 'To-Do Items',
    'users': 'Users',
    'water_qc': 'Water QC',
    'water_qc_maintenance': 'Water QC Maintenance',
    'water_qc_thresholds': 'Water QC Thresholds',
  };

  BackupSettings _settings = const BackupSettings();
  List<BackupErrorEntry> _errors = const [];
  bool _loaded = false;
  bool _busy = false;
  String? _statusMessage;
  RealtimeChannel? _offlineChannel;
  final Map<String, Timer> _offlineTableDebounces = {};
  bool _offlineQueued = false;

  // Priority tables get a shorter debounce; others are less time-sensitive.
  static const _priorityTables = <String>{
    'strains',
    'fish_stocks',
    'reagents',
    'equipment',
    'storage_locations',
  };
  static const _priorityDebounce = Duration(seconds: 3);
  static const _standardDebounce = Duration(seconds: 6);

  BackupSettings get settings => _settings;
  List<BackupErrorEntry> get errors => List<BackupErrorEntry>.unmodifiable(_errors);
  int get errorCount => _errors.length;
  bool get isLoaded => _loaded;
  bool get isBusy => _busy;
  String? get statusMessage => _statusMessage;
  List<String> get scheduledSelectableTables =>
      List<String>.unmodifiable(_backupScheduledTables);
  List<String> get offlineSelectableTables =>
      List<String>.unmodifiable(_backupAllTables);

  String tableLabel(String table) => _tableLabels[table] ?? table;

  Future<BackupSettings> loadSettings() async {
    if (_loaded) return _settings;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    final rawErrors = prefs.getString(_errorsPrefsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        _settings = BackupSettings.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map),
        );
      } catch (_) {
        _settings = const BackupSettings();
      }
    }
    if (rawErrors != null && rawErrors.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawErrors) as List<dynamic>;
        _errors = decoded
            .whereType<Map>()
            .map((e) => BackupErrorEntry.fromJson(Map<String, dynamic>.from(e)))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      } catch (_) {
        _errors = const [];
      }
    }
    _loaded = true;
    notifyListeners();
    return _settings;
  }

  Future<void> applySettings(BackupSettings settings) async {
    await loadSettings();
    final previous = _settings;
    try {
      _settings = BackupSettings.fromJson(settings.toJson());
      await _persistSettings();
      _statusMessage = 'Backup settings saved.';
      notifyListeners();
      await _configureOfflineMirrorSubscription();
      if (_settings.localMirrorEnabled && !previous.localMirrorEnabled) {
        unawaited(refreshLocalMirror(reason: 'enabled'));
      }
    } catch (e) {
      await addError(
        message: 'Could not save backup settings.',
        detail: e.toString(),
        scope: 'settings',
      );
      rethrow;
    }
  }

  Future<void> startForSession() async {
    await loadSettings();
    await _configureOfflineMirrorSubscription();
    if (_settings.scheduledEnabled && _settings.frequencies.isNotEmpty) {
      await runDueScheduledBackups(reason: 'login');
    }
    if (_settings.localMirrorEnabled) {
      await refreshLocalMirror(reason: 'login');
    }
  }

  Future<void> stop() async {
    for (final t in _offlineTableDebounces.values) {
      t.cancel();
    }
    _offlineTableDebounces.clear();
    final channel = _offlineChannel;
    _offlineChannel = null;
    if (channel != null) {
      await channel.unsubscribe();
    }
  }

  Future<String> recommendedRootPath() async {
    final home = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
    if (home != null && home.isNotEmpty) {
      return _joinPath(home, 'Documents', 'LIMSSphere');
    }
    final docs = await getApplicationDocumentsDirectory();
    return _joinPath(docs.path, 'LIMSSphere');
  }

  Future<String> appFolderPath() async {
    try {
      return File(Platform.resolvedExecutable).parent.path;
    } catch (_) {
      return Directory.current.path;
    }
  }

  Future<String> resolveRootPath([BackupSettings? settings]) async {
    final current = settings ?? await loadSettings();
    switch (current.locationMode) {
      case BackupLocationMode.documents:
        return recommendedRootPath();
      case BackupLocationMode.appFolder:
        return appFolderPath();
      case BackupLocationMode.custom:
        final custom = current.customPath?.trim();
        if (custom != null && custom.isNotEmpty) return custom;
        return recommendedRootPath();
    }
  }

  Future<String> resolveBackupsRootPath([BackupSettings? settings]) async {
    final root = await resolveRootPath(settings);
    return _joinPath(root, 'Backups');
  }

  Future<String> runSelectedBackupsNow() async {
    await loadSettings();
    if (!_settings.scheduledEnabled || _settings.frequencies.isEmpty) {
      const message = 'Scheduled backups are disabled or no cadence is selected.';
      _statusMessage = message;
      notifyListeners();
      return message;
    }
    return _runScheduledBackups(force: true, reason: 'manual');
  }

  Future<String> runDueScheduledBackups({String reason = 'login'}) async {
    await loadSettings();
    if (!_settings.scheduledEnabled || _settings.frequencies.isEmpty) {
      return 'Scheduled backups are disabled.';
    }
    return _runScheduledBackups(force: false, reason: reason);
  }

  Future<String> refreshLocalMirror({String reason = 'manual'}) async {
    await loadSettings();
    if (!_settings.localMirrorEnabled) {
      const message = 'Local mirror is disabled.';
      _statusMessage = message;
      notifyListeners();
      return message;
    }
    if (_busy) {
      _offlineQueued = true;
      const message = 'Local mirror refresh queued.';
      _statusMessage = message;
      notifyListeners();
      return message;
    }
    final result = await _runBusy<String>('Refreshing local mirror...', () async {
      final selectedTables = _settings.offlineTables.toList()..sort();
      if (selectedTables.isEmpty) {
        const message = 'Local mirror has no tables selected.';
        _statusMessage = message;
        return message;
      }
      final root = await resolveBackupsRootPath();
      final dir = Directory(_joinPath(root, 'local_mirror'));
      final summary = await _exportIntoDirectory(
        dir,
        type: 'local_mirror',
        reason: reason,
        tables: selectedTables,
      );
      await _addExportErrors(
        summary.errors,
        scope: 'local_mirror',
        message: 'Local mirror completed with table errors.',
      );
      final now = DateTime.now();
      _settings = _settings.copyWith(lastOfflineSyncAt: now);
      await _persistSettings();
      final message = summary.errors.isEmpty
          ? 'Local mirror updated in ${dir.path}.'
          : 'Local mirror updated with ${summary.errors.length} table warning(s).';
      _statusMessage = message;
      return message;
    });
    await _runQueuedOfflineIfNeeded();
    notifyListeners();
    return result;
  }

  Future<String> _runScheduledBackups({
    required bool force,
    required String reason,
  }) async {
    final now = DateTime.now();
    final due = <BackupFrequency>[
      for (final frequency in BackupFrequency.values)
        if (_settings.frequencies.contains(frequency) && (force || _isDue(frequency, now))) frequency,
    ];
    if (due.isEmpty) {
      const message = 'No scheduled backups were due.';
      _statusMessage = message;
      notifyListeners();
      return message;
    }

    final result = await _runBusy<String>('Creating scheduled backups...', () async {
      final backupsRoot = await resolveBackupsRootPath();
      final allErrors = <String>[];
      for (final frequency in due) {
        final selectedTables = _settings.tablesForFrequency(frequency).toList()
          ..sort();
        if (selectedTables.isEmpty) {
          allErrors.add('${frequency.label}: no tables selected');
          continue;
        }
        final folder = Directory(
          _joinPath(backupsRoot, frequency.folderName, _timestampFolderName(now)),
        );
        final summary = await _exportIntoDirectory(
          folder,
          type: frequency.key,
          reason: reason,
          tables: selectedTables,
        );
        allErrors.addAll(summary.errors);
        if (summary.tablesWritten > 0) {
          _settings = _markFrequencyAsCompleted(_settings, frequency, now);
        }
      }
      await _addExportErrors(
        allErrors,
        scope: 'scheduled',
        message: 'Scheduled backup completed with errors.',
      );
      await _persistSettings();
      final label = due.map((f) => f.label).join(', ');
      final message = allErrors.isEmpty
          ? 'Created ${due.length} backup snapshot(s): $label.'
          : 'Created ${due.length} snapshot(s) with ${allErrors.length} table warning(s).';
      _statusMessage = message;
      return message;
    });

    notifyListeners();
    return result;
  }

  Future<void> _persistSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(_settings.toJson()));
  }

  Future<void> _persistErrors() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _errorsPrefsKey,
      jsonEncode(_errors.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> addError({
    required String message,
    String detail = '',
    String scope = 'backup',
  }) async {
    await loadSettings();
    _errors = [
      BackupErrorEntry(
        message: message,
        detail: detail,
        scope: scope,
        createdAt: DateTime.now(),
      ),
      ..._errors,
    ];
    await _persistErrors();
    notifyListeners();
  }

  Future<void> clearErrors() async {
    await loadSettings();
    _errors = const [];
    await _persistErrors();
    notifyListeners();
  }

  Future<void> _addExportErrors(
    List<String> errors, {
    required String scope,
    required String message,
  }) async {
    if (errors.isEmpty) return;
    await addError(
      message: message,
      detail: errors.join('\n'),
      scope: scope,
    );
  }

  Future<void> _configureOfflineMirrorSubscription() async {
    final current = _offlineChannel;
    if (!_settings.localMirrorEnabled) {
      _offlineChannel = null;
      if (current != null) {
        await current.unsubscribe();
      }
      notifyListeners();
      return;
    }
    if (current != null) return;

    final channelName = 'backup_offline_${SupabaseManager.projectRef ?? 'default'}';
    var channel = Supabase.instance.client.channel(channelName);
    for (final table in _tables) {
      channel = channel
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: table,
            callback: (_) => _scheduleTableRefresh(table),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: table,
            callback: (_) => _scheduleTableRefresh(table),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.delete,
            schema: 'public',
            table: table,
            callback: (_) => _scheduleTableRefresh(table),
          );
    }
    _offlineChannel = channel.subscribe();
    _statusMessage ??= 'Local mirror listener is active.';
    notifyListeners();
  }

  void _scheduleTableRefresh(String table) {
    if (!_settings.localMirrorEnabled) return;
    _offlineTableDebounces[table]?.cancel();
    final delay = _priorityTables.contains(table) ? _priorityDebounce : _standardDebounce;
    _offlineTableDebounces[table] = Timer(
      delay,
      () => unawaited(_refreshSingleTable(table)),
    );
  }

  Future<void> _refreshSingleTable(String table) async {
    if (!_settings.localMirrorEnabled) return;
    if (!_settings.offlineTables.contains(table)) return;
    if (_busy) {
      _offlineQueued = true;
      return;
    }
    try {
      final root = await resolveBackupsRootPath();
      final dir = Directory(_joinPath(root, 'local_mirror'));
      if (!await dir.exists()) {
        unawaited(refreshLocalMirror(reason: 'init:$table'));
        return;
      }
      final rows = await _fetchTableRows(table);
      await _writeCsvFile(_joinPath(dir.path, '$table.csv'), _rowsToCsv(rows));
      _statusMessage = 'Local mirror: $table updated (${rows.length} rows).';
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _runQueuedOfflineIfNeeded() async {
    if (!_offlineQueued || !_settings.localMirrorEnabled) return;
    _offlineQueued = false;
    await refreshLocalMirror(reason: 'queued');
  }

  bool _isDue(BackupFrequency frequency, DateTime now) {
    final last = switch (frequency) {
      BackupFrequency.daily => _settings.lastDailyBackupAt,
      BackupFrequency.weekly => _settings.lastWeeklyBackupAt,
      BackupFrequency.monthly => _settings.lastMonthlyBackupAt,
      BackupFrequency.yearly => _settings.lastYearlyBackupAt,
    };
    if (last == null) return true;
    switch (frequency) {
      case BackupFrequency.daily:
        return !_sameDay(last, now);
      case BackupFrequency.weekly:
        return _startOfWeek(last) != _startOfWeek(now);
      case BackupFrequency.monthly:
        return last.year != now.year || last.month != now.month;
      case BackupFrequency.yearly:
        return last.year != now.year;
    }
  }

  BackupSettings _markFrequencyAsCompleted(
    BackupSettings settings,
    BackupFrequency frequency,
    DateTime now,
  ) {
    switch (frequency) {
      case BackupFrequency.daily:
        return settings.copyWith(lastDailyBackupAt: now);
      case BackupFrequency.weekly:
        return settings.copyWith(lastWeeklyBackupAt: now);
      case BackupFrequency.monthly:
        return settings.copyWith(lastMonthlyBackupAt: now);
      case BackupFrequency.yearly:
        return settings.copyWith(lastYearlyBackupAt: now);
    }
  }

  Future<T> _runBusy<T>(String status, Future<T> Function() action) async {
    if (_busy) {
      throw StateError('A backup operation is already running.');
    }
    _busy = true;
    _statusMessage = status;
    notifyListeners();
    try {
      return await action();
    } catch (e) {
      await addError(
        message: 'Backup operation failed.',
        detail: e.toString(),
        scope: 'operation',
      );
      rethrow;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<_BackupExportSummary> _exportIntoDirectory(
    Directory dir, {
    required String type,
    required String reason,
    required List<String> tables,
  }) async {
    await dir.create(recursive: true);
    final counts = <String, int>{};
    final errors = <String>[];
    var totalRows = 0;

    for (final table in tables) {
      try {
        final rows = await _fetchTableRows(table);
        counts[table] = rows.length;
        totalRows += rows.length;
        await _writeCsvFile(
          _joinPath(dir.path, '$table.csv'),
          _rowsToCsv(rows),
        );
      } on PostgrestException catch (e) {
        errors.add('$table: ${e.message}');
      } catch (e) {
        errors.add('$table: $e');
      }
    }

    final manifestRows = <Map<String, dynamic>>[
      {
        'section': 'meta',
        'key': 'generated_at',
        'value': DateTime.now().toIso8601String(),
      },
      {
        'section': 'meta',
        'key': 'type',
        'value': type,
      },
      {
        'section': 'meta',
        'key': 'reason',
        'value': reason,
      },
      {
        'section': 'meta',
        'key': 'connection_name',
        'value': SupabaseManager.currentName ?? '',
      },
      {
        'section': 'meta',
        'key': 'project_ref',
        'value': SupabaseManager.projectRef ?? '',
      },
      for (final table in tables)
        {
          'section': 'table_selected',
          'key': table,
          'value': tableLabel(table),
        },
      {
        'section': 'meta',
        'key': 'total_rows',
        'value': totalRows,
      },
      for (final entry in counts.entries)
        {
          'section': 'table_count',
          'key': entry.key,
          'value': entry.value,
        },
      for (final error in errors)
        {
          'section': 'error',
          'key': 'message',
          'value': error,
        },
    ];
    await _writeCsvFile(
      _joinPath(dir.path, '_manifest.csv'),
      _rowsToCsv(manifestRows),
    );

    return _BackupExportSummary(
      tablesWritten: counts.length,
      totalRows: totalRows,
      errors: errors,
    );
  }

  Future<List<Map<String, dynamic>>> _fetchTableRows(String table) async {
    final rows = <Map<String, dynamic>>[];
    var offset = 0;
    while (true) {
      final response = await Supabase.instance.client
          .from(table)
          .select()
          .range(offset, offset + _pageSize - 1);
      final page = List<Map<String, dynamic>>.from(
        (response as List<dynamic>).map((e) => Map<String, dynamic>.from(e as Map)),
      );
      rows.addAll(page);
      if (page.length < _pageSize) break;
      offset += _pageSize;
    }
    return rows;
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static DateTime _startOfWeek(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return d.subtract(Duration(days: d.weekday - 1));
  }

  static String _timestampFolderName(DateTime dt) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)}_${two(dt.hour)}-${two(dt.minute)}-${two(dt.second)}';
  }

  static String _joinPath(String first, [String? second, String? third, String? fourth]) {
    final parts = <String>[
      first,
      if (second != null && second.isNotEmpty) second,
      if (third != null && third.isNotEmpty) third,
      if (fourth != null && fourth.isNotEmpty) fourth,
    ];
    return parts
        .map((part) => part.replaceAll(RegExp(r'[\\/]+$'), ''))
        .where((part) => part.isNotEmpty)
        .join(Platform.pathSeparator);
  }

  Future<void> _writeCsvFile(String path, String csv) async {
    final bytes = <int>[0xEF, 0xBB, 0xBF, ...utf8.encode(csv)];
    await File(path).writeAsBytes(bytes, flush: true);
  }

  String _rowsToCsv(List<Map<String, dynamic>> rows) {
    final headers = <String>[];
    final seen = <String>{};
    for (final row in rows) {
      for (final key in row.keys) {
        if (seen.add(key)) headers.add(key);
      }
    }

    if (headers.isEmpty) {
      return '';
    }

    final buffer = StringBuffer()
      ..writeln(headers.map(_csvCell).join(','));
    for (final row in rows) {
      buffer.writeln(
        headers.map((header) => _csvCell(_csvValue(row[header]))).join(','),
      );
    }
    return buffer.toString();
  }

  String _csvValue(dynamic value) {
    if (value == null) return '';
    if (value is Map || value is List) return jsonEncode(value);
    return value.toString();
  }

  String _csvCell(String value) {
    final escaped = value.replaceAll('"', '""');
    final needsQuotes = escaped.contains(',') ||
        escaped.contains('"') ||
        escaped.contains('\n') ||
        escaped.contains('\r');
    return needsQuotes ? '"$escaped"' : escaped;
  }
}

class _BackupExportSummary {
  final int tablesWritten;
  final int totalRows;
  final List<String> errors;

  const _BackupExportSummary({
    required this.tablesWritten,
    required this.totalRows,
    required this.errors,
  });
}
