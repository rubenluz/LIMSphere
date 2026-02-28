import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'dart:io';
import 'sample_detail_page.dart';
import '../excel_import_page.dart';
import 'samples_columns.dart';
import 'samples_design_tokens.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Design tokens  (mirrors strains_page _DS)
// Design tokens and column definitions are now in separate files
// - samples_design_tokens.dart (SamplesDS, preference keys, platform check)
// - samples_columns.dart (SampleColDef, column definitions)


// Column definitions are now in samples_columns.dart


// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────
class SamplesPage extends StatefulWidget {
  const SamplesPage({super.key});

  @override
  State<SamplesPage> createState() => _SamplesPageState();
}

class _SamplesPageState extends State<SamplesPage> {
  List<Map<String, dynamic>> _rows     = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;

  // Selection
  bool _selectionMode = false;
  final Set<dynamic> _selectedRowIds  = {};
  final Set<String>  _selectedColKeys = {};

  // Search / sort
  String _search = '';
  List<String>      _sortKeys = [];
  Map<String, bool> _sortDirs = {};
  final _searchController = TextEditingController();

  // Column visibility
  Set<String> _hiddenCols   = {};
  Set<String> _emptyColKeys = {};
  bool _showColManager = false;

  // Column widths / order
  final Map<String, double> _colWidths = {};
  List<String>? _colOrder;
  String? _draggingColKey;
  int?    _dropTargetIndex;

  // Inline editing
  Map<String, dynamic>? _editingCell;
  final _editController = TextEditingController();

  // Scroll
  final _hScroll = ScrollController();
  final _vScroll = ScrollController();
  final _hOffset = ValueNotifier<double>(0);

  // ── Derived ────────────────────────────────────────────────────────────────
  List<SampleColDef> get _visibleCols {
    final ordered = _colOrder == null
        ? List<SampleColDef>.from(sampleAllColumns)
        : [
            ..._colOrder!
                .map((k) { try { return sampleAllColumns.firstWhere((c) => c.key == k); } catch (_) { return null; } })
                .whereType<SampleColDef>(),
            ...sampleAllColumns.where((c) => !_colOrder!.contains(c.key)),
          ];
    return ordered.where((col) {
      if (_hiddenCols.contains(col.key))   return false;
      if (_emptyColKeys.contains(col.key)) return false;
      return true;
    }).toList();
  }

  double _colWidth(SampleColDef col) => _colWidths[col.key] ?? col.defaultWidth;

  List<SampleColDef> get _exportCols {
    if (_selectionMode && _selectedColKeys.isNotEmpty) {
      return _visibleCols.where((c) => _selectedColKeys.contains(c.key)).toList();
    }
    return _visibleCols;
  }

  List<Map<String, dynamic>> get _selectedRows =>
      _filtered.where((r) => _selectedRowIds.contains(r['sample_code'])).toList();

  // ─────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadPrefs().then((_) => _load());
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
      final keysStr = prefs.getString(samplePrefSortKeys);
      if (keysStr != null && keysStr.isNotEmpty) {
        _sortKeys = keysStr.split(',').where((s) => s.isNotEmpty).toList();
      }
      final dirsStr = prefs.getString(samplePrefSortDirs);
      if (dirsStr != null && dirsStr.isNotEmpty) {
        for (final part in dirsStr.split('|')) {
          final kv = part.split(':');
          if (kv.length == 2) _sortDirs[kv[0]] = kv[1] == 'asc';
        }
      }
      for (final k in prefs.getKeys()) {
        if (k.startsWith('$samplePrefColWidths.')) {
          final w = prefs.getDouble(k);
          if (w != null) _colWidths[k.substring('$samplePrefColWidths.'.length)] = w;
        }
      }
      final saved = prefs.getString(samplePrefColOrder);
      if (saved != null && saved.isNotEmpty) {
        _colOrder = saved.split(',').where((s) => s.isNotEmpty).toList();
      }
    });
  }

  Future<void> _saveSortPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (_sortKeys.isEmpty) {
      await prefs.remove(samplePrefSortKeys);
      await prefs.remove(samplePrefSortDirs);
    } else {
      await prefs.setString(samplePrefSortKeys, _sortKeys.join(','));
      final dirsStr = _sortKeys.map((k) => '$k:${_sortDirs[k] == true ? "asc" : "desc"}').join('|');
      await prefs.setString(samplePrefSortDirs, dirsStr);
    }
  }

  Future<void> _saveColWidth(String key, double w) async =>
      (await SharedPreferences.getInstance()).setDouble('$samplePrefColWidths.$key', w);

  Future<void> _resetColWidths() async {
    final prefs = await SharedPreferences.getInstance();
    for (final k in prefs.getKeys().where((k) => k.startsWith('$samplePrefColWidths.')).toList()) {
      await prefs.remove(k);
    }
    setState(() => _colWidths.clear());
  }

  Future<void> _saveColOrder() async {
    if (_colOrder == null) return;
    (await SharedPreferences.getInstance()).setString(samplePrefColOrder, _colOrder!.join(','));
  }

  Future<void> _resetColOrder() async {
    await (await SharedPreferences.getInstance()).remove(samplePrefColOrder);
    setState(() => _colOrder = null);
  }

  void _reorderCol(String colKey, int toVisibleIndex) {
    final all = _colOrder ?? sampleAllColumns.map((c) => c.key).toList();
    final mutable = List<String>.from(all)..remove(colKey);
    final visible = _visibleCols;
    String? anchorKey;
    if (toVisibleIndex < visible.length) {
      anchorKey = visible[toVisibleIndex].key;
      if (anchorKey == colKey) { setState(() { _draggingColKey = null; _dropTargetIndex = null; }); return; }
    }
    if (anchorKey == null) {
      final lv = visible.isNotEmpty ? visible.last.key : null;
      if (lv != null) mutable.insert((mutable.indexOf(lv) + 1).clamp(0, mutable.length), colKey);
      else mutable.add(colKey);
    } else {
      mutable.insert(mutable.indexOf(anchorKey).clamp(0, mutable.length), colKey);
    }
    setState(() { _colOrder = mutable; _draggingColKey = null; _dropTargetIndex = null; });
    _saveColOrder();
  }

  // ── Data ──────────────────────────────────────────────────────────────────
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await Supabase.instance.client
          .from('samples')
          .select()
          .order('sample_code', ascending: true);
      _rows = List<Map<String, dynamic>>.from(res);
      _detectEmptyCols();
      _applyFilter();
    } catch (e) {
      _snack('Error loading samples: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _detectEmptyCols() {
    _emptyColKeys = sampleAllColumns
        .where((col) => !_rows.any((r) {
              final v = r[col.key];
              return v != null && v.toString().isNotEmpty;
            }))
        .map((c) => c.key)
        .toSet();
  }

  void _applyFilter() {
    var list = List<Map<String, dynamic>>.from(_rows);
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((r) =>
          r.values.any((v) => v?.toString().toLowerCase().contains(q) == true)).toList();
    }
    _filtered = list;
    _applySort();
  }

  static const _numericCols = {
    'sample_id', 'sample_latitude', 'sample_longitude', 'sample_altitude_m',
    'sample_temperature', 'sample_ph', 'sample_conductivity', 'sample_oxygen',
    'sample_salinity', 'sample_radiation', 'sample_turbidity', 'sample_depth_m',
    'sample_transport_time_h',
  };

  void _applySort() {
    if (_sortKeys.isEmpty) { if (mounted) setState(() {}); return; }
    _filtered.sort((a, b) {
      for (final key in _sortKeys) {
        final isNum = _numericCols.contains(key);
        final isAsc = _sortDirs[key] ?? true;
        late int cmp;
        if (isNum) {
          final ai = double.tryParse(a[key]?.toString() ?? '') ?? (isAsc ? double.maxFinite : double.negativeInfinity);
          final bi = double.tryParse(b[key]?.toString() ?? '') ?? (isAsc ? double.maxFinite : double.negativeInfinity);
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
      } else {
        _sortKeys.add(key);
        _sortDirs[key] = true;
      }
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
    final id = row['sample_code'];
    try {
      await Supabase.instance.client
          .from('samples')
          .update({key: value.isEmpty ? null : value})
          .eq('sample_code', id);
      final idx = _rows.indexWhere((r) => r['sample_code'] == id);
      if (idx != -1) _rows[idx][key] = value.isEmpty ? null : value;
      _applyFilter();
    } catch (e) {
      _snack('Save error: $e');
    }
    setState(() => _editingCell = null);
  }

  Future<void> _addRow() async {
    try {
      final maxRes = await Supabase.instance.client
          .from('samples')
          .select('sample_code')
          .order('sample_code', ascending: false)
          .limit(1);
      final nextNum = (maxRes as List).isNotEmpty && maxRes[0]['sample_code'] != null
          ? (maxRes[0]['sample_code'] as num).toInt() + 1
          : 1;
      final res = await Supabase.instance.client
          .from('samples')
          .insert({'sample_code': nextNum})
          .select()
          .single();
      _rows.add(Map<String, dynamic>.from(res));
      _detectEmptyCols();
      _applyFilter();
    } catch (e) {
      _snack('Error adding row: $e');
    }
  }

  Future<void> _deleteRow(Map<String, dynamic> row) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Delete Sample?'),
        content: Text(
            'Delete sample ${row['sample_code'] ?? '#${row['sample_id']}'}? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await Supabase.instance.client
          .from('samples')
          .delete()
          .eq('sample_code', row['sample_code']);
      _rows.removeWhere((r) => r['sample_code'] == row['sample_code']);
      _detectEmptyCols();
      _applyFilter();
    } catch (e) {
      _snack('Delete error: $e');
    }
  }

  void _openDetail(Map<String, dynamic> row) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SampleDetailPage(sampleId: row['sample_code'], onSaved: _load),
      ),
    ).then((_) => _load());
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))));
  }

  // ── Selection ─────────────────────────────────────────────────────────────
  void _enterSelectionMode() {
    setState(() {
      _selectionMode = true;
      _selectedRowIds.clear();
      _selectedColKeys..clear()..addAll(_visibleCols.map((c) => c.key));
    });
  }

  void _exitSelectionMode() {
    setState(() { _selectionMode = false; _selectedRowIds.clear(); _selectedColKeys.clear(); });
  }

  void _toggleRowSelection(dynamic id) => setState(() {
        if (_selectedRowIds.contains(id)) _selectedRowIds.remove(id);
        else _selectedRowIds.add(id);
      });

  void _toggleColSelection(String key) => setState(() {
        if (_selectedColKeys.contains(key)) _selectedColKeys.remove(key);
        else _selectedColKeys.add(key);
      });

  void _selectAllRows() => setState(() {
        if (_selectedRowIds.length == _filtered.length) _selectedRowIds.clear();
        else _selectedRowIds.addAll(_filtered.map((r) => r['sample_id'])); // Assuming 'sample_code' is the unique identifier
      });

  void _selectAllCols() => setState(() {
        final visible = _visibleCols.map((c) => c.key).toSet();
        if (_selectedColKeys.containsAll(visible)) _selectedColKeys.clear();
        else _selectedColKeys.addAll(visible);
      });

  // ── Export ────────────────────────────────────────────────────────────────
  Future<void> _copySelectedInfo() async {
    final rows = _selectedRows;
    final cols = _exportCols;
    if (rows.isEmpty) { _snack('Select at least one row'); return; }
    final buf = StringBuffer()..writeln(cols.map((c) => c.label).join('\t'));
    for (final row in rows) buf.writeln(cols.map((c) => row[c.key]?.toString() ?? '').join('\t'));
    await Clipboard.setData(ClipboardData(text: buf.toString()));
    _snack('Copied ${rows.length} row(s) × ${cols.length} col(s)');
  }

  Future<void> _exportSelectedToExcel() async {
    final rows = _selectedRows;
    final cols = _exportCols;
    if (rows.isEmpty) { _snack('Select at least one row'); return; }
    final excel = Excel.createExcel();
    final sheet = excel['Sheet1'];
    for (int c = 0; c < cols.length; c++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0)).value =
          TextCellValue(cols[c].label);
    }
    for (int r = 0; r < rows.length; r++) {
      for (int c = 0; c < cols.length; c++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1)).value =
            _toCellValue(rows[r][cols[c].key]);
      }
    }
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/samples_export_${DateTime.now().millisecondsSinceEpoch}.xlsx';
    File(path)..createSync(recursive: true)..writeAsBytesSync(excel.encode()!);
    await OpenFilex.open(path);
    _snack('Excel exported (${rows.length} rows)');
  }

  CellValue _toCellValue(dynamic v) {
    if (v == null)        return TextCellValue('');
    if (v is int)         return IntCellValue(v);
    if (v is double)      return DoubleCellValue(v);
    if (v is bool)        return BoolCellValue(v);
    if (v is DateTime)    return DateCellValue(year: v.year, month: v.month, day: v.day);
    return TextCellValue(v.toString());
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final desktop = isSampleDesktop(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      resizeToAvoidBottomInset: false,
      appBar: _selectionMode ? _buildSelectionAppBar(desktop) : _buildNormalAppBar(desktop),
      body: Column(children: [
        _buildToolbar(),
        if (_showColManager) _buildColumnManager(),
        if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else
          Expanded(child: _buildGrid()),
      ]),
      floatingActionButton: _selectionMode
          ? null
          : FloatingActionButton.extended(
              onPressed: _addRow,
              icon: const Icon(Icons.add),
              label: const Text('New Sample'),
              backgroundColor: SamplesDS.headerBg,
              foregroundColor: Colors.white,
            ),
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
            label: Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70)),
            onPressed: onPressed,
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
          ),
        );
      }
      return IconButton(
          icon: Icon(icon, size: 20, color: Colors.white70),
          tooltip: tooltip,
          onPressed: onPressed,
          padding: const EdgeInsets.all(8),
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36));
    }

    return AppBar(
      backgroundColor: SamplesDS.headerBg,
      foregroundColor: Colors.white,
      elevation: 0,
      title: const Row(children: [
        Icon(Icons.colorize_rounded, size: 20, color: Colors.white70),
        SizedBox(width: 8),
        Text('Samples', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
      ]),
      actions: [
        btn(
            icon: Icons.upload_file_rounded,
            tooltip: 'Import from Excel',
            label: 'Import',
            onPressed: () async {
              final ok = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          const ExcelImportPage(mode: 'samples')));
              if (ok == true) _load();
            }),
        btn(icon: Icons.refresh_rounded,    tooltip: 'Refresh',           label: 'Refresh',  onPressed: _load),
        btn(icon: Icons.checklist_rounded,  tooltip: 'Select rows & cols', label: 'Select',  onPressed: _enterSelectionMode),
        btn(icon: _showColManager ? Icons.view_column : Icons.view_column_outlined,
            tooltip: 'Manage columns', label: 'Columns',
            onPressed: () => setState(() => _showColManager = !_showColManager)),
        if (desktop) ...[
          btn(icon: Icons.width_normal_outlined, tooltip: 'Reset widths', label: 'Reset widths',
              onPressed: () async { await _resetColWidths(); _snack('Column widths reset'); }),
          btn(icon: Icons.reorder_rounded, tooltip: 'Reset order', label: 'Reset order',
              onPressed: () async { await _resetColOrder(); _snack('Column order reset'); }),
        ] else
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white70),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            onSelected: (v) async {
              if (v == 'widths') { await _resetColWidths(); _snack('Column widths reset'); }
              if (v == 'order')  { await _resetColOrder();  _snack('Column order reset'); }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'widths', child: ListTile(leading: Icon(Icons.width_normal_outlined), title: Text('Reset column widths'), dense: true)),
              const PopupMenuItem(value: 'order',  child: ListTile(leading: Icon(Icons.reorder_rounded),       title: Text('Reset column order'),  dense: true)),
            ],
          ),
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
          icon: Icon(icon, size: 16), label: Text(label, style: const TextStyle(fontSize: 12)),
          onPressed: fn,
          style: TextButton.styleFrom(foregroundColor: Colors.white70, padding: const EdgeInsets.symmetric(horizontal: 8)),
        );
      }
      return IconButton(icon: Icon(icon, size: 20), tooltip: tooltip, onPressed: fn, color: Colors.white70);
    }

    return AppBar(
      backgroundColor: const Color(0xFF1E3A5F),
      foregroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(icon: const Icon(Icons.close), tooltip: 'Exit selection', onPressed: _exitSelectionMode),
      title: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text('$rowCount row${rowCount != 1 ? 's' : ''} · $colCount col${colCount != 1 ? 's' : ''}',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        Text('Tap rows to select · tap column headers to pick columns',
            style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.55))),
      ]),
      actions: [
        selBtn(icon: allRowsSel ? Icons.deselect : Icons.select_all,
               tooltip: allRowsSel ? 'Deselect all rows' : 'Select all rows',
               label: allRowsSel ? 'All rows ✓' : 'All rows', fn: _selectAllRows),
        selBtn(icon: allColsSel ? Icons.view_column : Icons.view_column_outlined,
               tooltip: allColsSel ? 'Deselect all cols' : 'Select all cols',
               label: allColsSel ? 'All cols ✓' : 'All cols', fn: _selectAllCols),
        Center(child: Container(width: 1, height: 22, margin: const EdgeInsets.symmetric(horizontal: 4), color: Colors.white24)),
        selBtn(icon: Icons.copy_rounded,   tooltip: 'Copy to Clipboard', label: 'Copy',   fn: _copySelectedInfo),
        selBtn(icon: Icons.grid_on_rounded, tooltip: 'Export to Excel',  label: 'Export', fn: _exportSelectedToExcel),
        const SizedBox(width: 4),
      ],
    );
  }

  // ── Toolbar ───────────────────────────────────────────────────────────────
  Widget _buildToolbar() {
    final hasSort = _sortKeys.isNotEmpty;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search samples…',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade400, size: 18),
              suffixIcon: _search.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.clear, size: 16), onPressed: () {
                      _searchController.clear();
                      setState(() => _search = '');
                      _applyFilter();
                    })
                  : null,
              isDense: true, filled: true, fillColor: const Color(0xFFF8FAFC),
              border:        OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            ),
            style: const TextStyle(fontSize: 13),
            onChanged: (v) { setState(() => _search = v); _applyFilter(); },
          )),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
            child: Text('${_filtered.length} / ${_rows.length}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
          ),
        ]),
        if (hasSort) ...[
          const SizedBox(height: 8),
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
            Text('Sort:', style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
            const SizedBox(width: 6),
            ..._sortKeys.asMap().entries.map((e) => Padding(
              padding: const EdgeInsets.only(right: 4),
              child: InputChip(
                label: Text('${e.value} ${_sortDirs[e.value] == true ? "↑" : "↓"}', style: const TextStyle(fontSize: 11)),
                selected: true,
                onDeleted: () {
                  setState(() { _sortKeys.removeAt(e.key); _sortDirs.remove(e.value); });
                  _saveSortPrefs();
                  _applySort();
                },
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
            )),
            TextButton.icon(
              icon: const Icon(Icons.clear, size: 13),
              label: const Text('Clear sorts', style: TextStyle(fontSize: 12)),
              onPressed: _resetSort,
            ),
          ])),
        ],
      ]),
    );
  }

  // ── Column manager ────────────────────────────────────────────────────────
  Widget _buildColumnManager() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 240),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(children: [
            Text('Show / Hide Columns',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Theme.of(context).colorScheme.primary)),
            const Spacer(),
            TextButton(onPressed: () => setState(() => _hiddenCols = {}), child: const Text('Show all')),
          ]),
        ),
        Divider(height: 1, color: Colors.grey.shade100),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Wrap(
              spacing: 6, runSpacing: 6,
              children: sampleAllColumns.map((col) {
                final hidden = _hiddenCols.contains(col.key);
                final empty  = _emptyColKeys.contains(col.key);
                return FilterChip(
                  label: Text(col.label, style: const TextStyle(fontSize: 11)),
                  selected: !hidden && !empty,
                  onSelected: empty ? null : (v) {
                    setState(() { if (v) _hiddenCols.remove(col.key); else _hiddenCols.add(col.key); });
                  },
                  avatar: empty ? const Icon(Icons.remove_circle_outline, size: 11, color: Colors.grey) : null,
                  tooltip: empty ? 'No data' : null,
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                );
              }).toList(),
            ),
          ),
        ),
      ]),
    );
  }

  // ── Grid ──────────────────────────────────────────────────────────────────
  Widget _buildGrid() {
    if (_filtered.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.colorize_outlined, size: 56, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        Text('No samples found', style: TextStyle(color: Colors.grey.shade500, fontSize: 15)),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _addRow,
          icon: const Icon(Icons.add),
          label: const Text('Add First Sample'),
          style: FilledButton.styleFrom(backgroundColor: SamplesDS.headerBg),
        ),
      ]));
    }

    final cols = _visibleCols;
    final totalWidth = (_selectionMode ? SamplesDS.checkW : 0.0) + SamplesDS.openW +
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
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            clipBehavior: Clip.antiAlias,
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n is ScrollUpdateNotification && n.metrics.axis == Axis.horizontal) {
                  _hOffset.value = _hScroll.hasClients ? _hScroll.offset : 0.0;
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
                        itemExtent: SamplesDS.rowH,
                        itemBuilder: (ctx, i) => _buildDataRow(_filtered[i], i, cols),
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
  Widget _buildHeaderRow(List<SampleColDef> cols) {
    final allRowsSel = _filtered.isNotEmpty && _selectedRowIds.length == _filtered.length;
    return Container(
      height: SamplesDS.headerH,
      decoration: const BoxDecoration(
          color: SamplesDS.headerBg, border: Border(bottom: BorderSide(color: SamplesDS.headerBorder))),
      child: Row(children: [
        if (_selectionMode)
          SizedBox(width: SamplesDS.checkW, child: Center(child: Checkbox(
            value: allRowsSel ? true : (_selectedRowIds.isEmpty ? false : null),
            tristate: true, onChanged: (_) => _selectAllRows(),
            activeColor: Colors.white, checkColor: SamplesDS.headerBg,
            side: const BorderSide(color: Colors.white38, width: 1.5),
          ))),
        SizedBox(width: SamplesDS.openW,
            child: const Center(child: Icon(Icons.launch_rounded, size: 13, color: Colors.white30))),
        ...List.generate(cols.length, (i) {
          final col      = cols[i];
          final isDrag   = _draggingColKey == col.key;
          final showDrop = _dropTargetIndex == i;
          final isColSel = _selectionMode && _selectedColKeys.contains(col.key);
          return Row(mainAxisSize: MainAxisSize.min, children: [
            if (showDrop) Container(width: 2, height: SamplesDS.headerH, color: const Color(0xFF60A5FA)),
            Opacity(
              opacity: isDrag ? 0.35 : 1.0,
              child: _DraggableHeader(
                col: col, allVisibleCols: cols, colWidthFn: _colWidth,
                onDragStart:  () => setState(() { _draggingColKey = col.key; _dropTargetIndex = null; }),
                onDragUpdate: (localX) {
                  double accum = 0; int slot = cols.length;
                  for (int j = 0; j < cols.length; j++) {
                    if (localX < accum + _colWidth(cols[j]) / 2) { slot = j; break; }
                    accum += _colWidth(cols[j]);
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
                child: _buildHeaderCell(col, isColSelected: isColSel),
              ),
            ),
            if (i == cols.length - 1 && _dropTargetIndex == cols.length)
              Container(width: 2, height: SamplesDS.headerH, color: const Color(0xFF60A5FA)),
          ]);
        }),
      ]),
    );
  }

  Widget _buildHeaderCell(SampleColDef col, {required bool isColSelected}) {
    final sortIndex = _sortKeys.indexOf(col.key);
    final isSorted  = sortIndex >= 0;
    final width     = _colWidth(col);
    Color bgColor   = Colors.transparent;
    if (isColSelected) bgColor = const Color(0xFF1E40AF);

    return SizedBox(
      width: width, height: SamplesDS.headerH,
      child: Stack(clipBehavior: Clip.none, children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            width: width, height: SamplesDS.headerH,
            decoration: BoxDecoration(
              color: bgColor,
              border: const Border(right: BorderSide(color: SamplesDS.headerBorder)),
            ),
            padding: const EdgeInsets.only(left: 8, right: 14),
            child: Row(children: [
              if (isColSelected)
                Padding(padding: const EdgeInsets.only(right: 5),
                    child: Icon(Icons.check_box_rounded, size: 11, color: Colors.white.withOpacity(0.85))),
              Expanded(child: Text(col.label,
                  style: SamplesDS.headerStyle.copyWith(
                    color: isColSelected ? Colors.white :
                           col.readOnly  ? Colors.white38 : SamplesDS.headerText,
                  ),
                  overflow: TextOverflow.ellipsis)),
              if (!_selectionMode && isSorted)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(_sortDirs[col.key] == true ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                      size: 11, color: const Color(0xFF60A5FA)),
                  if (_sortKeys.length > 1) ...[
                    const SizedBox(width: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                      decoration: BoxDecoration(color: const Color(0xFF60A5FA), borderRadius: BorderRadius.circular(2)),
                      child: Text('${sortIndex + 1}', style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ]),
            ]),
          ),
        ),
        if (!_selectionMode)
          Positioned(right: -4, top: 0, bottom: 0, width: 8,
            child: _ColResizeHandle(
              onDrag:    (d) => setState(() { _colWidths[col.key] = (_colWidth(col) + d).clamp(sampleMinColWidth, 600.0); }),
              onDragEnd: ()  => _saveColWidth(col.key, _colWidth(col)),
            )),
      ]),
    );
  }

  // ── Data row ──────────────────────────────────────────────────────────────
  Widget _buildDataRow(Map<String, dynamic> row, int index, List<SampleColDef> cols) {
    final isSelected = _selectedRowIds.contains(row['sample_code']);
    final Color rowBg   = isSelected ? SamplesDS.selectedBg : index.isEven ? SamplesDS.rowEven : SamplesDS.rowOdd;
    final Color cellBase = isSelected ? SamplesDS.selectedBg : index.isEven ? SamplesDS.rowEven : SamplesDS.rowOdd;

    return GestureDetector(
      onTap: _selectionMode ? () => _toggleRowSelection(row['sample_code']) : null,
      child: Container(
        height: SamplesDS.rowH,
        decoration: BoxDecoration(
          color: rowBg,
          border: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 0.5)),
        ),
        child: Row(children: [
          if (_selectionMode)
            Container(
              width: SamplesDS.checkW, height: SamplesDS.rowH, color: cellBase,
              child: Center(child: Checkbox(
                value: isSelected,
                onChanged: (_) => _toggleRowSelection(row['sample_code']),
                visualDensity: VisualDensity.compact,
                activeColor: const Color(0xFF1E40AF),
              )),
            ),
          // Open button
          Container(
            width: SamplesDS.openW, height: SamplesDS.rowH, color: cellBase,
            child: Center(child: IconButton(
              icon: Icon(Icons.launch_rounded, size: 14,
                  color: _selectionMode ? Colors.grey.shade400 : const Color(0xFF94A3B8)),
              tooltip: 'Open sample',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: _selectionMode ? null : () => _openDetail(row),
            )),
          ),
          ...cols.map((col) => _buildDataCell(row, col, cellBase)),
        ]),
      ),
    );
  }

  // ── Data cell ─────────────────────────────────────────────────────────────
  Widget _buildDataCell(Map<String, dynamic> row, SampleColDef col, Color cellBase) {
    final isEditing  = _editingCell?['rowId'] == row['sample_code'] && _editingCell?['key'] == col.key;
    final isReadOnly = col.readOnly;
    final width      = _colWidth(col);

    return GestureDetector(
      onDoubleTap: (_selectionMode || isReadOnly) ? null : () {
        setState(() {
          _editingCell = {'rowId': row['sample_code'], 'key': col.key};
          _editController.text = row[col.key]?.toString() ?? '';
        });
      },
      child: Container(
        width: width, height: SamplesDS.rowH,
        decoration: BoxDecoration(
          color: cellBase,
          border: const Border(right: BorderSide(color: SamplesDS.cellBorder)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: isEditing
            ? Center(child: TextField(
                controller: _editController,
                autofocus: true,
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  border:        OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5)),
                ),
                onSubmitted:  (v) => _commitEdit(row, col.key, v),
                onTapOutside: (_) => _commitEdit(row, col.key, _editController.text),
              ))
            : Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  row[col.key]?.toString() ?? '',
                  style: isReadOnly ? SamplesDS.readOnlyStyle : SamplesDS.cellStyle,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Draggable header  (identical pattern to strains_page)
// ─────────────────────────────────────────────────────────────────────────────
class _DraggableHeader extends StatefulWidget {
  final SampleColDef col;
  final List<SampleColDef> allVisibleCols;
  final double Function(SampleColDef) colWidthFn;
  final VoidCallback onDragStart;
  final void Function(double localX) onDragUpdate;
  final VoidCallback onDragEnd;
  final VoidCallback? onTapInSelectionMode;
  final VoidCallback onTapSort;
  final Widget child;
  const _DraggableHeader({
    required this.col, required this.allVisibleCols, required this.colWidthFn,
    required this.onDragStart, required this.onDragUpdate, required this.onDragEnd,
    required this.onTapSort, required this.child, this.onTapInSelectionMode,
  });
  @override State<_DraggableHeader> createState() => _DraggableHeaderState();
}

class _DraggableHeaderState extends State<_DraggableHeader> {
  bool _isDragging = false;
  double _pointerStartX = 0;
  double _colStartOffset = 0;

  double get _cw => widget.colWidthFn(widget.col);

  double _offsetOf(SampleColDef col) {
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
      onLongPressStart: inSel ? null : (d) {
        _pointerStartX  = d.globalPosition.dx;
        _colStartOffset = _offsetOf(widget.col);
        setState(() => _isDragging = true);
        widget.onDragStart();
      },
      onLongPressMoveUpdate: inSel ? null : (d) {
        if (!_isDragging) return;
        widget.onDragUpdate(_colStartOffset + _cw / 2 + d.globalPosition.dx - _pointerStartX);
      },
      onLongPressEnd:    inSel ? null : (_) { setState(() => _isDragging = false); widget.onDragEnd(); },
      onLongPressCancel: inSel ? null : ()  { setState(() => _isDragging = false); widget.onDragEnd(); },
      child: MouseRegion(
        cursor: inSel ? SystemMouseCursors.click : (_isDragging ? SystemMouseCursors.grabbing : SystemMouseCursors.grab),
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
  const _ColResizeHandle({required this.onDrag, required this.onDragEnd});
  @override State<_ColResizeHandle> createState() => _ColResizeHandleState();
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
        onHorizontalDragEnd:    (_) => widget.onDragEnd(),
        child: Center(child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 2, height: 20,
          decoration: BoxDecoration(
            color: _hovering ? const Color(0xFF60A5FA) : Colors.transparent,
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
  const _HorizontalThumb({required this.contentWidth, required this.offset, required this.onScrollTo});
  @override State<_HorizontalThumb> createState() => _HorizontalThumbState();
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
      final thumbW    = (viewW * viewW / contentW).clamp(40.0, viewW);
      final maxThumbX = viewW - thumbW;
      return SizedBox(
        height: 10,
        child: ValueListenableBuilder<double>(
          valueListenable: widget.offset,
          builder: (ctx, offset, _) {
            final maxOffset = contentW - viewW;
            final fraction  = maxOffset > 0 ? (offset / maxOffset).clamp(0.0, 1.0) : 0.0;
            final thumbX    = fraction * maxThumbX;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => widget.onScrollTo((d.localPosition.dx / viewW).clamp(0.0, 1.0) * maxOffset),
              onHorizontalDragStart:  (d) { _dragStartX = d.localPosition.dx; _dragStartOffset = offset; },
              onHorizontalDragUpdate: (d) {
                if (_dragStartX == null) return;
                widget.onScrollTo(_dragStartOffset! + (d.localPosition.dx - _dragStartX!) / maxThumbX * maxOffset);
              },
              child: CustomPaint(
                  painter: _ThumbPainter(thumbX: thumbX, thumbW: thumbW),
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
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 3, size.width, 4), const Radius.circular(2)),
        Paint()..color = const Color(0xFFE2E8F0));
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(thumbX, 1, thumbW, 8), const Radius.circular(4)),
        Paint()..color = const Color(0xFF94A3B8));
  }
  @override bool shouldRepaint(_ThumbPainter old) => old.thumbX != thumbX || old.thumbW != thumbW;
}
