// water_qc_page.dart - Water Quality Control log.
// Inline editing: click cell → edit; Tab/Enter → next cell; Shift+Tab → previous; Escape → cancel.
// Maintenance cols (pH Cal, Cond Cal, Temp Check, RO Sediment, RO Carbon): double-click → DatePicker.
// Maintenance overview: double-click Last Done → DatePicker; click Optimal → edit dialog.
// "+" row at top of list inserts the next date (most recent + 1 day) automatically.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/theme/theme.dart';
import '/theme/module_permission.dart';
import '/theme/grid_widgets.dart';
import '../shared_widgets.dart';

class WaterQcPage extends StatefulWidget {
  const WaterQcPage({super.key});

  @override
  State<WaterQcPage> createState() => _WaterQcPageState();
}

class _WaterQcPageState extends State<WaterQcPage> {
  List<Map<String, dynamic>> _rows = [];
  // key → {lastDone: DateTime?, optimalDays: int}
  final Map<String, Map<String, dynamic>> _maint = {};
  bool _loading = true;
  String? _error;

  final _searchCtrl  = TextEditingController();
  String _filterMode  = 'all'; // 'all' | 'out_of_range' | 'has_incidents'
  bool   _showFilters = false;

  // {id: rowId, col: colKey}
  Map<String, dynamic>? _editingCell;
  final _editCtrl  = TextEditingController();
  final _editFocus = FocusNode();

  final _vertCtrl  = ScrollController();
  final _horizCtrl = ScrollController();
  final _hOffset   = ValueNotifier<double>(0);
  final _vOffset   = ValueNotifier<double>(0);

  static const _pageAccent = Color(0xFF22D3EE);

  // (key, label, width, type: 'date'|'num'|'maint'|'incident'|'text')
  static const _cols = [
    ('record_date',              'Date',              100.0, 'date'),
    ('ph',                       'pH',                 60.0, 'num'),
    ('conductivity',             'Conductivity',       95.0, 'num'),
    ('temperature',              'Temp (°C)',           80.0, 'num'),
    ('nitrates',                 'NO₃⁻ (mg/L)',        85.0, 'num'),
    ('nitrites',                 'NO₂⁻ (mg/L)',        85.0, 'num'),
    ('hardness_dkh',             'Hardness (dKH)',      90.0, 'num'),
    ('ph_calibration',           'pH Cal.',             85.0, 'maint'),
    ('conductivity_calibration', 'Cond. Cal.',          85.0, 'maint'),
    ('temperature_check',        'Temp Check',          85.0, 'maint'),
    ('ro_filter_sediment',       'RO Sediment',         95.0, 'maint'),
    ('ro_filter_carbon',         'RO Carbon',           85.0, 'maint'),
    ('incidents',                'Incidents',          130.0, 'incident'),
    ('observations',             'Observations',       160.0, 'text'),
  ];

  // Tab navigation skips 'date' and 'maint' columns
  static const _tabCols = [
    'ph', 'conductivity', 'temperature', 'nitrates', 'nitrites', 'hardness_dkh',
    'incidents', 'observations',
  ];

  static const _maintKeys = [
    'ph_calibration', 'conductivity_calibration', 'temperature_check',
    'ro_filter_sediment', 'ro_filter_carbon',
  ];

  static const _maintLabels = <String, String>{
    'ph_calibration':            'pH Calibration',
    'conductivity_calibration':  'Conductivity Calibration',
    'temperature_check':         'Temperature Check',
    'ro_filter_sediment':        'RO pre-filter (Sediments 5µm)',
    'ro_filter_carbon':          'RO pre-filter (Active carbon)',
  };

  // key → {minValue: double?, maxValue: double?}
  final Map<String, Map<String, dynamic>> _thresholds = {};

  // (key, label, unit, hasMin)
  static const _thresholdDefs = [
    ('ph',           'pH',           '',        true),
    ('conductivity', 'Conductivity', 'µS/cm',   true),
    ('temperature',  'Temperature',  '°C',      true),
    ('nitrates',     'NO₃⁻',        'mg/L',    false),
    ('nitrites',     'NO₂⁻',        'mg/L',    false),
  ];

  // These columns display as integers (no decimals)
  static const _intCols = {'conductivity', 'nitrates', 'nitrites'};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _editCtrl.dispose();
    _editFocus.dispose();
    _vertCtrl.dispose();
    _horizCtrl.dispose();
    _hOffset.dispose();
    _vOffset.dispose();
    super.dispose();
  }

  static const _numericCols = [
    'ph', 'conductivity', 'temperature', 'nitrates', 'nitrites', 'hardness_dkh',
  ];

  List<Map<String, dynamic>> get _filteredRows {
    var d = _rows.toList();
    final q = _searchCtrl.text.toLowerCase();
    if (q.isNotEmpty) {
      d = d.where((r) =>
        (r['record_date']?.toString() ?? '').contains(q) ||
        (r['observations']?.toString().toLowerCase() ?? '').contains(q) ||
        (r['incidents']?.toString().toLowerCase() ?? '').contains(q) ||
        _numericCols.any((k) => (r[k]?.toString() ?? '').contains(q))
      ).toList();
    }
    if (_filterMode == 'out_of_range') {
      d = d.where((r) => _numericCols.any((k) => _isOutOfRange(k, r[k]))).toList();
    } else if (_filterMode == 'has_incidents') {
      d = d.where((r) => (r['incidents']?.toString().trim() ?? '').isNotEmpty).toList();
    }
    return d;
  }

  bool get _hasActiveFilter => _filterMode != 'all';

  // ── Loading ────────────────────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        Supabase.instance.client
            .from('water_qc')
            .select()
            .order('record_date', ascending: false)
            .order('id', ascending: false),
        Supabase.instance.client.from('water_qc_maintenance').select(),
        Supabase.instance.client.from('water_qc_thresholds').select(),
      ]);
      if (!mounted) return;
      final rows       = List<Map<String, dynamic>>.from(results[0] as List);
      final maint      = List<Map<String, dynamic>>.from(results[1] as List);
      final thresholds = List<Map<String, dynamic>>.from(results[2] as List);
      setState(() {
        _rows = rows;
        for (final m in maint) {
          final key = m['key'] as String;
          final ld  = m['last_done_date'];
          _maint[key] = {
            'lastDone':    ld != null ? DateTime.tryParse(ld.toString()) : null,
            'optimalDays': (m['optimal_days'] as num?)?.toInt() ?? 30,
          };
        }
        for (final t in thresholds) {
          final key = t['key'] as String;
          _thresholds[key] = {
            'minValue': t['min_value'] != null
                ? (t['min_value'] as num).toDouble() : null,
            'maxValue': t['max_value'] != null
                ? (t['max_value'] as num).toDouble() : null,
            'setVal': t['set_value'] != null
                ? (t['set_value'] as num).toDouble() : null,
          };
        }
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  // ── Add row for a picked date ──────────────────────────────────────────────

  Future<void> _addRowForDate() async {
    if (!context.canEditModule) { context.warnReadOnly(); return; }
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;
    final ds    = fmtDate(picked);
    final email = Supabase.instance.client.auth.currentSession?.user.email;
    try {
      final inserted = await Supabase.instance.client
          .from('water_qc')
          .insert({'record_date': ds, 'created_by': email})
          .select()
          .single();
      if (!mounted) return;
      setState(() => _rows.insert(0, Map<String, dynamic>.from(inserted)));
      _startEdit(_rows[0]['id'].toString(), 'ph');
    } catch (e) {
      if (!mounted) return;
      _snack('Failed to add row: $e', error: true);
    }
  }

  // ── Add next row ───────────────────────────────────────────────────────────

  Future<void> _addNextRow() async {
    if (!context.canEditModule) { context.warnReadOnly(); return; }
    DateTime nextDate;
    if (_rows.isEmpty) {
      nextDate = DateTime.now();
    } else {
      final latestStr = _rows[0]['record_date']?.toString();
      final latest    = latestStr != null ? DateTime.tryParse(latestStr) : null;
      nextDate = (latest ?? DateTime.now()).add(const Duration(days: 1));
    }
    final ds    = fmtDate(nextDate);
    final email = Supabase.instance.client.auth.currentSession?.user.email;
    try {
      final inserted = await Supabase.instance.client
          .from('water_qc')
          .insert({'record_date': ds, 'created_by': email})
          .select()
          .single();
      if (!mounted) return;
      setState(() => _rows.insert(0, Map<String, dynamic>.from(inserted)));
      _startEdit(_rows[0]['id'].toString(), 'ph');
    } catch (e) {
      if (!mounted) return;
      _snack('Failed to add row: $e', error: true);
    }
  }

  // ── Inline editing ─────────────────────────────────────────────────────────

  void _startEdit(String rowId, String col) {
    final row = _rows.firstWhere(
        (r) => r['id'].toString() == rowId, orElse: () => {});
    if (row.isEmpty) return;
    _editFocus.unfocus();
    _editCtrl.text = row[col]?.toString() ?? '';
    _editCtrl.selection =
        TextSelection(baseOffset: 0, extentOffset: _editCtrl.text.length);
    setState(() => _editingCell = {'id': rowId, 'col': col});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _editFocus.requestFocus();
    });
  }

  // Commits the active cell to local state immediately and fires the network
  // save in the background — so Tab/Enter can move focus without waiting.
  void _commitCurrentEdit() {
    final cell = _editingCell;
    if (cell == null) return;
    final rowId = cell['id'] as String;
    final col   = cell['col'] as String;
    final raw   = _editCtrl.text.trim();

    final colDef = _cols.firstWhere((c) => c.$1 == col,
        orElse: () => ('', '', 0.0, 'text'));
    dynamic value;
    if (colDef.$4 == 'num') {
      value = raw.isEmpty ? null : double.tryParse(raw.replaceAll(',', '.'));
    } else {
      value = raw.isEmpty ? null : raw;
    }

    // Optimistic local update — no setState here, _startEdit will rebuild
    final ri = _rows.indexWhere((r) => r['id'].toString() == rowId);
    if (ri >= 0) _rows[ri] = {..._rows[ri], col: value};

    // Fire-and-forget network save
    Supabase.instance.client
        .from('water_qc')
        .update({col: value})
        .eq('id', int.parse(rowId))
        .then((_) {})
        .catchError((_) { if (mounted) _load(); });
  }

  void _cancelEdit() {
    setState(() => _editingCell = null);
    _editFocus.unfocus();
  }

  void _advanceCell({bool forward = true}) {
    final cell = _editingCell;
    if (cell == null) { setState(() => _editingCell = null); return; }

    final rowId = cell['id'] as String;
    final col   = cell['col'] as String;
    final ci    = _tabCols.indexOf(col);

    _commitCurrentEdit(); // instant local commit, network fires in background

    if (forward) {
      if (ci >= 0 && ci < _tabCols.length - 1) {
        _startEdit(rowId, _tabCols[ci + 1]);
      } else {
        // Move to first col of next row
        final ri = _rows.indexWhere((r) => r['id'].toString() == rowId);
        if (ri >= 0 && ri < _rows.length - 1) {
          _startEdit(_rows[ri + 1]['id'].toString(), _tabCols[0]);
        } else {
          setState(() => _editingCell = null);
        }
      }
    } else {
      if (ci > 0) {
        _startEdit(rowId, _tabCols[ci - 1]);
      } else {
        final ri = _rows.indexWhere((r) => r['id'].toString() == rowId);
        if (ri > 0) {
          _startEdit(_rows[ri - 1]['id'].toString(), _tabCols.last);
        } else {
          setState(() => _editingCell = null);
        }
      }
    }
  }

  // ── Maintenance cell (date picker) in main table ───────────────────────────

  Future<void> _pickMaintDate(Map<String, dynamic> row, String col) async {
    if (!context.canEditModule) { context.warnReadOnly(); return; }
    final val     = row[col]?.toString().trim();
    final current = (val != null && val.isNotEmpty) ? DateTime.tryParse(val) : null;
    final picked  = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;
    final ds = fmtDate(picked);
    final ri = _rows.indexWhere((r) => r['id'] == row['id']);
    if (ri >= 0) setState(() => _rows[ri] = {..._rows[ri], col: ds});
    try {
      await Supabase.instance.client
          .from('water_qc')
          .update({col: ds})
          .eq('id', row['id'] as int);
    } catch (_) {
      if (mounted) _load();
    }
  }

  // ── Maintenance overview — edit last done ──────────────────────────────────

  Future<void> _editMaintLastDone(String key) async {
    if (!context.canEditModule) { context.warnReadOnly(); return; }
    final current = _maint[key]?['lastDone'] as DateTime?;
    final picked  = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked == null || !mounted) return;
    setState(() => _maint[key] = {
      ...?_maint[key],
      'lastDone': picked,
    });
    try {
      await Supabase.instance.client
          .from('water_qc_maintenance')
          .upsert({'key': key, 'last_done_date': fmtDate(picked),
              'optimal_days': _maint[key]?['optimalDays'] ?? 30});
    } catch (_) {}
  }

  // ── Maintenance overview — edit optimal days ───────────────────────────────

  Future<void> _editMaintOptimal(String key) async {
    if (!context.canEditModule) { context.warnReadOnly(); return; }
    final current = (_maint[key]?['optimalDays'] as int?) ?? 30;
    final ctrl    = TextEditingController(text: '$current');
    final result  = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.appSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: Text('Optimal interval (days)',
            style: GoogleFonts.spaceGrotesk(
                color: context.appTextPrimary, fontWeight: FontWeight.w600)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          style: GoogleFonts.jetBrainsMono(color: context.appTextPrimary),
          decoration: InputDecoration(
            isDense: true,
            suffixText: 'days',
            suffixStyle: GoogleFonts.spaceGrotesk(
                color: context.appTextMuted, fontSize: 12),
            filled: true,
            fillColor: context.appSurface2,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: context.appBorder),
            ),
          ),
          onSubmitted: (v) {
            final n = int.tryParse(v.trim());
            if (n != null && n > 0) Navigator.pop(ctx, n);
          },
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: GoogleFonts.spaceGrotesk(color: context.appTextMuted))),
          TextButton(
              onPressed: () {
                final n = int.tryParse(ctrl.text.trim());
                if (n != null && n > 0) Navigator.pop(ctx, n);
              },
              child: Text('Save',
                  style: GoogleFonts.spaceGrotesk(color: _pageAccent))),
        ],
      ),
    );
    ctrl.dispose();
    if (result == null || !mounted) return;
    setState(() => _maint[key] = {...?_maint[key], 'optimalDays': result});
    try {
      await Supabase.instance.client
          .from('water_qc_maintenance')
          .upsert({'key': key, 'optimal_days': result,
              'last_done_date': _maint[key]?['lastDone'] != null
                  ? fmtDate(_maint[key]!['lastDone'] as DateTime)
                  : null});
    } catch (_) {}
  }

  // ── Thresholds — edit dialog ───────────────────────────────────────────────

  Future<void> _editThreshold(String key, String label, bool hasMin) async {
    if (!context.canEditModule) { context.warnReadOnly(); return; }
    final t    = _thresholds[key];
    final minC = TextEditingController(
        text: t?['minValue']?.toString() ?? '');
    final setC = TextEditingController(
        text: t?['setVal']?.toString() ?? '');
    final maxC = TextEditingController(
        text: t?['maxValue']?.toString() ?? '');

    InputDecoration fieldDeco(String hint) => InputDecoration(
      isDense: true,
      hintText: hint,
      hintStyle: GoogleFonts.spaceGrotesk(
          color: context.appTextMuted, fontSize: 12),
      filled: true,
      fillColor: context.appSurface2,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: context.appBorder),
      ),
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.appSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: Text('$label limits',
            style: GoogleFonts.spaceGrotesk(
                color: context.appTextPrimary, fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasMin) ...[
              TextField(
                controller: minC,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: GoogleFonts.jetBrainsMono(
                    color: context.appTextPrimary, fontSize: 13),
                decoration: fieldDeco('Min value (leave empty = no limit)'),
              ),
              const SizedBox(height: 10),
            ],
            TextField(
              controller: setC,
              autofocus: !hasMin,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: GoogleFonts.jetBrainsMono(
                  color: context.appTextPrimary, fontSize: 13),
              decoration: fieldDeco('Set value (target / optimal)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: maxC,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: GoogleFonts.jetBrainsMono(
                  color: context.appTextPrimary, fontSize: 13),
              decoration: fieldDeco('Max value (leave empty = no limit)'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style: GoogleFonts.spaceGrotesk(color: context.appTextMuted))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Save',
                  style: GoogleFonts.spaceGrotesk(color: _pageAccent))),
        ],
      ),
    );
    final minRaw = minC.text.trim().replaceAll(',', '.');
    final setRaw = setC.text.trim().replaceAll(',', '.');
    final maxRaw = maxC.text.trim().replaceAll(',', '.');
    minC.dispose(); setC.dispose(); maxC.dispose();
    if (saved != true || !mounted) return;

    final minVal = minRaw.isEmpty ? null : double.tryParse(minRaw);
    final setVal = setRaw.isEmpty ? null : double.tryParse(setRaw);
    final maxVal = maxRaw.isEmpty ? null : double.tryParse(maxRaw);

    setState(() => _thresholds[key] = {
      'minValue': minVal, 'setVal': setVal, 'maxValue': maxVal,
    });
    try {
      await Supabase.instance.client
          .from('water_qc_thresholds')
          .upsert({'key': key, 'min_value': minVal, 'set_value': setVal,
              'max_value': maxVal});
    } catch (_) {}
  }

  // Returns true if the numeric value is outside the configured threshold range.
  bool _isOutOfRange(String key, dynamic val) {
    if (val == null) return false;
    final v = double.tryParse(val.toString());
    if (v == null) return false;
    final t = _thresholds[key];
    if (t == null) return false;
    final min = t['minValue'] as double?;
    final max = t['maxValue'] as double?;
    if (min != null && v < min) return true;
    if (max != null && v > max) return true;
    return false;
  }

  // ── Delete row ─────────────────────────────────────────────────────────────

  Future<void> _deleteRow(Map<String, dynamic> row) async {
    if (!context.canEditModule) { context.warnReadOnly(); return; }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.appSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: Text('Delete row?',
            style: GoogleFonts.spaceGrotesk(
                color: context.appTextPrimary, fontWeight: FontWeight.w600)),
        content: Text(
            'Record for ${row['record_date'] ?? 'this row'} will be permanently removed.',
            style: GoogleFonts.spaceGrotesk(
                color: context.appTextSecondary, fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style: GoogleFonts.spaceGrotesk(color: context.appTextMuted))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Delete',
                  style: GoogleFonts.spaceGrotesk(color: AppDS.red))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final id = row['id'] as int;
    setState(() => _rows.removeWhere((r) => r['id'] == id));
    try {
      await Supabase.instance.client.from('water_qc').delete().eq('id', id);
    } catch (_) {
      if (mounted) _load();
    }
  }

  // ── CSV export ─────────────────────────────────────────────────────────────

  Future<void> _exportCsv() async {
    final buf = StringBuffer();
    buf.writeln('Date,pH,Conductivity,Temperature (°C),NO3- (mg/L),NO2- (mg/L),'
        'Hardness (dKH),pH Cal.,Cond. Cal.,Temp Check,RO Sediment,RO Carbon,'
        'Incidents,Observations');
    String esc(dynamic v) => '"${(v?.toString() ?? '').replaceAll('"', '""')}"';
    for (final r in _filteredRows) {
      buf.writeln([
        r['record_date'] ?? '', r['ph'] ?? '', r['conductivity'] ?? '',
        r['temperature'] ?? '', r['nitrates'] ?? '', r['nitrites'] ?? '',
        r['hardness_dkh'] ?? '', esc(r['ph_calibration']),
        esc(r['conductivity_calibration']), esc(r['temperature_check']),
        esc(r['ro_filter_sediment']), esc(r['ro_filter_carbon']),
        esc(r['incidents']), esc(r['observations']),
      ].join(','));
    }
    try {
      final dir = await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
      final file = File(
          '${dir.path}/water_qc_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(buf.toString());
      await OpenFilex.open(file.path);
    } catch (e) {
      if (mounted) _snack('Export failed: $e', error: true);
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static String fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.spaceGrotesk(color: AppDS.textPrimary)),
      backgroundColor: error ? AppDS.red.withValues(alpha: 0.9) : AppDS.surface,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ── Maintenance summary ────────────────────────────────────────────────────

  Widget _buildMaintSummary() {
    final now = DateTime.now();
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.appBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
            child: Row(children: [
              const Icon(Icons.build_circle_outlined, size: 15, color: _pageAccent),
              const SizedBox(width: 6),
              Text('Maintenance Overview',
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: context.appTextPrimary)),
              const SizedBox(width: 8),
              Flexible(child: Text(
                  'Double-click Last Done to edit · Click Optimal to change interval',
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 10, color: context.appTextMuted),
                  overflow: TextOverflow.ellipsis)),
            ]),
          ),
          Divider(height: 1, color: context.appBorder),
          // Water quality limits row
          _buildThresholdsRow(),
          Divider(height: 1, color: context.appBorder),
          // Column headers
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 5, 12, 4),
            child: Row(children: [
              Expanded(child: _hdrLabel('Maintenance item')),
              SizedBox(width: 108, child: _hdrLabel('Last done', center: true)),
              SizedBox(width: 56,  child: _hdrLabel('Days ago', center: true)),
              SizedBox(width: 70,  child: _hdrLabel('Optimal', center: true)),
              SizedBox(width: 108, child: _hdrLabel('Next due', center: true)),
              SizedBox(width: 90,  child: _hdrLabel('Status', center: true)),
            ]),
          ),
          Divider(height: 1, color: context.appBorder),
          for (int i = 0; i < _maintKeys.length; i++) ...[
            _buildMaintRow(_maintKeys[i], now),
            if (i < _maintKeys.length - 1)
              Divider(height: 1, indent: 12, endIndent: 12, color: context.appBorder),
          ],
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String mode, Color? color) {
    final selected = _filterMode == mode;
    final c = color ?? _pageAccent;
    return GestureDetector(
      onTap: () => setState(() => _filterMode = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? c.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? c : AppDS.border, width: selected ? 1.5 : 1),
        ),
        child: Text(label,
            style: GoogleFonts.spaceGrotesk(
                color: selected ? c : AppDS.textSecondary,
                fontSize: 12,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.normal)),
      ),
    );
  }

  Widget _hdrLabel(String t, {bool center = false}) => Text(t,
      textAlign: center ? TextAlign.center : TextAlign.start,
      style: GoogleFonts.spaceGrotesk(
          fontSize: 10, fontWeight: FontWeight.w700, color: context.appTextMuted));

  Widget _buildThresholdsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: Row(children: [
        Text('Quality limits:',
            style: GoogleFonts.spaceGrotesk(
                fontSize: 10, fontWeight: FontWeight.w700,
                color: context.appTextMuted)),
        const SizedBox(width: 10),
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: _thresholdDefs.map((def) {
              final key    = def.$1;
              final label  = def.$2;
              final unit   = def.$3;
              final hasMin = def.$4;
              final t      = _thresholds[key];
              final min    = t?['minValue'] as double?;
              final set    = t?['setVal']   as double?;
              final max    = t?['maxValue'] as double?;

              final isInt = _intCols.contains(key);
              String fmt(double v) {
                if (isInt) return v.round().toString();
                return v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
              }

              final String display;
              final suffix = unit.isNotEmpty ? ' $unit' : '';
              if (min != null && set != null && max != null) {
                display = '$label: ${fmt(min)}–${fmt(set)}–${fmt(max)}$suffix';
              } else if (min != null && max != null) {
                display = '$label: ${fmt(min)}–${fmt(max)}$suffix';
              } else if (set != null) {
                display = '$label: ${fmt(set)}$suffix';
              } else if (max != null) {
                display = '$label: ≤${fmt(max)}$suffix';
              } else if (min != null) {
                display = '$label: ≥${fmt(min)}$suffix';
              } else {
                display = '$label: —';
              }

              final hasValue = min != null || max != null;
              return GestureDetector(
                onTap: () => _editThreshold(key, label, hasMin),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: hasValue
                        ? _pageAccent.withValues(alpha: 0.08)
                        : context.appSurface2,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: hasValue
                          ? _pageAccent.withValues(alpha: 0.35)
                          : context.appBorder,
                    ),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(display,
                        style: GoogleFonts.spaceGrotesk(
                            fontSize: 10,
                            color: hasValue
                                ? context.appTextPrimary
                                : context.appTextMuted)),
                    const SizedBox(width: 4),
                    Icon(Icons.edit_outlined, size: 10,
                        color: context.appTextMuted),
                  ]),
                ),
              );
            }).toList(),
          ),
        ),
      ]),
    );
  }

  Widget _buildMaintRow(String key, DateTime now) {
    final label       = _maintLabels[key] ?? key;
    final lastDate    = _maint[key]?['lastDone'] as DateTime?;
    final optimalDays = (_maint[key]?['optimalDays'] as int?) ?? 30;

    String lastStr  = '—';
    String daysStr  = '—';
    String nextStr  = '—';
    Color  badge    = context.appTextMuted;
    String badgeStr = '—';

    if (lastDate != null) {
      lastStr = fmtDate(lastDate);
      final daysAgo  = now.difference(lastDate).inDays;
      daysStr = '$daysAgo';
      final nextDate = lastDate.add(Duration(days: optimalDays));
      nextStr = fmtDate(nextDate);
      final daysLeft = nextDate.difference(now).inDays;
      if (daysLeft < 0) {
        badge = AppDS.red;   badgeStr = '${daysLeft.abs()}d overdue';
      } else if (daysLeft <= 7) {
        badge = AppDS.yellow; badgeStr = daysLeft == 0 ? 'today' : 'in ${daysLeft}d';
      } else {
        badge = AppDS.green;  badgeStr = 'in ${daysLeft}d';
      }
    } else {
      badge = AppDS.red; badgeStr = 'never done';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: Row(children: [
        // Item name
        Expanded(
          child: Text(label,
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 11, color: context.appTextSecondary),
              overflow: TextOverflow.ellipsis),
        ),
        // Last done — double-click to edit
        GestureDetector(
          onDoubleTap: () => _editMaintLastDone(key),
          child: Tooltip(
            message: 'Double-click to change date',
            child: Container(
              width: 108,
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(lastStr,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      color: lastDate != null
                          ? context.appTextSecondary
                          : context.appTextMuted,
                      decoration:
                          lastDate != null ? TextDecoration.underline : null,
                      decorationStyle: TextDecorationStyle.dotted)),
            ),
          ),
        ),
        // Days ago — calculated
        SizedBox(
          width: 56,
          child: Text(daysStr,
              textAlign: TextAlign.center,
              style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  color: lastDate != null ? badge : context.appTextMuted,
                  fontWeight:
                      lastDate != null ? FontWeight.w700 : FontWeight.w400)),
        ),
        // Optimal — click to edit
        GestureDetector(
          onTap: () => _editMaintOptimal(key),
          child: Tooltip(
            message: 'Click to change interval',
            child: Container(
              width: 70,
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text('$optimalDays d',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      color: context.appTextSecondary,
                      decoration: TextDecoration.underline,
                      decorationStyle: TextDecorationStyle.dotted)),
            ),
          ),
        ),
        // Next due — calculated
        SizedBox(
          width: 108,
          child: Text(nextStr,
              textAlign: TextAlign.center,
              style: GoogleFonts.jetBrainsMono(
                  fontSize: 11, color: context.appTextSecondary)),
        ),
        // Status badge
        SizedBox(
          width: 90,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: badge.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(badgeStr,
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 10, fontWeight: FontWeight.w600, color: badge)),
            ),
          ),
        ),
      ]),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final tableWidth = _cols.fold(0.0, (s, c) => s + c.$3) + 36;

    return Column(
      children: [
        // ── Toolbar ──────────────────────────────────────────────────────────
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: context.appSurface2,
            border: Border(bottom: BorderSide(color: context.appBorder)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            const Icon(Icons.water_drop_outlined, size: 18, color: _pageAccent),
            const SizedBox(width: 8),
            Text('Water QC',
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: context.appTextPrimary)),
            const SizedBox(width: 16),
            Expanded(
              child: SizedBox(
                height: 36,
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (_) => setState(() {}),
                  style: GoogleFonts.spaceGrotesk(
                      color: context.appTextPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search by date, observations…',
                    hintStyle: GoogleFonts.spaceGrotesk(
                        color: context.appTextMuted, fontSize: 13),
                    prefixIcon: Icon(Icons.search,
                        color: context.appTextMuted, size: 16),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear,
                                size: 14, color: context.appTextMuted),
                            onPressed: () => setState(() => _searchCtrl.clear()))
                        : null,
                    filled: true,
                    fillColor: context.appSurface3,
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: context.appBorder)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: context.appBorder)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: _pageAccent)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '${_filteredRows.length} record${_filteredRows.length == 1 ? '' : 's'}',
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 12, color: context.appTextMuted),
              ),
            ),
            Tooltip(
              message: _showFilters ? 'Hide filters' : 'Show filters',
              child: Stack(children: [
                IconButton(
                  icon: Icon(Icons.tune,
                      color: _showFilters ? _pageAccent : context.appTextSecondary,
                      size: 18),
                  onPressed: () => setState(() => _showFilters = !_showFilters),
                ),
                if (_hasActiveFilter)
                  Positioned(
                    right: 6, top: 6,
                    child: Container(
                      width: 7, height: 7,
                      decoration: const BoxDecoration(
                          color: _pageAccent, shape: BoxShape.circle),
                    ),
                  ),
              ]),
            ),
            Tooltip(
              message: 'Export CSV',
              child: IconButton(
                icon: Icon(Icons.download_outlined,
                    size: 18, color: context.appTextSecondary),
                onPressed: _exportCsv,
              ),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppDS.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                minimumSize: const Size(0, 36),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                textStyle: GoogleFonts.spaceGrotesk(fontSize: 13),
              ),
              onPressed: _addRowForDate,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add QC record'),
            ),
          ]),
        ),
        // ── Filter panel ─────────────────────────────────────────────────────
        if (_showFilters)
          Container(
            decoration: BoxDecoration(
              color: context.appSurface,
              border: Border(bottom: BorderSide(color: context.appBorder)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: [
              Text('Show:',
                  style: GoogleFonts.spaceGrotesk(
                      color: context.appTextMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
              _filterChip('All', 'all', null),
              const SizedBox(width: 6),
              _filterChip('Out of range', 'out_of_range', AppDS.red),
              const SizedBox(width: 6),
              _filterChip('Has incidents', 'has_incidents', AppDS.orange),
            ]),
          ),

        // ── Maintenance summary ───────────────────────────────────────────────
        if (!_loading && _error == null) _buildMaintSummary(),

        // ── Table ─────────────────────────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Text('Error loading data: $_error',
                          style: GoogleFonts.spaceGrotesk(
                              color: AppDS.red, fontSize: 13)))
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                      child: Column(children: [
                        Expanded(
                          child: Row(children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppDS.tableBorder),
                                  boxShadow: const [BoxShadow(
                                      color: AppDS.shadow,
                                      blurRadius: 4,
                                      offset: Offset(0, 2))],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: NotificationListener<ScrollNotification>(
                                    onNotification: (n) {
                                      if (n is ScrollUpdateNotification) {
                                        if (n.metrics.axis == Axis.horizontal) {
                                          _hOffset.value = _horizCtrl.hasClients
                                              ? _horizCtrl.offset : 0;
                                        } else {
                                          _vOffset.value = _vertCtrl.hasClients
                                              ? _vertCtrl.offset : 0;
                                        }
                                      }
                                      return false;
                                    },
                                    child: SingleChildScrollView(
                                      controller: _horizCtrl,
                                      scrollDirection: Axis.horizontal,
                                      child: SizedBox(
                                        width: tableWidth,
                                        child: Column(children: [
                                          // Sticky header
                                          Container(
                                            height: AppDS.tableHeaderH,
                                            color: context.appHeaderBg,
                                            child: Row(children: [
                                              const SizedBox(width: 36),
                                              ..._cols.map((c) => SizedBox(
                                                width: c.$3,
                                                child: Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(horizontal: 6),
                                                  child: Text(c.$2,
                                                      style: GoogleFonts
                                                          .spaceGrotesk(
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w700,
                                                        color: context.appHeaderText,
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis),
                                                ),
                                              )),
                                            ]),
                                          ),
                                          Container(height: 1, color: AppDS.tableBorder),
                                          // Rows
                                          Expanded(
                                            child: ListView.builder(
                                              controller: _vertCtrl,
                                              // +1 for the "add next" row at index 0
                                              itemCount: _filteredRows.length + 1,
                                              itemExtent: AppDS.tableRowH,
                                              itemBuilder: (_, i) {
                                                if (i == 0) return _buildAddNextRow();
                                                final fr = _filteredRows;
                                                return _buildRow(fr[i - 1], i - 1);
                                              },
                                            ),
                                          ),
                                        ]),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            AppVerticalThumb(
                              contentLength: (_filteredRows.length + 1) * AppDS.tableRowH,
                              topPadding: AppDS.tableHeaderH,
                              offset: _vOffset,
                              onScrollTo: (y) {
                                if (_vertCtrl.hasClients) {
                                  _vertCtrl.jumpTo(y.clamp(
                                      0.0, _vertCtrl.position.maxScrollExtent));
                                }
                                _vOffset.value = y;
                              },
                            ),
                          ]),
                        ),
                        const SizedBox(height: 4),
                        AppHorizontalThumb(
                          contentWidth: tableWidth,
                          offset: _hOffset,
                          onScrollTo: (x) {
                            if (_horizCtrl.hasClients) {
                              _horizCtrl.jumpTo(x.clamp(
                                  0.0, _horizCtrl.position.maxScrollExtent));
                            }
                            _hOffset.value = x;
                          },
                        ),
                        const SizedBox(height: 4),
                      ]),
                    ),
        ),
      ],
    );
  }

  // ── "Add next" row at top of list ─────────────────────────────────────────

  Widget _buildAddNextRow() {
    DateTime nextDate;
    if (_rows.isEmpty) {
      nextDate = DateTime.now();
    } else {
      final latestStr = _rows[0]['record_date']?.toString();
      final latest    = latestStr != null ? DateTime.tryParse(latestStr) : null;
      nextDate = (latest ?? DateTime.now()).add(const Duration(days: 1));
    }
    final label = fmtDate(nextDate);
    return InkWell(
      onTap: _addNextRow,
      child: Container(
        decoration: BoxDecoration(
          color: _pageAccent.withValues(alpha: 0.06),
          border: Border(bottom: BorderSide(
              color: _pageAccent.withValues(alpha: 0.25), width: 1)),
        ),
        child: Row(children: [
          SizedBox(
            width: 36,
            child: Center(
              child: Icon(Icons.add_circle_outline,
                  size: 16, color: _pageAccent),
            ),
          ),
          Text(label,
              style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _pageAccent)),
          const SizedBox(width: 8),
          Text('— tap or Ctrl+Enter to add',
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 10, color: _pageAccent.withValues(alpha: 0.6))),
        ]),
      ),
    );
  }

  // ── Row builder ────────────────────────────────────────────────────────────

  Widget _buildRow(Map<String, dynamic> row, int i) {
    final bg = i.isEven ? AppDS.tableRowEven : AppDS.tableRowOdd;
    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: const Border(bottom: BorderSide(color: AppDS.tableBorder, width: 1)),
      ),
      child: Row(children: [
        SizedBox(
          width: 36,
          child: AppIconButton(
            icon: Icons.delete_outline,
            tooltip: 'Delete row',
            color: AppDS.tableTextMute,
            onPressed: () => _deleteRow(row),
          ),
        ),
        ..._cols.map((c) => _buildCell(row, c)),
      ]),
    );
  }

  // ── Cell builder ───────────────────────────────────────────────────────────

  Widget _buildCell(
      Map<String, dynamic> row,
      (String, String, double, String) col) {
    final key   = col.$1;
    final width = col.$3;
    final type  = col.$4;
    final rowId = row['id'].toString();
    final val   = row[key];
    final isEdit = _editingCell?['id'] == rowId && _editingCell?['col'] == key;

    // ── Record date — tap to open DatePicker ──────────────────────────────
    if (type == 'date') {
      return SizedBox(
        width: width,
        child: GestureDetector(
          onTap: () async {
            if (!context.canEditModule) { context.warnReadOnly(); return; }
            final current = val != null ? DateTime.tryParse(val.toString()) : null;
            final picked  = await showDatePicker(
              context: context,
              initialDate: current ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (picked == null || !mounted) return;
            final ds = fmtDate(picked);
            final ri = _rows.indexWhere((r) => r['id'] == row['id']);
            if (ri >= 0) setState(() => _rows[ri] = {..._rows[ri], key: ds});
            try {
              await Supabase.instance.client
                  .from('water_qc').update({key: ds}).eq('id', row['id'] as int);
            } catch (_) { if (mounted) _load(); }
          },
          child: Container(
            height: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            alignment: Alignment.centerLeft,
            child: Text(val?.toString() ?? '—',
                style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    color: AppDS.tableText,
                    fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis),
          ),
        ),
      );
    }

    // ── Maintenance col — double-click to open DatePicker ─────────────────
    if (type == 'maint') {
      final isEmpty = val == null || val.toString().trim().isEmpty;
      return GestureDetector(
        onDoubleTap: () => _pickMaintDate(row, key),
        child: Tooltip(
          message: 'Double-click to set date',
          child: Container(
            width: width,
            height: double.infinity,
            color: isEmpty ? null : const Color(0xFF22C55E).withValues(alpha: 0.12),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            alignment: Alignment.centerLeft,
            child: Text(
              isEmpty ? '—' : val.toString(),
              style: isEmpty
                  ? GoogleFonts.jetBrainsMono(
                      fontSize: 11, color: AppDS.tableTextMute)
                  : GoogleFonts.jetBrainsMono(
                      fontSize: 11, color: const Color(0xFF15803D)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      );
    }

    // ── Editing cell ──────────────────────────────────────────────────────
    if (isEdit) {
      return SizedBox(
        width: width,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
          child: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.tab):
                  () => _advanceCell(),
              const SingleActivator(LogicalKeyboardKey.tab, shift: true):
                  () => _advanceCell(forward: false),
              const SingleActivator(LogicalKeyboardKey.enter):
                  () => _advanceCell(),
              const SingleActivator(LogicalKeyboardKey.enter, control: true): () {
                _commitCurrentEdit();
                setState(() => _editingCell = null);
                _addNextRow();
              },
              const SingleActivator(LogicalKeyboardKey.escape): _cancelEdit,
            },
            child: TextField(
              controller: _editCtrl,
              focusNode: _editFocus,
              keyboardType: type == 'num'
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.text,
              style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppDS.tableText),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                  borderSide: BorderSide(color: Color(0xFF22D3EE), width: 1.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                  borderSide: BorderSide(color: Color(0xFF22D3EE), width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                  borderSide: BorderSide(color: Color(0xFF22D3EE), width: 2),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // ── Read-only cell ────────────────────────────────────────────────────
    final isEmpty = val == null || val.toString().trim().isEmpty;
    Color? cellBg;
    Color textColor = AppDS.tableText;
    if (type == 'num' && !isEmpty && _isOutOfRange(key, val)) {
      cellBg    = AppDS.red.withValues(alpha: 0.13);
      textColor = AppDS.red;
    } else if (type == 'incident' && !isEmpty) {
      cellBg    = AppDS.red.withValues(alpha: 0.10);
      textColor = AppDS.red;
    }

    String displayVal = '—';
    if (!isEmpty) {
      if (type == 'num' && _intCols.contains(key)) {
        final n = double.tryParse(val.toString());
        displayVal = n != null ? n.round().toString() : val.toString();
      } else {
        displayVal = val.toString();
      }
    }

    return GestureDetector(
      onTap: () {
        if (!context.canEditModule) { context.warnReadOnly(); return; }
        _startEdit(rowId, key);
      },
      child: Container(
        width: width,
        height: double.infinity,
        color: cellBg,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        alignment: Alignment.centerLeft,
        child: Text(
          displayVal,
          style: isEmpty
              ? GoogleFonts.jetBrainsMono(fontSize: 11, color: AppDS.tableTextMute)
              : (type == 'num'
                  ? GoogleFonts.jetBrainsMono(fontSize: 11, color: textColor)
                  : GoogleFonts.spaceGrotesk(fontSize: 11, color: textColor)),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
