

import 'package:flutter/material.dart';
import '/theme/module_permission.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'strain_detail_page.dart';
import '../function_excel_import_page.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'dart:io';
import '/core/data_cache.dart';
import 'strains_columns.dart';
import 'strains_design_tokens.dart';
import '/theme/theme.dart';
import 'strains_grid_widgets.dart';
import 'strains_appbars.dart';
import 'strains_toolbar.dart';

// ignore_for_file: use_build_context_synchronously

// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────
class StrainsPage extends StatefulWidget {
  final dynamic filterSampleId;
  final dynamic autoOpenNewStrainForSample;
  final dynamic highlightStrainId;
  const StrainsPage({
    super.key,
    this.filterSampleId,
    this.autoOpenNewStrainForSample,
    this.highlightStrainId,
  });

  @override
  State<StrainsPage> createState() => _StrainsPageState();
}

class _StrainsPageState extends State<StrainsPage> {
  // ── State ──────────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _rows     = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;

  bool _selectionMode = false;
  final Set<dynamic> _selectedRowIds  = {};
  final Set<String>  _selectedColKeys = {};

  String            _search = '';
  List<String>      _sortKeys = [];
  Map<String, bool> _sortDirs = {};
  final _searchController = TextEditingController();
  bool _showFilters    = false;
  bool _showColManager = false;
  final List<ActiveFilter> _activeFilters = [];
  List<int> _periodicityOptions = [];
  int?      _selectedPeriodicity;

  bool        _hideEmpty    = false;
  Set<String> _hiddenCols   = {};
  Set<String> _emptyColKeys = {};

  final Map<String, double> _colWidths = {};
  List<String>? _colOrder;
  String? _draggingColKey;
  int?    _dropTargetIndex;

  Map<String, dynamic>? _editingCell;
  final _editController = TextEditingController();

  final _hScroll = ScrollController();
  final _vScroll = ScrollController();
  final _hOffset = ValueNotifier<double>(0);
  final _vOffset = ValueNotifier<double>(0);

  // ── Derived ────────────────────────────────────────────────────────────────
  List<StrainColDef> get _visibleCols {
    final ordered = _colOrder == null
        ? List<StrainColDef>.from(strainAllColumns)
        : [
            ..._colOrder!
                .map((k) {
                  try { return strainAllColumns.firstWhere((c) => c.key == k); }
                  catch (_) { return null; }
                })
                .whereType<StrainColDef>(),
            ...strainAllColumns.where((c) => !_colOrder!.contains(c.key)),
          ];
    return ordered.where((col) {
      if (_hiddenCols.contains(col.key))   return false;
      if (_emptyColKeys.contains(col.key)) return false;
      return true;
    }).toList();
  }

  double _colWidth(StrainColDef col) => _colWidths[col.key] ?? col.defaultWidth;

  List<StrainColDef> get _exportCols {
    if (_selectionMode && _selectedColKeys.isNotEmpty) {
      return _visibleCols.where((c) => _selectedColKeys.contains(c.key)).toList();
    }
    return _visibleCols;
  }

  List<Map<String, dynamic>> get _selectedRows =>
      _filtered.where((r) => _selectedRowIds.contains(r['strain_id'])).toList();

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadPrefs().then((_) => _load().then((_) {
      if (widget.autoOpenNewStrainForSample != null && mounted) {
        _showAddStrainDialog(preselectedSampleId: widget.autoOpenNewStrainForSample);
      }
    }));
  }

  @override
  void dispose() {
    _editController.dispose();
    _searchController.dispose();
    _hScroll.dispose();
    _vScroll.dispose();
    _hOffset.dispose();
    _vOffset.dispose();
    super.dispose();
  }

  // ── Prefs ──────────────────────────────────────────────────────────────────
  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      final keysStr = prefs.getString(strainPrefSortKeys);
      if (keysStr != null && keysStr.isNotEmpty) {
        _sortKeys = keysStr.split(',').where((s) => s.isNotEmpty).toList();
      }
      final dirsStr = prefs.getString(strainPrefSortDirs);
      if (dirsStr != null && dirsStr.isNotEmpty) {
        for (final part in dirsStr.split('|')) {
          final kv = part.split(':');
          if (kv.length == 2) _sortDirs[kv[0]] = kv[1] == 'asc';
        }
      }
      for (final k in prefs.getKeys()) {
        if (k.startsWith('$strainPrefColWidths.')) {
          final w = prefs.getDouble(k);
          if (w != null) _colWidths[k.substring('$strainPrefColWidths.'.length)] = w;
        }
      }
      final saved = prefs.getString(strainPrefColOrder);
      if (saved != null && saved.isNotEmpty) {
        _colOrder = saved.split(',').where((s) => s.isNotEmpty).toList();
      }
      _hideEmpty = prefs.getBool(strainPrefHideEmpty) ?? false;
    });
  }

  Future<void> _saveHideEmptyPref(bool v) async =>
      (await SharedPreferences.getInstance()).setBool(strainPrefHideEmpty, v);

  Future<void> _saveSortPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (_sortKeys.isEmpty) {
      await prefs.remove(strainPrefSortKeys);
      await prefs.remove(strainPrefSortDirs);
    } else {
      await prefs.setString(strainPrefSortKeys, _sortKeys.join(','));
      await prefs.setString(strainPrefSortDirs,
          _sortKeys.map((k) => '$k:${_sortDirs[k] == true ? "asc" : "desc"}').join('|'));
    }
  }

  Future<void> _saveColWidth(String key, double w) async =>
      (await SharedPreferences.getInstance()).setDouble('$strainPrefColWidths.$key', w);

  Future<void> _resetColWidths() async {
    final prefs = await SharedPreferences.getInstance();
    for (final k in prefs.getKeys()
        .where((k) => k.startsWith('$strainPrefColWidths.')).toList()) {
      await prefs.remove(k);
    }
    setState(() => _colWidths.clear());
  }

  Future<void> _saveColOrder() async {
    if (_colOrder == null) return;
    await (await SharedPreferences.getInstance())
        .setString(strainPrefColOrder, _colOrder!.join(','));
  }

  Future<void> _resetColOrder() async {
    await (await SharedPreferences.getInstance()).remove(strainPrefColOrder);
    setState(() => _colOrder = null);
  }

  void _reorderCol(String colKey, int toVisibleIndex) {
    final mutable = List<String>.from(
        _colOrder ?? strainAllColumns.map((c) => c.key).toList())
      ..remove(colKey);
    final visible = _visibleCols;
    String? anchor;
    if (toVisibleIndex < visible.length) {
      anchor = visible[toVisibleIndex].key;
      if (anchor == colKey) {
        setState(() { _draggingColKey = null; _dropTargetIndex = null; });
        return;
      }
    }
    if (anchor == null) {
      final lv = visible.isNotEmpty ? visible.last.key : null;
      if (lv != null) {
        mutable.insert((mutable.indexOf(lv) + 1).clamp(0, mutable.length), colKey);
      } else {
        mutable.add(colKey);
      }
    } else {
      mutable.insert(mutable.indexOf(anchor).clamp(0, mutable.length), colKey);
    }
    setState(() { _colOrder = mutable; _draggingColKey = null; _dropTargetIndex = null; });
    _saveColOrder();
  }

  // ── Data ──────────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _strainRowsFromRaw(List<dynamic> raw) =>
      raw.map((r) {
        final row = Map<String, dynamic>.from(r as Map);
        final s = row['samples'] as Map<String, dynamic>? ?? {};
        for (final k in [
          'rebeca', 'ccpi', 'date', 'country', 'archipelago', 'island',
          'municipality', 'local', 'habitat_type', 'habitat_1', 'habitat_2',
          'habitat_3', 'method', 'gps', 'temperature', 'ph', 'conductivity',
          'oxygen', 'salinity', 'radiation', 'responsible', 'observations',
        ]) { row['s_$k'] = s['sample_$k']; }
        row.remove('samples');
        _computeNextTransfer(row);
        return row;
      }).toList();

  Future<void> _load() async {
    final cacheKey = widget.filterSampleId != null ? 'strains_${widget.filterSampleId}' : 'strains';
    final cached = await DataCache.read(cacheKey);
    if (cached != null && mounted) {
      _rows = _strainRowsFromRaw(cached);
      if (_hideEmpty) { _detectEmptyCols(); } else { _emptyColKeys = {}; }
      _buildPeriodicityOptions();
      _applyFilter();
      setState(() => _loading = false);
    } else {
      setState(() => _loading = true);
    }
    try {
      var q = Supabase.instance.client.from('strains').select('''
        *,
        samples (
          sample_code, sample_rebeca, sample_ccpi, sample_date,
          sample_country, sample_archipelago, sample_island,
          sample_municipality, sample_local,
          sample_habitat_type, sample_habitat_1, sample_habitat_2, sample_habitat_3,
          sample_method, sample_gps, sample_temperature, sample_ph,
          sample_conductivity, sample_oxygen, sample_salinity, sample_radiation,
          sample_responsible, sample_observations
        )
      ''');
      if (widget.filterSampleId != null) q = q.eq('strain_sample_code', widget.filterSampleId);
      final res = await q.order('strain_code', ascending: true);
      await DataCache.write(cacheKey, res as List<dynamic>);
      if (!mounted) return;
      _rows = _strainRowsFromRaw(res);
      if (_hideEmpty) { _detectEmptyCols(); } else { _emptyColKeys = {}; }
      _buildPeriodicityOptions();
      _applyFilter();
      _syncNextTransferDates(); // background — no await
      setState(() => _loading = false);
    } catch (e) {
      if (cached == null) _snack('Error loading strains: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _computeNextTransfer(Map<String, dynamic> row) {
    if (row['strain_next_transfer']?.toString().isNotEmpty == true) return;
    final lastStr = row['strain_last_transfer']?.toString() ?? '';
    final days = int.tryParse(row['strain_periodicity']?.toString() ?? '');
    if (lastStr.isNotEmpty && days != null) {
      try {
        final next = DateTime.parse(lastStr).add(Duration(days: days));
        row['strain_next_transfer'] =
            '${next.year.toString().padLeft(4,"0")}-${next.month.toString().padLeft(2,"0")}-${next.day.toString().padLeft(2,"0")}';
        row['_next_transfer_computed'] = true;
      } catch (_) {}
    }
  }

  // Compares each strain's stored next_transfer against last_transfer+cycle.
  // Updates Supabase (and local state) silently for any mismatches.
  Future<void> _syncNextTransferDates() async {
    final List<({String id, String date})> toFix = [];
    for (final row in _rows) {
      final lastStr = row['strain_last_transfer']?.toString() ?? '';
      final days    = int.tryParse(row['strain_periodicity']?.toString() ?? '');
      if (lastStr.isEmpty || days == null) continue;
      DateTime computed;
      try { computed = DateTime.parse(lastStr).add(Duration(days: days)); }
      catch (_) { continue; }
      final expected = '${computed.year.toString().padLeft(4, '0')}-'
          '${computed.month.toString().padLeft(2, '0')}-'
          '${computed.day.toString().padLeft(2, '0')}';
      if ((row['strain_next_transfer']?.toString() ?? '') == expected) continue;
      row['strain_next_transfer']   = expected;
      row['_next_transfer_computed'] = false;
      toFix.add((id: row['strain_id'].toString(), date: expected));
    }
    if (toFix.isEmpty) return;
    try {
      await Future.wait(toFix.map((u) => Supabase.instance.client
          .from('strains')
          .update({'strain_next_transfer': u.date})
          .eq('strain_id', u.id)));
      if (mounted) {
        _applyFilter();
        _snack('Synced ${toFix.length} transfer date${toFix.length != 1 ? 's' : ''}');
      }
    } catch (e) {
      if (mounted) _snack('Error syncing transfer dates: $e');
    }
  }

  void _detectEmptyCols() {
    _emptyColKeys = strainAllColumns
        .where((col) => !_rows.any((r) {
              final v = r[col.key];
              return v != null && v.toString().isNotEmpty;
            }))
        .map((c) => c.key)
        .toSet();
  }

  void _buildPeriodicityOptions() {
    _periodicityOptions = _rows
        .map((r) => int.tryParse(r['strain_periodicity']?.toString() ?? ''))
        .whereType<int>()
        .toSet()
        .toList()
      ..sort();
  }

  // ── Filter / sort ──────────────────────────────────────────────────────────
  void _applyFilter() {
    var list = List<Map<String, dynamic>>.from(_rows);
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((r) =>
          r.values.any((v) => v?.toString().toLowerCase().contains(q) == true)).toList();
    }
    for (final f in _activeFilters) {
      if (f.value.isEmpty) continue;
      final q = f.value.toLowerCase();
      list = list
          .where((r) => r[f.column]?.toString().toLowerCase().contains(q) == true).toList();
    }
    if (_selectedPeriodicity != null) {
      list = list.where((r) =>
          int.tryParse(r['strain_periodicity']?.toString() ?? '') == _selectedPeriodicity).toList();
    }
    _filtered = list;
    _applySort();
  }

  static const _intSortCols = {
    'strain_periodicity', 'strain_seq_16s_bp', 'strain_seq_18s_bp',
    'strain_its2_bp', 'strain_rbcl_bp', 'strain_tufa_bp', 'strain_cox1_bp',
    'strain_genome_cont', 'strain_cryo_vials',
  };

  void _applySort() {
    if (_sortKeys.isEmpty) { if (mounted) setState(() {}); return; }
    _filtered.sort((a, b) {
      for (final key in _sortKeys) {
        final isInt = _intSortCols.contains(key);
        final isAsc = _sortDirs[key] ?? true;
        late int cmp;
        if (isInt) {
          final ai = int.tryParse(a[key]?.toString() ?? '') ?? (isAsc ? 999999 : -1);
          final bi = int.tryParse(b[key]?.toString() ?? '') ?? (isAsc ? 999999 : -1);
          cmp = ai.compareTo(bi);
        } else {
          cmp = (a[key]?.toString() ?? '').compareTo(b[key]?.toString() ?? '');
        }
        if (cmp != 0) return isAsc ? cmp : -cmp;
      }
      return 0;
    });
    if (mounted) setState(() {});
  }

  void _onSort(String key) {
    setState(() {
      if (_sortKeys.contains(key)) {
        _sortDirs[key] = !(_sortDirs[key] ?? true);
      } else { _sortKeys.add(key); _sortDirs[key] = true; }
    });
    _saveSortPrefs();
    _applySort();
  }

  void _resetSort() {
    setState(() { _sortKeys.clear(); _sortDirs.clear(); });
    _saveSortPrefs();
    _applySort();
  }

  // ── Edit ──────────────────────────────────────────────────────────────────
  Future<void> _commitEdit(Map<String, dynamic> row, String key, String value) async {
    final id = row['strain_id'];
    try {
      await Supabase.instance.client
          .from('strains')
          .update({key: value.isEmpty ? null : value})
          .eq('strain_id', id);
      final idx = _rows.indexWhere((r) => r['strain_id'] == id);
      if (idx != -1) {
        _rows[idx][key] = value.isEmpty ? null : value;
        if (key == 'strain_last_transfer' || key == 'strain_periodicity') {
          _rows[idx].remove('strain_next_transfer');
          _rows[idx].remove('_next_transfer_computed');
          _computeNextTransfer(_rows[idx]);
        }
      }
      _applyFilter();
    } catch (e) { _snack('Save error: $e'); }
    setState(() => _editingCell = null);
  }

  Future<void> _showStatusPicker(Map<String, dynamic> row, Offset pos) async {
    final current = row['strain_status']?.toString();
    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx + 1, pos.dy + 1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      items: strainStatusOptions.map((s) => PopupMenuItem<String>(
        value: s,
        child: Row(children: [
          _statusIcon(s, size: 16),
          const SizedBox(width: 10),
          Text(s, style: TextStyle(
              fontWeight: current == s ? FontWeight.bold : FontWeight.normal,
              color: _statusColor(s), fontSize: 13)),
          if (current == s) ...[const Spacer(), const Icon(Icons.check, size: 14)],
        ]),
      )).toList(),
    );
    if (result != null && result != current) await _commitEdit(row, 'strain_status', result);
  }

  Future<void> _showTransferDatePicker(Map<String, dynamic> row) async {
    DateTime? selectedDate;
    final currentDate = DateTime.tryParse(row['strain_last_transfer']?.toString() ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDs) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                title: const Text('Set Last Transfer Date'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(
                      width: 300,
                      child: CalendarDatePicker(
                        initialDate: currentDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                        onDateChanged: (d) => setDs(() => selectedDate = d),
                      )),
                  if (selectedDate != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                          color: AppDS.tableRowSel,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFBFDBFE))),
                      child: Text(
                          '${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2,"0")}-${selectedDate!.day.toString().padLeft(2,"0")}',
                          style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1D4ED8))),
                    ),
                  ],
                ]),
                actions: [
                  TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
                  FilledButton.icon(
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('This strain'),
                      onPressed: selectedDate != null ? () => Navigator.of(ctx).pop('insert_single') : null),
                  FilledButton.tonal(
                      onPressed: selectedDate != null ? () => Navigator.of(ctx).pop('insert_all') : null,
                      child: const Text('All same cycle')),
                ],
              )),
    );
    if (selectedDate == null || result == null) return;
    final dateStr =
        '${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2,"0")}-${selectedDate!.day.toString().padLeft(2,"0")}';
    if (result == 'insert_single') {
      await _commitEdit(row, 'strain_last_transfer', dateStr);
      if (mounted) _snack('Last transfer updated for ${row["strain_code"]}');
    } else {
      final periodicity = row['strain_periodicity'];
      if (periodicity == null || periodicity <= 0) {
        _snack('Cannot use "All same cycle" — strain_periodicity not set'); return;
      }
      try {
        await Supabase.instance.client.from('strains')
            .update({'strain_last_transfer': dateStr}).eq('strain_periodicity', periodicity);
        if (mounted) { _snack('Updated all strains with $periodicity-day cycle'); _load(); }
      } catch (e) { if (mounted) _snack('Error: $e'); }
    }
  }

  void _openDetail(Map<String, dynamic> row) {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) =>
            StrainDetailPage(strainId: row['strain_id'], onSaved: _load)))
        .then((_) => _load());
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m), behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))));
  }

  Color _statusColor(String? s) {
    if (s == 'ALIVE')  return AppDS.green;
    if (s == 'DEAD')   return AppDS.red;
    if (s == 'INCARE') return AppDS.yellow;
    return AppDS.textMuted;
  }

  Widget _statusIcon(String? s, {double size = 11}) {
    return Icon(
      s == 'ALIVE'  ? Icons.check_circle_rounded
        : s == 'DEAD'   ? Icons.cancel_rounded
        : s == 'INCARE' ? Icons.medical_services_rounded
        : Icons.help_outline_rounded,
      size: size, color: _statusColor(s));
  }

  // ── Selection ─────────────────────────────────────────────────────────────
  void _enterSelectionMode() => setState(() {
    _selectionMode = true;
    _selectedRowIds.clear();
    _selectedColKeys..clear()..addAll(_visibleCols.map((c) => c.key));
  });
  void _exitSelectionMode() => setState(() {
    _selectionMode = false; _selectedRowIds.clear(); _selectedColKeys.clear();
  });
  void _toggleRowSelection(dynamic id) => setState(() {
    if (_selectedRowIds.contains(id)) {
      _selectedRowIds.remove(id);
    } else {
      _selectedRowIds.add(id);
    }
  });
  void _toggleColSelection(String key) => setState(() {
    if (_selectedColKeys.contains(key)) {
      _selectedColKeys.remove(key);
    } else {
      _selectedColKeys.add(key);
    }
  });
  void _selectAllRows() => setState(() {
    if (_selectedRowIds.length == _filtered.length) {
      _selectedRowIds.clear();
    } else {
      _selectedRowIds.addAll(_filtered.map((r) => r['strain_id']));
    }
  });
  void _selectAllCols() => setState(() {
    final v = _visibleCols.map((c) => c.key).toSet();
    if (_selectedColKeys.containsAll(v)) {
      _selectedColKeys.clear();
    } else {
      _selectedColKeys.addAll(v);
    }
  });

  // ── Export ────────────────────────────────────────────────────────────────
  Future<void> _copySelectedInfo() async {
    final rows = _selectedRows; final cols = _exportCols;
    if (rows.isEmpty) { _snack('Select at least one row'); return; }
    final buf = StringBuffer()..writeln(cols.map((c) => c.label).join('\t'));
    for (final row in rows) {
      buf.writeln(cols.map((c) => row[c.key]?.toString() ?? '').join('\t'));
    }
    await Clipboard.setData(ClipboardData(text: buf.toString()));
    _snack('Copied ${rows.length} row(s) x ${cols.length} col(s)');
  }

  Future<void> _exportSelectedToExcel() async {
    final rows = _selectedRows; final cols = _exportCols;
    if (rows.isEmpty) { _snack('Select at least one row'); return; }
    final excel = Excel.createExcel();
    final sheet = excel['Sheet1'];
    for (int c = 0; c < cols.length; c++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0)).value =
          TextCellValue(cols[c].label);
    }
    for (int r = 0; r < rows.length; r++)
      for (int c = 0; c < cols.length; c++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1)).value =
            _toCellValue(rows[r][cols[c].key]);
      }
    final dir = await getTemporaryDirectory();
    final safeDate = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
    final path = '${dir.path}\\strains_export_$safeDate.xlsx';
    File(path)..createSync(recursive: true)..writeAsBytesSync(excel.encode()!);
    await OpenFilex.open(path);
    _snack('Excel exported (${rows.length} rows)');
  }

  CellValue _toCellValue(dynamic v) {
    if (v == null)     return TextCellValue('');
    if (v is int)      return IntCellValue(v);
    if (v is double)   return DoubleCellValue(v);
    if (v is bool)     return BoolCellValue(v);
    if (v is DateTime) return DateCellValue(year: v.year, month: v.month, day: v.day);
    return TextCellValue(v.toString());
  }

  Future<void> _showAddStrainDialog({dynamic preselectedSampleId}) async {
    if (!context.canEditModule) { context.warnReadOnly(); return; }
    List<Map<String, dynamic>> samples = [];
    try {
      samples = List<Map<String, dynamic>>.from(await Supabase.instance.client
          .from('samples').select('sample_id, sample_rebeca, sample_ccpi, sample_number')
          .order('sample_number'));
    } catch (e) { _snack('Could not load samples: $e'); return; }
    if (!mounted) return;
    dynamic selId = preselectedSampleId;
    final codeCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDs) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                title: const Text('New Strain'),
                content: SizedBox(width: 360, child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('A strain must originate from a sample.',
                      style: TextStyle(fontSize: 13, color: ctx.appTextMuted)),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<dynamic>(
                    initialValue: selId,
                    decoration: const InputDecoration(labelText: 'Source Sample *',
                        border: OutlineInputBorder(), isDense: true),
                    items: samples.map((s) {
                      final lbl = [s['sample_code']?.toString()]
                          .where((v) => v != null && v.isNotEmpty).join(' — ');
                      return DropdownMenuItem(value: s['sample_id'],
                          child: Text(lbl, overflow: TextOverflow.ellipsis));
                    }).toList(),
                    onChanged: (v) => setDs(() => selId = v),
                  ),
                  const SizedBox(height: 16),
                  TextField(controller: codeCtrl, decoration: const InputDecoration(
                      labelText: 'Strain Code', border: OutlineInputBorder(), isDense: true)),
                ])),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                  FilledButton(
                      onPressed: selId == null ? null : () => Navigator.pop(ctx, true),
                      child: const Text('Create')),
                ],
              )),
    );
    if (ok != true || selId == null) return;
    try {
      final res = await Supabase.instance.client.from('strains')
          .insert({'strain_sample_code': selId, 'strain_code': codeCtrl.text.isEmpty ? null : codeCtrl.text})
          .select().single();
      if (mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (_) =>
            StrainDetailPage(strainId: res['strain_code'], onSaved: _load)))
            .then((_) => _load());
      }
    } catch (e) { _snack('Error creating strain: $e'); }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final desktop = isDesktopPlatform(context);
    return Scaffold(
      backgroundColor: context.appBg,
      resizeToAvoidBottomInset: false,
      appBar: _selectionMode
          ? buildStrainsSelectionAppBar(
              desktop: desktop,
              rowCount: _selectedRowIds.length,
              colCount: _selectedColKeys.length,
              allRowsSel: _selectedRowIds.length == _filtered.length,
              allColsSel: _selectedColKeys.length == _visibleCols.length,
              onExit: _exitSelectionMode,
              onToggleAllRows: _selectAllRows,
              onToggleAllCols: _selectAllCols,
              onCopy: _copySelectedInfo,
              onExport: _exportSelectedToExcel,
            )
          : buildStrainsNormalAppBar(
              context: context,
              desktop: desktop,
              filterSampleId: widget.filterSampleId,
              showFilters: _showFilters,
              onToggleFilters: () => setState(() => _showFilters = !_showFilters),
              onAdd: _showAddStrainDialog,
              onRefresh: _load,
              onSelect: _enterSelectionMode,
              onToggleColManager: () => setState(() => _showColManager = !_showColManager),
              onImport: () async {
                final ok = await Navigator.push<bool>(context,
                    MaterialPageRoute(builder: (_) => const ExcelImportPage(mode: 'strains')));
                if (ok == true) _load();
              },
            ),
      body: Column(children: [
        StrainsToolbar(
          showFilters: _showFilters,
          activeFilters: _activeFilters,
          sortKeys: _sortKeys,
          sortDirs: _sortDirs,
          periodicityOptions: _periodicityOptions,
          selectedPeriodicity: _selectedPeriodicity,
          filteredCount: _filtered.length,
          totalCount: _rows.length,
          search: _search,
          searchController: _searchController,
          onSearchChanged: (v) { setState(() => _search = v); _applyFilter(); },
          onToggleFilters: () => setState(() => _showFilters = !_showFilters),
          onClearSort: _resetSort,
          onRemoveSortKey: (i, key) {
            setState(() { _sortKeys.removeAt(i); _sortDirs.remove(key); });
            _saveSortPrefs(); _applySort();
          },
          onPeriodicityChanged: (v) { setState(() => _selectedPeriodicity = v); _applyFilter(); },
          onClearFilters: () {
            setState(() { _activeFilters.clear(); _selectedPeriodicity = null; });
            _applyFilter();
          },
        ),
        if (_showFilters)
          StrainsFilterPanel(
            activeFilters: _activeFilters,
            hideEmpty: _hideEmpty,
            onDetectEmpty: () {
              setState(() { _hideEmpty = true; _detectEmptyCols(); });
              _saveHideEmptyPref(true);
            },
            onShowEmpty: () {
              setState(() { _hideEmpty = false; _emptyColKeys = {}; });
              _saveHideEmptyPref(false);
            },
            onAddFilter: (f) { setState(() => _activeFilters.add(f)); },
            onRemoveFilter: (f) { setState(() => _activeFilters.remove(f)); _applyFilter(); },
            onFilterChanged: (f, v) { f.value = v; _applyFilter(); },
          ),
        if (_showColManager)
          StrainsColumnManager(
            colOrder: _colOrder,
            colWidths: _colWidths,
            hiddenCols: _hiddenCols,
            emptyColKeys: _emptyColKeys,
            onClose: () => setState(() => _showColManager = false),
            onResetAll: () async {
              await _resetColWidths(); await _resetColOrder();
              setState(() => _hiddenCols = {});
              _snack('All column settings reset');
            },
            onReorder: (key, newPos) {
              final base = _colOrder ?? strainAllColumns.map((c) => c.key).toList();
              final extra = strainAllColumns.map((c) => c.key).where((k) => !base.contains(k));
              final display = [...base, ...extra];
              final m = List<String>.from(display)..remove(key);
              m.insert(newPos.clamp(1, display.length) - 1, key);
              setState(() => _colOrder = m);
              _saveColOrder();
            },
            onWidthChanged: (key, w) { setState(() => _colWidths[key] = w); _saveColWidth(key, w); },
            onVisibilityChanged: (key, v) => setState(() {
              if (v) {
                _hiddenCols.remove(key);
              } else {
                _hiddenCols.add(key);
              }
            }),
          ),
        if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else
          Expanded(child: _buildGrid()),
      ]),
    );
  }

  // ── Grid ──────────────────────────────────────────────────────────────────
  Widget _buildGrid() {
    if (_filtered.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.science_outlined, size: 56, color: context.appTextMuted),
        const SizedBox(height: 12),
        Text('No strains found', style: TextStyle(color: context.appTextMuted, fontSize: 15)),
        const SizedBox(height: 16),
        FilledButton.icon(
            onPressed: _showAddStrainDialog,
            icon: const Icon(Icons.add),
            label: const Text('Add First Strain'),
            style: FilledButton.styleFrom(backgroundColor: context.appSurface2)),
      ]));
    }
    final cols = _visibleCols;
    final totalWidth = (_selectionMode ? AppDS.tableCheckW : 0.0) +
        AppDS.tableOpenW + cols.fold(0.0, (s, c) => s + _colWidth(c));

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: Column(children: [
        Expanded(
          child: Row(children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppDS.tableBorder),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                clipBehavior: Clip.antiAlias,
                child: NotificationListener<ScrollNotification>(
                  onNotification: (n) {
                    if (n is ScrollUpdateNotification) {
                      if (n.metrics.axis == Axis.horizontal) {
                        _hOffset.value = _hScroll.hasClients ? _hScroll.offset : 0.0;
                      } else if (n.metrics.axis == Axis.vertical)
                        _vOffset.value = _vScroll.hasClients ? _vScroll.offset : 0.0;
                    }
                    return false;
                  },
                  child: SingleChildScrollView(
                    controller: _hScroll,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: totalWidth,
                      child: Column(children: [
                        _buildHeaderRow(cols),
                        Expanded(
                          child: ListView.builder(
                            controller: _vScroll,
                            itemCount: _filtered.length,
                            itemExtent: AppDS.tableRowH,
                            itemBuilder: (ctx, i) {
                              final row = _filtered[i];
                              return _buildDataRow(row, i, cols,
                                  highlight: widget.highlightStrainId != null &&
                                      row['strain_id'] == widget.highlightStrainId);
                            },
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            VerticalThumb(
              contentLength: _filtered.length * AppDS.tableRowH,
              topPadding: AppDS.tableHeaderH,
              offset: _vOffset,
              onScrollTo: (y) {
                final max = _vScroll.hasClients ? _vScroll.position.maxScrollExtent : 0.0;
                final clamped = y.clamp(0.0, max);
                _vScroll.jumpTo(clamped);
                _vOffset.value = clamped;
              },
            ),
          ]),
        ),
        const SizedBox(height: 4),
        HorizontalThumb(
          contentWidth: totalWidth,
          offset: _hOffset,
          onScrollTo: (x) {
            final max = (totalWidth - 400).clamp(0.0, double.infinity);
            _hScroll.jumpTo(x.clamp(0.0, max));
            _hOffset.value = x.clamp(0.0, max);
          },
        ),
        const SizedBox(height: 8),
      ]),
    );
  }

  // ── Header row ────────────────────────────────────────────────────────────
  Widget _buildHeaderRow(List<StrainColDef> cols) {
    final allRowsSel = _filtered.isNotEmpty && _selectedRowIds.length == _filtered.length;
    return Container(
      height: AppDS.tableHeaderH,
      decoration: BoxDecoration(
          color: context.appHeaderBg,
          border: Border(bottom: BorderSide(color: context.appBorder))),
      child: Row(children: [
        if (_selectionMode)
          SizedBox(width: AppDS.tableCheckW, child: Center(child: Checkbox(
            value: allRowsSel ? true : (_selectedRowIds.isEmpty ? false : null),
            tristate: true, onChanged: (_) => _selectAllRows(),
            activeColor: AppDS.accent, checkColor: Colors.white,
            side: BorderSide(color: context.appBorder2, width: 1.5),
          ))),
        SizedBox(width: AppDS.tableOpenW),
        ...List.generate(cols.length, (i) {
          final col = cols[i];
          return Row(mainAxisSize: MainAxisSize.min, children: [
            if (_dropTargetIndex == i)
              Container(width: 2, height: AppDS.tableHeaderH, color: AppDS.blue),
            Opacity(
              opacity: _draggingColKey == col.key ? 0.35 : 1.0,
              child: DraggableHeader(
                col: col, allVisibleCols: cols, colWidthFn: _colWidth,
                onDragStart: () => setState(() { _draggingColKey = col.key; _dropTargetIndex = null; }),
                onDragUpdate: (lx) {
                  double acc = 0; int slot = cols.length;
                  for (int j = 0; j < cols.length; j++) {
                    if (lx < acc + _colWidth(cols[j]) / 2) { slot = j; break; }
                    acc += _colWidth(cols[j]);
                  }
                  if (_dropTargetIndex != slot) setState(() => _dropTargetIndex = slot);
                },
                onDragEnd: () {
                  if (_dropTargetIndex != null && _draggingColKey != null) {
                    _reorderCol(_draggingColKey!, _dropTargetIndex!);
                  } else {
                    setState(() { _draggingColKey = null; _dropTargetIndex = null; });
                  }
                },
                onTapSort: () => _onSort(col.key),
                onTapInSelectionMode: _selectionMode ? () => _toggleColSelection(col.key) : null,
                child: _buildHeaderCell(col,
                    isColSelected: _selectionMode && _selectedColKeys.contains(col.key)),
              ),
            ),
            if (i == cols.length - 1 && _dropTargetIndex == cols.length)
              Container(width: 2, height: AppDS.tableHeaderH, color: AppDS.blue),
          ]);
        }),
      ]),
    );
  }

  Widget _buildHeaderCell(StrainColDef col, {required bool isColSelected}) {
    final sortIndex = _sortKeys.indexOf(col.key);
    final width     = _colWidth(col);
    Color bg = isColSelected ? AppDS.blue800 : Colors.transparent;

    return SizedBox(
      width: width, height: AppDS.tableHeaderH,
      child: Stack(clipBehavior: Clip.none, children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            width: width, height: AppDS.tableHeaderH,
            decoration: BoxDecoration(
                color: bg,
                border: Border(right: BorderSide(color: context.appBorder))),
            padding: const EdgeInsets.only(left: 8, right: 14),
            child: Row(children: [
              if (isColSelected)
                Padding(padding: const EdgeInsets.only(right: 5),
                    child: Icon(Icons.check_box_rounded, size: 11, color: Colors.white.withValues(alpha: 0.85))),
              Expanded(child: Text(col.label,
                  style: AppDS.tableHeaderStyle.copyWith(
                    color: isColSelected ? Colors.white
                        : col.readOnly ? context.appTextMuted
                        : context.appHeaderText),
                  overflow: TextOverflow.ellipsis)),
              if (!_selectionMode)
                if (sortIndex >= 0)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(_sortDirs[col.key] == true
                        ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                        size: 11, color: AppDS.blue),
                    if (_sortKeys.length > 1) ...[
                      const SizedBox(width: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                        decoration: BoxDecoration(color: AppDS.blue,
                            borderRadius: BorderRadius.circular(2)),
                        child: Text('${sortIndex + 1}', style: const TextStyle(
                            fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ]),
            ]),
          ),
        ),
        if (!_selectionMode)
          Positioned(right: -4, top: 0, bottom: 0, width: 8,
              child: ColResizeHandle(
                onDrag: (d) => setState(() =>
                    _colWidths[col.key] = (_colWidth(col) + d).clamp(strainMinColWidth, 600.0)),
                onDragEnd: () => _saveColWidth(col.key, _colWidth(col)),
              )),
      ]),
    );
  }

  // ── Data row ──────────────────────────────────────────────────────────────
  Widget _buildDataRow(Map<String, dynamic> row, int index, List<StrainColDef> cols,
      {bool highlight = false}) {
    final urgency    = calculateStrainUrgency(row);
    final isSelected = _selectedRowIds.contains(row['strain_id']);
    final isDark     = Theme.of(context).brightness == Brightness.dark;
    final baseEven   = context.appSurface;
    final baseOdd    = context.appSurface2;
    final selColor   = isDark ? const Color(0xFF1E3A5F) : AppDS.tableRowSel;
    Color rowBg = isSelected ? selColor
        : highlight ? (isDark ? const Color(0xFF1E3A5F) : const Color(0xFFDEF1FF))
        : urgency == StrainTransferUrgency.overdue ? (isDark ? AppDS.red.withValues(alpha: 0.18) : AppDS.tableRowUrgent)
        : urgency == StrainTransferUrgency.soon    ? (isDark ? AppDS.yellow.withValues(alpha: 0.12) : AppDS.tableRowSoon)
        : index.isEven ? baseEven : baseOdd;
    final cellBase = isSelected ? selColor
        : index.isEven ? baseEven : baseOdd;

    return GestureDetector(
      onTap: _selectionMode ? () => _toggleRowSelection(row['strain_id']) : null,
      child: Container(
        height: AppDS.tableRowH,
        decoration: BoxDecoration(color: rowBg,
            border: Border(bottom: BorderSide(color: context.appBorder, width: 0.5))),
        child: Row(children: [
          if (_selectionMode)
            Container(width: AppDS.tableCheckW, height: AppDS.tableRowH, color: cellBase,
                child: Center(child: Checkbox(
                  value: isSelected, onChanged: (_) => _toggleRowSelection(row['strain_id']),
                  visualDensity: VisualDensity.compact, activeColor: AppDS.blue800,
                ))),
          Container(width: AppDS.tableOpenW, height: AppDS.tableRowH, color: cellBase,
              child: Center(child: IconButton(
                icon: Icon(Icons.launch_rounded, size: 14,
                    color: _selectionMode ? AppDS.textSecondary : AppDS.textSecondary),
                tooltip: 'Open strain', padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: _selectionMode ? null : () => _openDetail(row),
              ))),
          ...cols.map((col) => _buildDataCell(row, col, cellBase)),
        ]),
      ),
    );
  }

  // ── Data cell ─────────────────────────────────────────────────────────────
  Widget _buildDataCell(Map<String, dynamic> row, StrainColDef col, Color cellBase) {
    final isEditing  = _editingCell?['rowId'] == row['strain_id'] && _editingCell?['key'] == col.key;
    final isReadOnly = col.readOnly;
    final isStatus   = col.key == 'strain_status';
    final isComputed = col.key == 'strain_next_transfer' && row['_next_transfer_computed'] == true;

    return GestureDetector(
      onDoubleTap: (_selectionMode || isReadOnly) ? null : () async {
        if (!context.canEditModule) { context.warnReadOnly(); return; }
        if (isStatus) {
          final box = context.findRenderObject() as RenderBox?;
          final pos = box?.localToGlobal(Offset.zero) ?? Offset.zero;
          await _showStatusPicker(row, pos + const Offset(200, 200));
        } else if (col.key == 'strain_last_transfer') {
          await _showTransferDatePicker(row);
        } else {
          setState(() {
            _editingCell = {'rowId': row['strain_id'], 'key': col.key};
            _editController.text = row[col.key]?.toString() ?? '';
          });
        }
      },
      onLongPress: (_selectionMode || isReadOnly || !isStatus) ? null : () async {
        if (!context.canEditModule) { context.warnReadOnly(); return; }
        final box = context.findRenderObject() as RenderBox?;
        final pos = box?.localToGlobal(Offset.zero) ?? Offset.zero;
        await _showStatusPicker(row, pos + const Offset(200, 200));
      },
      child: Container(
        width: _colWidth(col), height: AppDS.tableRowH,
        decoration: BoxDecoration(
            color: cellBase,
            border: Border(right: BorderSide(color: context.appBorder))),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: isEditing
            ? Center(child: TextField(
                controller: _editController, autofocus: true,
                style: TextStyle(fontSize: 12, color: context.appTextPrimary),
                decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: AppDS.blue500, width: 1.5))),
                onSubmitted: (v) => _commitEdit(row, col.key, v),
                onTapOutside: (_) => _commitEdit(row, col.key, _editController.text),
              ))
            : Align(
                alignment: Alignment.centerLeft,
                child: isStatus
                    ? StatusCell(status: row['strain_status']?.toString())
                    : Row(mainAxisSize: MainAxisSize.min, children: [
                        if (isComputed) ...[
                          Tooltip(message: 'Calculated from last transfer + cycle days',
                              child: Icon(Icons.calculate_outlined, size: 11, color: AppDS.blue)),
                          const SizedBox(width: 4),
                        ],
                        Flexible(child: Text(
                          row[col.key]?.toString() ?? '',
                          style: isReadOnly ? TextStyle(fontSize: 12, color: context.appTextMuted)
                              : isComputed  ? const TextStyle(fontSize: 12, color: AppDS.blue500, fontStyle: FontStyle.italic)
                              : TextStyle(fontSize: 12, color: context.appTextPrimary),
                          overflow: TextOverflow.ellipsis)),
                      ]),
              ),
      ),
    );
  }
}