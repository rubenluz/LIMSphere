import 'package:blue_open_lims/functions/printing_strains.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'strain_detail_page.dart';
import '../excel_import_page.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'dart:io';
import 'strains_columns.dart';
import 'strains_design_tokens.dart';

// Design tokens and column definitions are now in separate files
// - strains_design_tokens.dart (StrainsDS, status options, preferences, urgency enum, platform check)
// - strains_columns.dart (StrainColDef, column definitions)


// Column definitions are now in strains_columns.dart


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
  List<Map<String, dynamic>> _rows     = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;

  bool _selectionMode = false;
  final Set<dynamic> _selectedRowIds  = {};
  final Set<String>  _selectedColKeys = {};

  String  _search  = '';
  List<String>      _sortKeys = [];
  Map<String, bool> _sortDirs = {};
  final _searchController = TextEditingController();
  bool _showFilters    = false;
  bool _showColManager = false;
  final List<ActiveFilter> _activeFilters = [];
  List<int> _periodicityOptions = [];
  int?      _selectedPeriodicity;

  String      _kingdomMode  = 'all';
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

  // ── Derived ────────────────────────────────────────────────────────────────
  List<StrainColDef> get _visibleCols {
    final ordered = _colOrder == null
        ? List<StrainColDef>.from(strainAllColumns)
        : [
            ..._colOrder!
                .map((k) {
                  try {
                    return strainAllColumns.firstWhere((c) => c.key == k);
                  } catch (_) {
                    return null;
                  }
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

  // ─────────────────────────────────────────────────────────────────────────
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
    });
  }

  Future<void> _saveSortPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (_sortKeys.isEmpty) {
      await prefs.remove(strainPrefSortKeys);
      await prefs.remove(strainPrefSortDirs);
    } else {
      await prefs.setString(strainPrefSortKeys, _sortKeys.join(','));
      final dirsStr = _sortKeys
          .map((k) => '$k:${_sortDirs[k] == true ? "asc" : "desc"}')
          .join('|');
      await prefs.setString(strainPrefSortDirs, dirsStr);
    }
  }

  Future<void> _saveColWidth(String colKey, double width) async =>
      (await SharedPreferences.getInstance())
          .setDouble('$strainPrefColWidths.$colKey', width);

  Future<void> _resetColWidths() async {
    final prefs = await SharedPreferences.getInstance();
    for (final k in prefs
        .getKeys()
        .where((k) => k.startsWith('$strainPrefColWidths.'))
        .toList()) {
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
    final all = _colOrder ?? strainAllColumns.map((c) => c.key).toList();
    final mutable = List<String>.from(all)..remove(colKey);
    final visible = _visibleCols;
    String? anchorKey;
    if (toVisibleIndex < visible.length) {
      anchorKey = visible[toVisibleIndex].key;
      if (anchorKey == colKey) {
        setState(() {
          _draggingColKey = null;
          _dropTargetIndex = null;
        });
        return;
      }
    }
    if (anchorKey == null) {
      final lv = visible.isNotEmpty ? visible.last.key : null;
      if (lv != null) {
        mutable.insert(
            (mutable.indexOf(lv) + 1).clamp(0, mutable.length), colKey);
      } else {
        mutable.add(colKey);
      }
    } else {
      mutable.insert(
          mutable.indexOf(anchorKey).clamp(0, mutable.length), colKey);
    }
    setState(() {
      _colOrder = mutable;
      _draggingColKey = null;
      _dropTargetIndex = null;
    });
    _saveColOrder();
  }

  // ── Data ──────────────────────────────────────────────────────────────────
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      var q = Supabase.instance.client.from('strains').select('''
        *,
        samples (
          sample_code, sample_rebeca, sample_ccpi, sample_date,
          sample_country, sample_archipelago, sample_island,
          sample_municipality, sample_local,
          sample_habitat_type, sample_habitat_1, sample_habitat_2, sample_habitat_3,
          sample_method, sample_gps,
          sample_temperature, sample_ph, sample_conductivity,
          sample_oxygen, sample_salinity, sample_radiation,
          sample_responsible, sample_observations
        )
      ''');
      if (widget.filterSampleId != null) {
        q = q.eq('strain_sample_code', widget.filterSampleId);
      }
      final res = await q.order('strain_code', ascending: true);

      _rows = (res as List).map((r) {
        final row = Map<String, dynamic>.from(r);
        final s = row['samples'] as Map<String, dynamic>? ?? {};
        // Flatten sample fields into row with s_ prefix (display only)
        for (final k in [
          'rebeca', 'ccpi', 'date', 'country', 'archipelago', 'island',
          'municipality', 'local', 'habitat_type', 'habitat_1', 'habitat_2',
          'habitat_3', 'method', 'gps', 'temperature', 'ph', 'conductivity',
          'oxygen', 'salinity', 'radiation', 'responsible', 'observations',
        ]) {
          row['s_$k'] = s['sample_$k'];
        }
        row.remove('samples');
        _computeNextTransfer(row);
        return row;
      }).toList();

      _detectEmptyCols();
      _buildPeriodicityOptions();
      _applyFilter();
    } catch (e) {
      _snack('Error loading strains: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _computeNextTransfer(Map<String, dynamic> row) {
    final hasNext =
        row['strain_next_transfer']?.toString().isNotEmpty == true;
    final lastStr = row['strain_last_transfer']?.toString() ?? '';
    final days = int.tryParse(row['strain_periodicity']?.toString() ?? '');
    if (!hasNext && lastStr.isNotEmpty && days != null) {
      try {
        final next =
            DateTime.parse(lastStr).add(Duration(days: days));
        row['strain_next_transfer'] =
            '${next.year.toString().padLeft(4, '0')}'
            '-${next.month.toString().padLeft(2, '0')}'
            '-${next.day.toString().padLeft(2, '0')}';
        row['_next_transfer_computed'] = true;
      } catch (_) {}
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
        .map((r) =>
            int.tryParse(r['strain_periodicity']?.toString() ?? ''))
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
      list = list
          .where((r) =>
              r.values.any((v) => v?.toString().toLowerCase().contains(q) == true))
          .toList();
    }
    for (final f in _activeFilters) {
      if (f.value.isEmpty) continue;
      final q = f.value.toLowerCase();
      list = list
          .where((r) =>
              r[f.column]?.toString().toLowerCase().contains(q) == true)
          .toList();
    }
    if (_selectedPeriodicity != null) {
      list = list
          .where((r) =>
              int.tryParse(r['strain_periodicity']?.toString() ?? '') ==
              _selectedPeriodicity)
          .toList();
    }
    _filtered = list;
    _applySort();
  }

  static const _intSortCols = {
    'strain_periodicity',
    'strain_seq_16s_bp', 'strain_seq_18s_bp',
    'strain_its2_bp', 'strain_rbcl_bp',
    'strain_tufa_bp', 'strain_cox1_bp',
    'strain_genome_cont', 'strain_cryo_vials',
  };

  void _applySort() {
    if (_sortKeys.isEmpty) {
      if (mounted) setState(() {});
      return;
    }
    _filtered.sort((a, b) {
      for (final key in _sortKeys) {
        final isInt = _intSortCols.contains(key);
        final isAsc = _sortDirs[key] ?? true;
        late int cmp;
        if (isInt) {
          final ai = int.tryParse(a[key]?.toString() ?? '') ??
              (isAsc ? 999999 : -1);
          final bi = int.tryParse(b[key]?.toString() ?? '') ??
              (isAsc ? 999999 : -1);
          cmp = ai.compareTo(bi);
        } else {
          final av = a[key]?.toString() ?? '';
          final bv = b[key]?.toString() ?? '';
          cmp = av.compareTo(bv);
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
      } else {
        _sortKeys.add(key);
        _sortDirs[key] = true;
      }
    });
    _saveSortPrefs();
    _applySort();
  }

  void _resetSort() {
    setState(() {
      _sortKeys.clear();
      _sortDirs.clear();
    });
    _saveSortPrefs();
    _applySort();
  }

  // ── Edit ──────────────────────────────────────────────────────────────────
  Future<void> _commitEdit(
      Map<String, dynamic> row, String key, String value) async {
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
    } catch (e) {
      _snack('Save error: $e');
    }
    setState(() => _editingCell = null);
  }

  Future<void> _showStatusPicker(
      Map<String, dynamic> row, Offset pos) async {
    final current = row['strain_status']?.toString();
    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx + 1, pos.dy + 1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      items: strainStatusOptions
          .map((s) => PopupMenuItem<String>(
                value: s,
                child: Row(children: [
                  _statusIcon(s, size: 16),
                  const SizedBox(width: 10),
                  Text(s,
                      style: TextStyle(
                          fontWeight: current == s
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: _statusColor(s),
                          fontSize: 13)),
                  if (current == s) ...[
                    const Spacer(),
                    const Icon(Icons.check, size: 14)
                  ],
                ]),
              ))
          .toList(),
    );
    if (result != null && result != current) {
      await _commitEdit(row, 'strain_status', result);
    }
  }

  Future<void> _showTransferDatePicker(Map<String, dynamic> row) async {
    DateTime? selectedDate;
    final currentDateStr = row['strain_last_transfer']?.toString();
    final currentDate = currentDateStr != null
        ? DateTime.tryParse(currentDateStr)
        : DateTime.now();

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDs) => AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: const Color(0xFFBFDBFE))),
                      child: Text(
                          '${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1D4ED8))),
                    ),
                  ],
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Cancel')),
                  FilledButton.icon(
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('This strain'),
                      onPressed: selectedDate != null
                          ? () => Navigator.of(ctx).pop('insert_single')
                          : null),
                  FilledButton.tonal(
                      onPressed: selectedDate != null
                          ? () => Navigator.of(ctx).pop('insert_all')
                          : null,
                      child: const Text('All same cycle')),
                ],
              )),
    );

    if (selectedDate == null || result == null) return;
    final dateStr =
        '${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}';

    if (result == 'insert_single') {
      await _commitEdit(row, 'strain_last_transfer', dateStr);
      if (mounted) _snack('Last transfer updated for ${row['strain_code']}');
    } else {
      final periodicity = row['strain_periodicity'];
      if (periodicity == null || periodicity <= 0) {
        _snack('Cannot use "All same cycle" — strain_periodicity not set');
        return;
      }
      try {
        await Supabase.instance.client
            .from('strains')
            .update({'strain_last_transfer': dateStr})
            .eq('strain_periodicity', periodicity);
        if (mounted) {
          _snack('Updated all strains with $periodicity-day cycle');
          _load();
        }
      } catch (e) {
        if (mounted) _snack('Error: $e');
      }
    }
  }

  void _openDetail(Map<String, dynamic> row) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => StrainDetailPage(
                strainId: row['strain_id'], onSaved: _load)))
        .then((_) => _load());
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))));
  }

  Color _statusColor(String? s) {
    if (s == 'ALIVE')  return StrainsDS.aliveColor;
    if (s == 'DEAD')   return StrainsDS.deadColor;
    if (s == 'INCARE') return StrainsDS.incareColor;
    return Colors.grey;
  }

  Widget _statusIcon(String? s, {double size = 11}) {
    final icon = s == 'ALIVE'
        ? Icons.check_circle_rounded
        : s == 'DEAD'
            ? Icons.cancel_rounded
            : s == 'INCARE'
                ? Icons.medical_services_rounded
                : Icons.help_outline_rounded;
    return Icon(icon, size: size, color: _statusColor(s));
  }

  // ── Selection ─────────────────────────────────────────────────────────────
  void _enterSelectionMode() {
    setState(() {
      _selectionMode = true;
      _selectedRowIds.clear();
      _selectedColKeys
        ..clear()
        ..addAll(_visibleCols.map((c) => c.key));
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedRowIds.clear();
      _selectedColKeys.clear();
    });
  }

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
        final visible = _visibleCols.map((c) => c.key).toSet();
        if (_selectedColKeys.containsAll(visible)) {
          _selectedColKeys.clear();
        } else {
          _selectedColKeys.addAll(visible);
        }
      });

  // ── Export ────────────────────────────────────────────────────────────────
  Future<void> _copySelectedInfo() async {
    final rows = _selectedRows;
    final cols = _exportCols;
    if (rows.isEmpty) {
      _snack('Select at least one row');
      return;
    }
    final buf = StringBuffer()
      ..writeln(cols.map((c) => c.label).join('\t'));
    for (final row in rows) {
      buf.writeln(cols.map((c) => row[c.key]?.toString() ?? '').join('\t'));
    }
    await Clipboard.setData(ClipboardData(text: buf.toString()));
    _snack('Copied ${rows.length} row(s) × ${cols.length} col(s)');
  }

  Future<void> _exportSelectedToExcel() async {
    final rows = _selectedRows;
    final cols = _exportCols;
    if (rows.isEmpty) {
      _snack('Select at least one row');
      return;
    }
    final excel = Excel.createExcel();
    final sheet = excel['Sheet1'];
    for (int c = 0; c < cols.length; c++) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0))
          .value = TextCellValue(cols[c].label);
    }
    for (int r = 0; r < rows.length; r++) {
      for (int c = 0; c < cols.length; c++) {
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1))
            .value = _toCellValue(rows[r][cols[c].key]);
      }
    }
    final dir = await getTemporaryDirectory();
    final safeDate = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
    final filePath = '${dir.path}\\strains_export_$safeDate.xlsx';
    final fileBytes = excel.encode();

    File(filePath)
      ..createSync(recursive: true)
      ..writeAsBytesSync(fileBytes!);
        await OpenFilex.open(filePath);
        _snack('Excel exported (${rows.length} rows)');
    }

  Future<void> _printStrains() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PrintStrainsPage(),
      ),
    );
  }

  CellValue _toCellValue(dynamic value) {
    if (value == null) return TextCellValue('');
    if (value is int) return IntCellValue(value);
    if (value is double) return DoubleCellValue(value);
    if (value is bool) return BoolCellValue(value);
    if (value is DateTime) {
      return DateCellValue(
          year: value.year, month: value.month, day: value.day);
    }
    return TextCellValue(value.toString());
  }

  Future<void> _showAddStrainDialog({dynamic preselectedSampleId}) async {
    List<Map<String, dynamic>> samples = [];
    try {
      samples = List<Map<String, dynamic>>.from(await Supabase.instance.client
          .from('samples')
          .select('sample_id, sample_rebeca, sample_ccpi, sample_number')
          .order('sample_number'));
    } catch (e) {
      _snack('Could not load samples: $e');
      return;
    }
    if (!mounted) return;
    dynamic selId = preselectedSampleId;
    final codeCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDs) => AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                title: const Text('New Strain'),
                content: SizedBox(
                    width: 360,
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('A strain must originate from a sample.',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600)),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<dynamic>(
                            initialValue: selId,
                            decoration: const InputDecoration(
                                labelText: 'Source Sample *',
                                border: OutlineInputBorder(),
                                isDense: true),
                            items: samples.map((s) {
                              final lbl = [
                                s['sample_code']?.toString()
                              ]
                                  .where((v) => v != null && v.isNotEmpty)
                                  .join(' — ');
                              return DropdownMenuItem(
                                  value: s['sample_id'],
                                  child: Text(lbl,
                                      overflow: TextOverflow.ellipsis));
                            }).toList(),
                            onChanged: (v) => setDs(() => selId = v),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                              controller: codeCtrl,
                              decoration: const InputDecoration(
                                  labelText: 'Strain Code',
                                  border: OutlineInputBorder(),
                                  isDense: true)),
                        ])),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: selId == null
                          ? null
                          : () => Navigator.pop(ctx, true),
                      child: const Text('Create')),
                ],
              )),
    );
    if (ok != true || selId == null) return;
    try {
      final res = await Supabase.instance.client
          .from('strains')
          .insert({
            'strain_sample_code': selId,
            'strain_code': codeCtrl.text.isEmpty ? null : codeCtrl.text,
          })
          .select()
          .single();
      if (mounted) {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => StrainDetailPage(
                    strainId: res['strain_code'], onSaved: _load)))
            .then((_) => _load());
      }
    } catch (e) {
      _snack('Error creating strain: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final desktop = isDesktopPlatform(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      resizeToAvoidBottomInset: false,
      appBar: _selectionMode
          ? _buildSelectionAppBar(desktop)
          : _buildNormalAppBar(desktop),
      body: Column(children: [
        _buildToolbar(desktop),
        if (_showFilters)    _buildFilterPanel(),
        if (_showColManager) _buildColumnManager(),
        if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else
          Expanded(child: _buildGrid()),
      ]),
    );
  }

  // ── Normal AppBar ─────────────────────────────────────────────────────────
  PreferredSizeWidget _buildNormalAppBar(bool desktop) {
    Widget btn({required IconData icon, required String tooltip, required String label, required VoidCallback onPressed}) {
      if (desktop) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: TextButton.icon(
            icon: Icon(icon, size: 16, color: Colors.white70),
            label: Text(label,
                style: const TextStyle(fontSize: 12, color: Colors.white70)),
            onPressed: onPressed,
            style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
          ),
        );
      }
      return IconButton(
          icon: Icon(icon, size: 20, color: Colors.white70),
          tooltip: tooltip,
          onPressed: onPressed,
          padding: const EdgeInsets.all(8),
          constraints:
              const BoxConstraints(minWidth: 36, minHeight: 36));
    }

    return AppBar(
      backgroundColor: StrainsDS.headerBg,
      foregroundColor: Colors.white,
      elevation: 0,
      title: Row(children: [
        const Icon(Icons.science_rounded, size: 20, color: Colors.white70),
        const SizedBox(width: 8),
        Text(
            widget.filterSampleId != null
                ? 'Strains — Sample ${widget.filterSampleId}'
                : 'Strains',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
      ]),
      actions: [
  btn(icon: Icons.refresh_rounded,    tooltip: 'Refresh', label: 'Refresh', onPressed: _load),  
  btn(icon: Icons.checklist_rounded,  tooltip: 'Select rows & columns', label: 'Select', onPressed: _enterSelectionMode),

  btn(icon: Icons.print_outlined,     tooltip: 'Print',   label: 'Print',   onPressed: _printStrains),

  btn(icon: Icons.view_column_outlined, tooltip: 'Manage columns', label: 'Columns', onPressed: () => setState(() => _showColManager = !_showColManager)),
    btn(icon: Icons.upload_file_rounded,tooltip: 'Import from Excel', label: 'Import', onPressed: () async {
    final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const ExcelImportPage(mode: 'strains')));
    if (ok == true) _load();
  }),
  const SizedBox(width: 4),
],
    );
  }

  // ── Selection AppBar ──────────────────────────────────────────────────────
  PreferredSizeWidget _buildSelectionAppBar(bool desktop) {
    final rowCount   = _selectedRowIds.length;
    final colCount   = _selectedColKeys.length;
    final allRowsSel = _selectedRowIds.length == _filtered.length;
    final allColsSel = _selectedColKeys.length == _visibleCols.length;

    Widget selBtn({required IconData icon, required String tooltip, required String label, required VoidCallback fn}) {
      if (desktop) {
        return TextButton.icon(
          icon: Icon(icon, size: 16),
          label: Text(label, style: const TextStyle(fontSize: 12)),
          onPressed: fn,
          style: TextButton.styleFrom(
              foregroundColor: Colors.white70,
              padding:
                  const EdgeInsets.symmetric(horizontal: 8)),
        );
      }
      return IconButton(
          icon: Icon(icon, size: 20),
          tooltip: tooltip,
          onPressed: fn,
          color: Colors.white70);
    }

    return AppBar(
      backgroundColor: const Color(0xFF1E3A5F),
      foregroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Exit selection',
          onPressed: _exitSelectionMode),
      title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                '$rowCount row${rowCount != 1 ? 's' : ''} · $colCount col${colCount != 1 ? 's' : ''}',
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 15)),
            Text('Tap rows to select · tap column headers to pick columns',
                style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withOpacity(0.55))),
          ]),
      actions: [
        selBtn(
            icon: allRowsSel ? Icons.deselect : Icons.select_all,
            tooltip:
                allRowsSel ? 'Deselect all rows' : 'Select all rows',
            label: allRowsSel ? 'All rows ✓' : 'All rows',
            fn: _selectAllRows),
        selBtn(
            icon: allColsSel
                ? Icons.view_column
                : Icons.view_column_outlined,
            tooltip:
                allColsSel ? 'Deselect all cols' : 'Select all cols',
            label: allColsSel ? 'All cols ✓' : 'All cols',
            fn: _selectAllCols),
        Center(
            child: Container(
                width: 1,
                height: 22,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                color: Colors.white24)),
        selBtn(
            icon: Icons.copy_rounded,
            tooltip: 'Copy to Clipboard',
            label: 'Copy to Clipboard',
            fn: _copySelectedInfo),
        selBtn(
            icon: Icons.grid_on_rounded,
            tooltip: 'Export to Excel',
            label: 'Export to Excel',
            fn: _exportSelectedToExcel),
        const SizedBox(width: 4),
      ],
    );
  }

  // ── Toolbar ───────────────────────────────────────────────────────────────
  Widget _buildToolbar(bool desktop) {
    final hasActive = _activeFilters.any((f) => f.value.isNotEmpty) ||
        _selectedPeriodicity != null;
    final hasSort = _sortKeys.isNotEmpty;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search strains…',
              hintStyle: TextStyle(
                  color: Colors.grey.shade400, fontSize: 13),
              prefixIcon: Icon(Icons.search_rounded,
                  color: Colors.grey.shade400, size: 18),
              suffixIcon: _search.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _search = '');
                        _applyFilter();
                      })
                  : null,
              isDense: true,
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: Color(0xFFE2E8F0))),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: Color(0xFFE2E8F0))),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                      color: Color(0xFF3B82F6), width: 1.5)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            ),
            style: const TextStyle(fontSize: 13),
            onChanged: (v) {
              setState(() => _search = v);
              _applyFilter();
            },
          )),
          const SizedBox(width: 8),
          _ToolbarChip(
              label: 'Filters',
              icon: Icons.tune_rounded,
              selected: _showFilters,
              onTap: () =>
                  setState(() => _showFilters = !_showFilters)),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6)),
            child: Text('${_filtered.length} / ${_rows.length}',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B))),
          ),
        ]),
        if (hasSort) ...[
          const SizedBox(height: 8),
          SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                Text('Sort:',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w600)),
                const SizedBox(width: 6),
                ..._sortKeys.asMap().entries.map((e) => Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: InputChip(
                      label: Text(
                          '${e.value} ${_sortDirs[e.value] == true ? "↑" : "↓"}',
                          style: const TextStyle(fontSize: 11)),
                      selected: true,
                      onDeleted: () {
                        setState(() {
                          _sortKeys.removeAt(e.key);
                          _sortDirs.remove(e.value);
                        });
                        _saveSortPrefs();
                        _applySort();
                      },
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6)),
                    ))),
                TextButton.icon(
                    icon: const Icon(Icons.clear, size: 13),
                    label: const Text('Clear sorts',
                        style: TextStyle(fontSize: 12)),
                    onPressed: _resetSort),
              ])),
        ],
        if (hasActive) ...[
          const SizedBox(height: 8),
          SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                ..._activeFilters.map((f) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InputChip(
                      label: Text(
                          '${f.label}: ${f.value.isEmpty ? "…" : f.value}',
                          style: const TextStyle(fontSize: 11)),
                      selected: f.value.isNotEmpty,
                      onDeleted: () {
                        setState(() => _activeFilters.remove(f));
                        _applyFilter();
                      },
                      onPressed: () => _editFilterValue(f),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6)),
                    ))),
                if (_selectedPeriodicity != null)
                  Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InputChip(
                        label: Text('Cycle: ${_selectedPeriodicity}d',
                            style: const TextStyle(fontSize: 11)),
                        selected: true,
                        onDeleted: () {
                          setState(() => _selectedPeriodicity = null);
                          _applyFilter();
                        },
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)),
                      )),
                TextButton.icon(
                    icon: const Icon(Icons.clear, size: 13),
                    label: const Text('Clear all',
                        style: TextStyle(fontSize: 12)),
                    onPressed: () {
                      setState(() {
                        _activeFilters.clear();
                        _selectedPeriodicity = null;
                      });
                      _applyFilter();
                    }),
              ])),
        ],
        const SizedBox(height: 8),
        SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              Text('Cycle:',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w600)),
              const SizedBox(width: 6),
              if (_periodicityOptions.isEmpty)
                Text('no data',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade400))
              else
                ..._periodicityOptions.map((d) => Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: _ToolbarChip(
                        label: '${d}d',
                        selected: _selectedPeriodicity == d,
                        compact: true,
                        onTap: () {
                          setState(() => _selectedPeriodicity =
                              _selectedPeriodicity == d ? null : d);
                          _applyFilter();
                        }))),
            ])),
      ]),
    );
  }

  void _editFilterValue(ActiveFilter f) async {
    final ctrl = TextEditingController(text: f.value);
    await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              title: Text('Filter: ${f.label}'),
              contentPadding:
                  const EdgeInsets.fromLTRB(24, 12, 24, 0),
              content: TextField(
                  controller: ctrl,
                  autofocus: true,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                      hintText: 'Type to filter…',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      isDense: true),
                  onSubmitted: (_) => Navigator.pop(ctx)),
              actions: [
                TextButton(
                    onPressed: () {
                      ctrl.clear();
                      Navigator.pop(ctx);
                    },
                    child: const Text('Clear')),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Apply')),
              ],
            ));
    setState(() => f.value = ctrl.text);
    _applyFilter();
  }

  // ── Filter panel ──────────────────────────────────────────────────────────
  Widget _buildFilterPanel() {
    final filterableCols =
        strainAllColumns.where((c) => !c.readOnly).toList();
    String? pickedColKey;
    return StatefulBuilder(
        builder: (ctx, setPanel) => Container(
              decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  border: Border(
                      bottom: BorderSide(color: Colors.grey.shade200),
                      top: BorderSide(color: Colors.grey.shade200))),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.tune_rounded,
                          size: 15,
                          color:
                              Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 6),
                      Text('Advanced Filters',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary)),
                      const Spacer(),
                      _KingdomSelector(
                          value: _kingdomMode,
                          onChanged: (v) =>
                              setState(() => _kingdomMode = v)),
                      const SizedBox(width: 12),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Text('Hide empty',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600)),
                        Transform.scale(
                            scale: 0.75,
                            child: Switch(
                              value: _emptyColKeys.isNotEmpty,
                              onChanged: (v) {
                                if (v) {
                                  _detectEmptyCols();
                                  setState(() {});
                                } else {
                                  setState(() => _emptyColKeys = {});
                                }
                              },
                            )),
                      ]),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                          child: DropdownButtonFormField<String>(
                        initialValue: pickedColKey,
                        isExpanded: true,
                        isDense: true,
                        decoration: InputDecoration(
                            labelText: 'Add filter by column…',
                            border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(8)),
                            contentPadding:
                                const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8)),
                        items: filterableCols
                            .map((col) => DropdownMenuItem(
                                value: col.key,
                                child: Text(col.label,
                                    style: const TextStyle(
                                        fontSize: 12))))
                            .toList(),
                        onChanged: (v) =>
                            setPanel(() => pickedColKey = v),
                      )),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                          icon: const Icon(Icons.add, size: 15),
                          label: const Text('Add'),
                          onPressed: pickedColKey == null
                              ? null
                              : () {
                                  final col = strainAllColumns.firstWhere(
                                      (c) => c.key == pickedColKey);
                                  if (_activeFilters.any(
                                      (f) =>
                                          f.column == pickedColKey)) {
                                    return;
                                  }
                                  final filter = ActiveFilter(
                                      col.key, col.label, '');
                                  setState(
                                      () => _activeFilters.add(filter));
                                  setPanel(() => pickedColKey = null);
                                  _editFilterValue(filter);
                                }),
                    ]),
                    if (_activeFilters.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ..._activeFilters.map((f) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(children: [
                            Expanded(
                                child: TextField(
                              controller: TextEditingController(
                                  text: f.value)
                                ..selection = TextSelection.fromPosition(
                                    TextPosition(
                                        offset: f.value.length)),
                              decoration: InputDecoration(
                                  labelText: f.label,
                                  isDense: true,
                                  border: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(8)),
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 8),
                                  suffixIcon: f.value.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(
                                              Icons.clear,
                                              size: 15),
                                          onPressed: () {
                                            setState(
                                                () => f.value = '');
                                            _applyFilter();
                                          })
                                      : null),
                              style: const TextStyle(fontSize: 13),
                              onChanged: (v) {
                                f.value = v;
                                _applyFilter();
                              },
                            )),
                            IconButton(
                                icon: const Icon(
                                    Icons.delete_outline,
                                    size: 17,
                                    color: Colors.red),
                                onPressed: () {
                                  setState(() =>
                                      _activeFilters.remove(f));
                                  _applyFilter();
                                }),
                          ]))),
                    ],
                  ]),
            ));
  }

  // ── Column manager ────────────────────────────────────────────────────────
  Widget _buildColumnManager() {
  // Build a full ordered list of all columns with their current visibility and width
  final orderedKeys = _colOrder ?? strainAllColumns.map((c) => c.key).toList();

  return Container(
    constraints: const BoxConstraints(maxHeight: 420),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 3))
      ],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header bar
        Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(children: [
            const Icon(Icons.view_column_outlined, size: 16, color: Color(0xFF3B82F6)),
            const SizedBox(width: 8),
            const Text('Column Manager',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF1E293B))),
            const Spacer(),
            // Reset all button
            TextButton.icon(
              icon: const Icon(Icons.restart_alt_rounded, size: 14),
              label: const Text('Reset all', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(foregroundColor: Colors.red.shade400,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
              onPressed: () async {
                await _resetColWidths();
                await _resetColOrder();
                setState(() => _hiddenCols = {});
                _snack('All column settings reset');
              },
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.close, size: 17),
              onPressed: () => setState(() => _showColManager = false),
              tooltip: 'Close',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            ),
          ]),
        ),
        // Column header labels
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          color: const Color(0xFFF1F5F9),
          child: Row(children: [
            const SizedBox(width: 36, child: Text('#', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8)))),
            const SizedBox(width: 8),
            const Expanded(child: Text('Column', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8)))),
            const SizedBox(width: 80, child: Text('Width', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8)))),
            const SizedBox(width: 44, child: Center(child: Text('Show', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8))))),
          ]),
        ),
        // Scrollable column list
        Flexible(
          child: StatefulBuilder(
            builder: (ctx, setPanel) {
              // Rebuild ordered list from current state
              final orderedKeys2 = _colOrder ?? strainAllColumns.map((c) => c.key).toList();
              final displayKeys = [
                ...orderedKeys2,
                ...strainAllColumns.map((c) => c.key).where((k) => !orderedKeys2.contains(k)),
              ];

              return ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: displayKeys.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade100),
                itemBuilder: (ctx, i) {
                  final key = displayKeys[i];
                  StrainColDef? colDef;
                  try { colDef = strainAllColumns.firstWhere((c) => c.key == key); } catch (_) { return const SizedBox.shrink(); }

                  final isHidden = _hiddenCols.contains(key) || _emptyColKeys.contains(key);
                  final currentWidth = _colWidths[key] ?? colDef!.defaultWidth;
                  final position = i + 1; // 1-based

                  return Container(
                    color: isHidden ? const Color(0xFFFAFAFA) : Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    child: Row(children: [
                      // Position number input
                      SizedBox(
                        width: 36,
                        child: _ColPositionField(
                          position: position,
                          total: displayKeys.length,
                          onSubmit: (newPos) {
                            final clamped = newPos.clamp(1, displayKeys.length);
                            if (clamped == position) return;
                            // Build new order
                            final mutable = List<String>.from(displayKeys)..remove(key);
                            mutable.insert(clamped - 1, key);
                            setState(() => _colOrder = mutable);
                            _saveColOrder();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Column label
                      Expanded(
                        child: Row(children: [
                          if (colDef!.readOnly)
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Icon(Icons.lock_outline_rounded, size: 10, color: Colors.grey.shade400),
                            ),
                          Flexible(
                            child: Text(colDef!.label,
                              style: TextStyle(
                                fontSize: 12,
                                color: isHidden ? Colors.grey.shade400 : const Color(0xFF334155),
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis),
                          ),
                        ]),
                      ),
                      // Width slider
                      SizedBox(
                        width: 80,
                        child: isHidden
                          ? Center(child: Text('—', style: TextStyle(color: Colors.grey.shade300, fontSize: 12)))
                          : SliderTheme(
                              data: SliderThemeData(
                                trackHeight: 2,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                                activeTrackColor: const Color(0xFF3B82F6),
                                inactiveTrackColor: const Color(0xFFE2E8F0),
                                thumbColor: const Color(0xFF3B82F6),
                              ),
                              child: Slider(
                                value: currentWidth.clamp(40.0, 400.0),
                                min: 40,
                                max: 400,
                                onChanged: (v) {
                                  setState(() => _colWidths[key] = v);
                                  setPanel(() {});
                                },
                                onChangeEnd: (v) => _saveColWidth(key, v),
                              ),
                            ),
                      ),
                      // Show/hide toggle
                      SizedBox(
                        width: 44,
                        child: _emptyColKeys.contains(key)
                          ? Center(child: Tooltip(
                              message: 'No data in this column',
                              child: Icon(Icons.remove_circle_outline, size: 14, color: Colors.grey.shade300)))
                          : Transform.scale(
                              scale: 0.8,
                              child: Switch(
                                value: !_hiddenCols.contains(key),
                                onChanged: (v) {
                                  setState(() {
                                    if (v) _hiddenCols.remove(key);
                                    else   _hiddenCols.add(key);
                                  });
                                  setPanel(() {});
                                },
                                activeColor: const Color(0xFF3B82F6),
                              ),
                            ),
                      ),
                    ]),
                  );
                },
              );
            },
          ),
        ),
      ],
    ),
  );
  
}

  // ── Grid ──────────────────────────────────────────────────────────────────
  Widget _buildGrid() {
    if (_filtered.isEmpty) {
      return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.science_outlined,
            size: 56, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        Text('No strains found',
            style:
                TextStyle(color: Colors.grey.shade500, fontSize: 15)),
        const SizedBox(height: 16),
        FilledButton.icon(
            onPressed: () => _showAddStrainDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Add First Strain'),
            style:
                FilledButton.styleFrom(backgroundColor: StrainsDS.headerBg)),
      ]));
    }

    final cols = _visibleCols;
    final totalWidth = (_selectionMode ? StrainsDS.checkW : 0.0) +
        StrainsDS.openW +
        cols.fold(0.0, (s, c) => s + _colWidth(c));

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: Column(children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n is ScrollUpdateNotification &&
                    n.metrics.axis == Axis.horizontal) {
                  _hOffset.value =
                      _hScroll.hasClients ? _hScroll.offset : 0.0;
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
                        itemExtent: StrainsDS.rowH,
                        itemBuilder: (ctx, i) {
                          final row = _filtered[i];
                          return _buildDataRow(row, i, cols,
                              highlight: widget.highlightStrainId !=
                                      null &&
                                  row['strain_id'] ==
                                      widget.highlightStrainId);
                        },
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        _HorizontalThumb(
          contentWidth: totalWidth,
          offset: _hOffset,
          onScrollTo: (x) {
            final max = (totalWidth - 400).clamp(0.0, double.infinity);
            final clamped = x.clamp(0.0, max);
            _hScroll.jumpTo(clamped);
            _hOffset.value = clamped;
          },
        ),
        const SizedBox(height: 8),
      ]),
    );
  }

  // ── Header row ────────────────────────────────────────────────────────────
  Widget _buildHeaderRow(List<StrainColDef> cols) {
    final allRowsSel =
        _filtered.isNotEmpty &&
        _selectedRowIds.length == _filtered.length;
    return Container(
      height: StrainsDS.headerH,
      decoration: const BoxDecoration(
          color: StrainsDS.headerBg,
          border: Border(
              bottom: BorderSide(color: StrainsDS.headerBorder))),
      child: Row(children: [
        if (_selectionMode)
          SizedBox(
              width: StrainsDS.checkW,
              child: Center(
                  child: Checkbox(
                value: allRowsSel
                    ? true
                    : (_selectedRowIds.isEmpty ? false : null),
                tristate: true,
                onChanged: (_) => _selectAllRows(),
                activeColor: Colors.white,
                checkColor: StrainsDS.headerBg,
                side: const BorderSide(
                    color: Colors.white38, width: 1.5),
              ))),
        SizedBox(
            width: StrainsDS.openW,
            child: Center(
                child: Icon(Icons.launch_rounded,
                    size: 13, color: Colors.white30))),
        ...List.generate(cols.length, (i) {
          final col      = cols[i];
          final isDrag   = _draggingColKey == col.key;
          final showDrop = _dropTargetIndex == i;
          final isColSel = _selectionMode &&
              _selectedColKeys.contains(col.key);
          return Row(mainAxisSize: MainAxisSize.min, children: [
            if (showDrop)
              Container(
                  width: 2,
                  height: StrainsDS.headerH,
                  color: const Color(0xFF60A5FA)),
            Opacity(
              opacity: isDrag ? 0.35 : 1.0,
              child: _DraggableHeader(
                col: col,
                allVisibleCols: cols,
                colWidthFn: _colWidth,
                onDragStart: () => setState(() {
                  _draggingColKey = col.key;
                  _dropTargetIndex = null;
                }),
                onDragUpdate: (localX) {
                  double accum = 0;
                  int slot = cols.length;
                  for (int j = 0; j < cols.length; j++) {
                    if (localX < accum + _colWidth(cols[j]) / 2) {
                      slot = j;
                      break;
                    }
                    accum += _colWidth(cols[j]);
                  }
                  if (_dropTargetIndex != slot) {
                    setState(() => _dropTargetIndex = slot);
                  }
                },
                onDragEnd: () {
                  if (_dropTargetIndex != null &&
                      _draggingColKey != null) {
                    _reorderCol(
                        _draggingColKey!, _dropTargetIndex!);
                  } else {
                    setState(() {
                      _draggingColKey = null;
                      _dropTargetIndex = null;
                    });
                  }
                },
                onTapSort: () => _onSort(col.key),
                onTapInSelectionMode: _selectionMode
                    ? () => _toggleColSelection(col.key)
                    : null,
                child: _buildHeaderCell(col,
                    isColSelected: isColSel),
              ),
            ),
            if (i == cols.length - 1 &&
                _dropTargetIndex == cols.length)
              Container(
                  width: 2,
                  height: StrainsDS.headerH,
                  color: const Color(0xFF60A5FA)),
          ]);
        }),
      ]),
    );
  }

  Widget _buildHeaderCell(StrainColDef col,
      {required bool isColSelected}) {
    final sortIndex = _sortKeys.indexOf(col.key);
    final isSorted  = sortIndex >= 0;
    final blocked   = col.onlyFor != null &&
        _kingdomMode != 'all' &&
        !col.onlyFor!.contains(_kingdomMode);
    final width = _colWidth(col);

    Color bgColor =
        blocked ? const Color(0xFF374151) : Colors.transparent;
    if (isColSelected) bgColor = const Color(0xFF1E40AF);

    return SizedBox(
      width: width,
      height: StrainsDS.headerH,
      child: Stack(clipBehavior: Clip.none, children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            width: width,
            height: StrainsDS.headerH,
            decoration: BoxDecoration(
              color: bgColor,
              border: const Border(
                  right: BorderSide(color: StrainsDS.headerBorder)),
            ),
            padding: const EdgeInsets.only(left: 8, right: 14),
            child: Row(children: [
              if (isColSelected)
                Padding(
                    padding: const EdgeInsets.only(right: 5),
                    child: Icon(Icons.check_box_rounded,
                        size: 11,
                        color: Colors.white.withOpacity(0.85))),
              Expanded(
                  child: Text(col.label,
                      style: StrainsDS.headerStyle.copyWith(
                        color: blocked
                            ? Colors.white24
                            : isColSelected
                                ? Colors.white
                                : col.readOnly
                                    ? Colors.white38
                                    : StrainsDS.headerText,
                      ),
                      overflow: TextOverflow.ellipsis)),
              if (!_selectionMode)
                if (blocked)
                  const Icon(Icons.block,
                      size: 9, color: Colors.white24)
                else if (isSorted)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(
                        _sortDirs[col.key] == true
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        size: 11,
                        color: const Color(0xFF60A5FA)),
                    if (_sortKeys.length > 1) ...[
                      const SizedBox(width: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 3, vertical: 1),
                        decoration: BoxDecoration(
                            color: const Color(0xFF60A5FA),
                            borderRadius:
                                BorderRadius.circular(2)),
                        child: Text('${sortIndex + 1}',
                            style: const TextStyle(
                                fontSize: 9,
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                      )
                    ]
                  ]),
            ]),
          ),
        ),
        if (!_selectionMode)
          Positioned(
              right: -4,
              top: 0,
              bottom: 0,
              width: 8,
              child: _ColResizeHandle(
                onDrag: (d) => setState(() {
                  _colWidths[col.key] =
                      (_colWidth(col) + d).clamp(strainMinColWidth, 600.0);
                }),
                onDragEnd: () =>
                    _saveColWidth(col.key, _colWidth(col)),
              )),
      ]),
    );
  }

  // ── Data row ──────────────────────────────────────────────────────────────
  Widget _buildDataRow(Map<String, dynamic> row, int index,
      List<StrainColDef> cols,
      {bool highlight = false}) {
    final urgency = calculateStrainUrgency(row);
    final isSelected = _selectedRowIds.contains(row['strain_id']);

    Color rowBg;
    if (isSelected)                           rowBg = StrainsDS.selectedBg;
    else if (highlight)                       rowBg = const Color(0xFFDEF1FF);
    else if (urgency == StrainTransferUrgency.overdue) rowBg = StrainsDS.overdueRowBg;
    else if (urgency == StrainTransferUrgency.soon)    rowBg = StrainsDS.soonRowBg;
    else if (index.isEven)                   rowBg = StrainsDS.rowEven;
    else                                     rowBg = StrainsDS.rowOdd;

    final Color cellBase = isSelected
        ? StrainsDS.selectedBg
        : index.isEven
            ? StrainsDS.rowEven
            : StrainsDS.rowOdd;

    return GestureDetector(
      onTap:
          _selectionMode ? () => _toggleRowSelection(row['strain_id']) : null,
      child: Container(
        height: StrainsDS.rowH,
        decoration: BoxDecoration(
          color: rowBg,
          border: const Border(
              bottom:
                  BorderSide(color: Color(0xFFE2E8F0), width: 0.5)),
        ),
        child: Row(children: [
          if (_selectionMode)
            Container(
              width: StrainsDS.checkW,
              height: StrainsDS.rowH,
              color: cellBase,
              child: Center(
                  child: Checkbox(
                value: isSelected,
                onChanged: (_) =>
                    _toggleRowSelection(row['strain_id']),
                visualDensity: VisualDensity.compact,
                activeColor: const Color(0xFF1E40AF),
              )),
            ),
          Container(
            width: StrainsDS.openW,
            height: StrainsDS.rowH,
            color: cellBase,
            child: Center(
                child: IconButton(
              icon: Icon(Icons.launch_rounded,
                  size: 14,
                  color: _selectionMode
                      ? Colors.grey.shade400
                      : const Color(0xFF94A3B8)),
              tooltip: 'Open strain',
              padding: EdgeInsets.zero,
              constraints:
                  const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed:
                  _selectionMode ? null : () => _openDetail(row),
            )),
          ),
          ...cols.map((col) => _buildDataCell(row, col, cellBase)),
        ]),
      ),
    );
  }

  // ── Data cell ─────────────────────────────────────────────────────────────
  Widget _buildDataCell(Map<String, dynamic> row, StrainColDef col,
      Color cellBase) {
    final isEditing = _editingCell?['rowId'] == row['strain_id'] &&
        _editingCell?['key'] == col.key;
    final isReadOnly = col.readOnly;
    final isStatus   = col.key == 'strain_status';
    final blocked    = col.onlyFor != null &&
        _kingdomMode != 'all' &&
        !col.onlyFor!.contains(_kingdomMode);
    final width = _colWidth(col);
    final isComputed = col.key == 'strain_next_transfer' &&
        row['_next_transfer_computed'] == true;

    Color cellBg = blocked ? StrainsDS.blockedBg : cellBase;

    return GestureDetector(
      onDoubleTap:
          (_selectionMode || isReadOnly || blocked) ? null : () async {
            if (isStatus) {
              final box =
                  context.findRenderObject() as RenderBox?;
              final pos = box?.localToGlobal(Offset.zero) ??
                  Offset.zero;
              await _showStatusPicker(
                  row, pos + const Offset(200, 200));
            } else if (col.key == 'strain_last_transfer') {
              await _showTransferDatePicker(row);
            } else {
              setState(() {
                _editingCell = {
                  'rowId': row['strain_id'],
                  'key': col.key
                };
                _editController.text =
                    row[col.key]?.toString() ?? '';
              });
            }
          },
      onLongPress:
          (_selectionMode || isReadOnly || blocked || !isStatus)
              ? null
              : () async {
                  final box =
                      context.findRenderObject() as RenderBox?;
                  final pos =
                      box?.localToGlobal(Offset.zero) ??
                          Offset.zero;
                  await _showStatusPicker(
                      row, pos + const Offset(200, 200));
                },
      child: Container(
        width: width,
        height: StrainsDS.rowH,
        decoration: BoxDecoration(
            color: cellBg,
            border: const Border(
                right: BorderSide(color: StrainsDS.cellBorder))),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: isEditing
            ? Center(
                child: TextField(
                  controller: _editController,
                  autofocus: true,
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                      isDense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 4),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(
                              color: Color(0xFF3B82F6),
                              width: 1.5))),
                  onSubmitted: (v) =>
                      _commitEdit(row, col.key, v),
                  onTapOutside: (_) =>
                      _commitEdit(
                          row, col.key, _editController.text),
                ))
            : Align(
                alignment: Alignment.centerLeft,
                child: isStatus && !blocked
                    ? _StatusCell(status: row['strain_status']?.toString())
                    : Row(mainAxisSize: MainAxisSize.min, children: [
                        if (isComputed) ...[
                          Tooltip(
                              message:
                                  'Calculated from last transfer + cycle days',
                              child: Icon(Icons.calculate_outlined,
                                  size: 11,
                                  color: const Color(0xFF60A5FA))),
                          const SizedBox(width: 4),
                        ],
                        Flexible(
                            child: Text(
                          blocked
                              ? '—'
                              : (row[col.key]?.toString() ?? ''),
                          style: blocked
                              ? StrainsDS.cellStyle.copyWith(
                                  color: StrainsDS.blockedText
                                      .withOpacity(0.4))
                              : isReadOnly
                                  ? StrainsDS.readOnlyStyle
                                  : isComputed
                                      ? StrainsDS.cellStyle.copyWith(
                                          color:
                                              const Color(0xFF3B82F6),
                                          fontStyle: FontStyle.italic)
                                      : StrainsDS.cellStyle,
                          overflow: TextOverflow.ellipsis,
                        )),
                      ]),
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Status cell
// ─────────────────────────────────────────────────────────────────────────────
class _StatusCell extends StatelessWidget {
  final String? status;
  const _StatusCell({this.status});

  Color get _color {
    if (status == 'ALIVE')  return StrainsDS.aliveColor;
    if (status == 'DEAD')   return StrainsDS.deadColor;
    if (status == 'INCARE') return StrainsDS.incareColor;
    return Colors.grey;
  }

  IconData get _icon {
    if (status == 'ALIVE')  return Icons.check_circle_rounded;
    if (status == 'DEAD')   return Icons.cancel_rounded;
    if (status == 'INCARE') return Icons.medical_services_rounded;
    return Icons.help_outline_rounded;
  }

  @override
  Widget build(BuildContext context) {
    if (status == null || status!.isEmpty) return const SizedBox.shrink();
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(_icon, size: 11, color: _color),
      const SizedBox(width: 5),
      Flexible(
          child: Text(status!,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _color),
              overflow: TextOverflow.ellipsis)),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Toolbar chip
// ─────────────────────────────────────────────────────────────────────────────
class _ToolbarChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;
  const _ToolbarChip(
      {required this.label,
      required this.selected,
      required this.onTap,
      this.icon,
      this.compact = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 10, vertical: compact ? 4 : 6),
        decoration: BoxDecoration(
          color: selected
              ? StrainsDS.headerBg
              : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: selected
                  ? StrainsDS.headerBg
                  : const Color(0xFFCBD5E1)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon,
                size: 13,
                color: selected
                    ? Colors.white70
                    : const Color(0xFF64748B)),
            const SizedBox(width: 5)
          ],
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: selected
                      ? Colors.white
                      : const Color(0xFF475569))),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Kingdom selector
// ─────────────────────────────────────────────────────────────────────────────
class _KingdomSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _KingdomSelector(
      {required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        textStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 11)),
        padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 10)),
      ),
      segments: const [
        ButtonSegment(value: 'all', label: Text('All')),
        ButtonSegment(
            value: 'prokaryote', label: Text('Prokaryote')),
        ButtonSegment(
            value: 'eukaryote', label: Text('Eukaryote')),
      ],
      selected: {value},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Draggable header
// ─────────────────────────────────────────────────────────────────────────────
class _DraggableHeader extends StatefulWidget {
  final StrainColDef col;
  final List<StrainColDef> allVisibleCols;
  final double Function(StrainColDef) colWidthFn;
  final VoidCallback onDragStart;
  final void Function(double localX) onDragUpdate;
  final VoidCallback onDragEnd;
  final VoidCallback? onTapInSelectionMode;
  final VoidCallback onTapSort;
  final Widget child;

  const _DraggableHeader({
    required this.col,
    required this.allVisibleCols,
    required this.colWidthFn,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onTapSort,
    required this.child,
    this.onTapInSelectionMode,
  });

  @override
  State<_DraggableHeader> createState() => _DraggableHeaderState();
}

class _DraggableHeaderState extends State<_DraggableHeader> {
  bool _isDragging = false;
  double _pointerStartX = 0;
  double _colStartOffset = 0;

  double get _cw => widget.colWidthFn(widget.col);

  double _offsetOf(StrainColDef col) {
    double acc = 0;
    for (final c in widget.allVisibleCols) {
      if (c.key == col.key) break;
      acc += widget.colWidthFn(c);
    }
    return acc;
  }

  @override
  Widget build(BuildContext context) {
    final inSel = widget.onTapInSelectionMode != null;
    return GestureDetector(
      onTap: inSel ? widget.onTapInSelectionMode : widget.onTapSort,
      onLongPressStart: inSel
          ? null
          : (d) {
              _pointerStartX = d.globalPosition.dx;
              _colStartOffset = _offsetOf(widget.col);
              setState(() => _isDragging = true);
              widget.onDragStart();
            },
      onLongPressMoveUpdate: inSel
          ? null
          : (d) {
              if (!_isDragging) return;
              widget.onDragUpdate(_colStartOffset +
                  _cw / 2 +
                  d.globalPosition.dx -
                  _pointerStartX);
            },
      onLongPressEnd: inSel
          ? null
          : (_) {
              setState(() => _isDragging = false);
              widget.onDragEnd();
            },
      onLongPressCancel: inSel
          ? null
          : () {
              setState(() => _isDragging = false);
              widget.onDragEnd();
            },
      child: MouseRegion(
        cursor: inSel
            ? SystemMouseCursors.click
            : (_isDragging
                ? SystemMouseCursors.grabbing
                : SystemMouseCursors.grab),
        child: widget.child,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Column resize handle
// ─────────────────────────────────────────────────────────────────────────────
class _ColResizeHandle extends StatefulWidget {
  final void Function(double delta) onDrag;
  final void Function() onDragEnd;
  const _ColResizeHandle(
      {required this.onDrag, required this.onDragEnd});

  @override
  State<_ColResizeHandle> createState() =>
      _ColResizeHandleState();
}

class _ColResizeHandleState extends State<_ColResizeHandle> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _hovering = true),
      onExit:  (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (d) => widget.onDrag(d.delta.dx),
        onHorizontalDragEnd: (_) => widget.onDragEnd(),
        child: Center(
            child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 2,
          height: 20,
          decoration: BoxDecoration(
            color: _hovering
                ? const Color(0xFF60A5FA)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(1),
          ),
        )),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Horizontal scrollbar thumb
// ─────────────────────────────────────────────────────────────────────────────
class _HorizontalThumb extends StatefulWidget {
  final double contentWidth;
  final ValueNotifier<double> offset;
  final void Function(double) onScrollTo;
  const _HorizontalThumb(
      {required this.contentWidth,
      required this.offset,
      required this.onScrollTo});

  @override
  State<_HorizontalThumb> createState() =>
      _HorizontalThumbState();
}

class _HorizontalThumbState extends State<_HorizontalThumb> {
  double? _dragStartX;
  double? _dragStartOffset;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, constraints) {
      final viewW    = constraints.maxWidth;
      final contentW = widget.contentWidth;
      if (contentW <= viewW) return const SizedBox(height: 10);
      final thumbW    =
          (viewW * viewW / contentW).clamp(40.0, viewW);
      final maxThumbX = viewW - thumbW;
      return SizedBox(
        height: 10,
        child: ValueListenableBuilder<double>(
          valueListenable: widget.offset,
          builder: (ctx, offset, _) {
            final maxOffset = contentW - viewW;
            final fraction = maxOffset > 0
                ? (offset / maxOffset).clamp(0.0, 1.0)
                : 0.0;
            final thumbX = fraction * maxThumbX;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => widget.onScrollTo(
                  (d.localPosition.dx / viewW).clamp(0.0, 1.0) *
                      maxOffset),
              onHorizontalDragStart: (d) {
                _dragStartX = d.localPosition.dx;
                _dragStartOffset = offset;
              },
              onHorizontalDragUpdate: (d) {
                if (_dragStartX == null) return;
                widget.onScrollTo(_dragStartOffset! +
                    (d.localPosition.dx - _dragStartX!) /
                        maxThumbX *
                        maxOffset);
              },
              child: CustomPaint(
                  painter: _ThumbPainter(
                      thumbX: thumbX, thumbW: thumbW),
                  size: Size(viewW, 10)),
            );
          },
        ),
      );
    });
  }
}

class _ThumbPainter extends CustomPainter {
  final double thumbX, thumbW;
  const _ThumbPainter({required this.thumbX, required this.thumbW});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(0, 3, size.width, 4),
            const Radius.circular(2)),
        Paint()..color = const Color(0xFFE2E8F0));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(thumbX, 1, thumbW, 8),
            const Radius.circular(4)),
        Paint()..color = const Color(0xFF94A3B8));
  }

  @override
  bool shouldRepaint(_ThumbPainter old) =>
      old.thumbX != thumbX || old.thumbW != thumbW;
}
// ─────────────────────────────────────────────────────────────────────────────
// Column position number input
// ─────────────────────────────────────────────────────────────────────────────
class _ColPositionField extends StatefulWidget {
  final int position;
  final int total;
  final void Function(int newPos) onSubmit;
  const _ColPositionField({required this.position, required this.total, required this.onSubmit});

  @override
  State<_ColPositionField> createState() => _ColPositionFieldState();
}

class _ColPositionFieldState extends State<_ColPositionField> {
  late TextEditingController _ctrl;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: '${widget.position}');
  }

  @override
  void didUpdateWidget(_ColPositionField old) {
    super.didUpdateWidget(old);
    if (!_editing && old.position != widget.position) {
      _ctrl.text = '${widget.position}';
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final val = int.tryParse(_ctrl.text);
    if (val != null) widget.onSubmit(val);
    else _ctrl.text = '${widget.position}';
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _editing = true),
      child: _editing
          ? SizedBox(
              width: 32,
              height: 26,
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
                  ),
                ),
                onSubmitted: (_) => _submit(),
                onTapOutside: (_) => _submit(),
              ),
            )
          : Container(
              width: 32,
              height: 26,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              alignment: Alignment.center,
              child: Text('${widget.position}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
            ),
    );
  }
}
