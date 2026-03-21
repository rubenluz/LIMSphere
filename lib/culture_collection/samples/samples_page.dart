import 'package:flutter/material.dart';
import '/theme/module_permission.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'dart:io';
import '/core/data_cache.dart';
import 'sample_detail_page.dart';
import '/theme/grid_widgets.dart';
import '../function_excel_import_page.dart';
import 'samples_columns.dart';
import 'samples_design_tokens.dart';
import '/theme/theme.dart';

// Column definitions are in samples_columns.dart; design tokens in theme/theme.dart


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
  final _vOffset = ValueNotifier<double>(0);

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
    _vOffset.dispose();
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
    final cached = await DataCache.read('samples');
    if (cached != null && mounted) {
      _rows = List<Map<String, dynamic>>.from(cached);
      _detectEmptyCols();
      _applyFilter();
      setState(() => _loading = false);
    } else {
      setState(() => _loading = true);
    }
    try {
      final res = await Supabase.instance.client
          .from('samples')
          .select()
          .order('sample_code', ascending: true);
      await DataCache.write('samples', res as List<dynamic>);
      if (!mounted) return;
      _rows = List<Map<String, dynamic>>.from(res);
      _detectEmptyCols();
      _applyFilter();
      setState(() => _loading = false);
    } catch (e) {
      if (cached == null) _snack('Error loading samples: $e');
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
    if (!context.canEditModule) { context.warnReadOnly(); return; }
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

  Future<void> _exportCsv() async {
    final rows = _filtered;
    final cols = _visibleCols;
    if (rows.isEmpty) { _snack('No data to export'); return; }
    final buf = StringBuffer()..writeln(cols.map((c) => '"${c.label}"').join(','));
    for (final row in rows) {
      buf.writeln(cols.map((c) {
        final v = row[c.key]?.toString() ?? '';
        return '"${v.replaceAll('"', '""')}"';
      }).join(','));
    }
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/samples_${DateTime.now().millisecondsSinceEpoch}.csv';
    File(path)..createSync(recursive: true)..writeAsStringSync(buf.toString());
    await OpenFilex.open(path);
    _snack('CSV exported (${rows.length} rows)');
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
      backgroundColor: context.appBg,
      resizeToAvoidBottomInset: false,
      appBar: _selectionMode ? _buildSelectionAppBar(desktop) : _buildNormalAppBar(desktop),
      body: Column(children: [
        _buildToolbar(),
        Divider(height: 1, color: context.appBorder),
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
    final iconColor = context.appTextSecondary;

    Widget btn({required IconData icon, required String tooltip, required String label, required VoidCallback onPressed}) {
      if (desktop) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: TextButton.icon(
            icon: Icon(icon, size: 16, color: iconColor),
            label: Text(label, style: TextStyle(fontSize: 12, color: iconColor)),
            onPressed: onPressed,
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
          ),
        );
      }
      return IconButton(
          icon: Icon(icon, size: 20, color: iconColor),
          tooltip: tooltip,
          onPressed: onPressed,
          padding: const EdgeInsets.all(8),
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36));
    }

    return AppBar(
      backgroundColor: context.appSurface,
      foregroundColor: context.appTextPrimary,
      elevation: 0,
      title: Text('Samples', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600, fontSize: 16)),
      actions: [
        // ── Add Sample ───────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: FilledButton.icon(
            onPressed: _addRow,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add Sample', style: TextStyle(fontSize: 12)),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(0, 36),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
        // ── CSV export ───────────────────────────────────────────────────
        Tooltip(
          message: 'Export CSV',
          child: IconButton(
            icon: Icon(Icons.download_outlined, size: 20, color: iconColor),
            onPressed: _exportCsv,
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ),
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
        btn(icon: Icons.refresh_rounded,    tooltip: 'Refresh',            label: 'Refresh',  onPressed: _load),
        btn(icon: Icons.checklist_rounded,  tooltip: 'Select rows & cols', label: 'Select',   onPressed: _enterSelectionMode),
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
            icon: Icon(Icons.more_vert, color: iconColor),
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
          style: TextButton.styleFrom(foregroundColor: AppDS.toolbarIcon, padding: const EdgeInsets.symmetric(horizontal: 8)),
        );
      }
      return IconButton(icon: Icon(icon, size: 20), tooltip: tooltip, onPressed: fn, color: AppDS.toolbarIcon);
    }

    return AppBar(
      backgroundColor: AppDS.fabBg,
      foregroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(icon: const Icon(Icons.close), tooltip: 'Exit selection', onPressed: _exitSelectionMode),
      title: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text('$rowCount row${rowCount != 1 ? 's' : ''} · $colCount col${colCount != 1 ? 's' : ''}',
            style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600, fontSize: 15)),
        Text('Tap rows to select · tap column headers to pick columns',
            style: GoogleFonts.spaceGrotesk(fontSize: 10, color: Colors.white.withValues(alpha: 0.55))),
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
      color: context.appSurface,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: TextField(
            controller: _searchController,
            style: TextStyle(fontSize: 13, color: context.appTextPrimary),
            decoration: InputDecoration(
              hintText: 'Search samples…',
              hintStyle: TextStyle(color: context.appTextMuted, fontSize: 13),
              prefixIcon: Icon(Icons.search_rounded, color: context.appTextMuted, size: 18),
              suffixIcon: _search.isNotEmpty
                  ? IconButton(icon: Icon(Icons.clear, size: 16, color: context.appTextMuted), onPressed: () {
                      _searchController.clear();
                      setState(() => _search = '');
                      _applyFilter();
                    })
                  : null,
              isDense: true, filled: true, fillColor: context.appSurface3,
              border:        OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.appBorder)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.appBorder)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppDS.accent, width: 1.5)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            ),
            onChanged: (v) { setState(() => _search = v); _applyFilter(); },
          )),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: context.appSurface2,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: context.appBorder),
            ),
            child: Text('${_filtered.length} / ${_rows.length}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.appTextMuted)),
          ),
        ]),
        if (hasSort) ...[
          const SizedBox(height: 8),
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
            Text('Sort:', style: TextStyle(fontSize: 11, color: context.appTextSecondary, fontWeight: FontWeight.w600)),
            const SizedBox(width: 6),
            ..._sortKeys.asMap().entries.map((e) => Padding(
              padding: const EdgeInsets.only(right: 4),
              child: InputChip(
                label: Text('${e.value} ${_sortDirs[e.value] == true ? "↑" : "↓"}',
                    style: TextStyle(fontSize: 11, color: context.appTextPrimary)),
                selected: true,
                selectedColor: context.appSurface2,
                side: const BorderSide(color: AppDS.accent),
                onDeleted: () {
                  setState(() { _sortKeys.removeAt(e.key); _sortDirs.remove(e.value); });
                  _saveSortPrefs();
                  _applySort();
                },
                deleteIconColor: context.appTextSecondary,
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
            )),
            TextButton.icon(
              icon: Icon(Icons.clear, size: 13, color: context.appTextSecondary),
              label: Text('Clear sorts', style: TextStyle(fontSize: 12, color: context.appTextSecondary)),
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
        color: context.appSurface,
        border: Border(bottom: BorderSide(color: context.appBorder)),
        boxShadow: const [BoxShadow(color: AppDS.shadow, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(children: [
            const Icon(Icons.view_column_outlined, size: 16, color: AppDS.accent),
            const SizedBox(width: 8),
            Text('Show / Hide Columns',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: context.appTextPrimary)),
            const Spacer(),
            TextButton(
              onPressed: () => setState(() => _hiddenCols = {}),
              style: TextButton.styleFrom(foregroundColor: AppDS.accent),
              child: const Text('Show all'),
            ),
          ]),
        ),
        Divider(height: 1, color: context.appBorder),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Wrap(
              spacing: 6, runSpacing: 6,
              children: sampleAllColumns.map((col) {
                final hidden = _hiddenCols.contains(col.key);
                final empty  = _emptyColKeys.contains(col.key);
                return FilterChip(
                  label: Text(col.label, style: TextStyle(fontSize: 11, color: context.appTextPrimary)),
                  selected: !hidden && !empty,
                  selectedColor: context.appSurface2,
                  side: BorderSide(color: context.appBorder),
                  checkmarkColor: AppDS.accent,
                  onSelected: empty ? null : (v) {
                    setState(() { if (v) _hiddenCols.remove(col.key); else _hiddenCols.add(col.key); });
                  },
                  avatar: empty ? Icon(Icons.remove_circle_outline, size: 11, color: context.appTextMuted) : null,
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
        Icon(Icons.colorize_outlined, size: 56, color: context.appBorder),
        const SizedBox(height: 12),
        Text('No samples found', style: TextStyle(color: context.appTextMuted, fontSize: 15)),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _addRow,
          icon: const Icon(Icons.add),
          label: const Text('Add First Sample'),
          style: FilledButton.styleFrom(
            backgroundColor: AppDS.accent,
            foregroundColor: AppDS.bg,
          ),
        ),
      ]));
    }

    final cols = _visibleCols;
    final totalWidth = (_selectionMode ? AppDS.tableCheckW : 0.0) + AppDS.tableOpenW +
        cols.fold(0.0, (s, c) => s + _colWidth(c));

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
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
                      if (n.metrics.axis == Axis.horizontal)
                        _hOffset.value = _hScroll.hasClients ? _hScroll.offset : 0.0;
                      else if (n.metrics.axis == Axis.vertical)
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
                            itemBuilder: (ctx, i) => _buildDataRow(_filtered[i], i, cols),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            AppVerticalThumb(
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
        AppHorizontalThumb(
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
      height: AppDS.tableHeaderH,
      decoration: BoxDecoration(
          color: context.appSurface, border: Border(bottom: BorderSide(color: context.appBorder))),
      child: Row(children: [
        if (_selectionMode)
          SizedBox(width: AppDS.tableCheckW, child: Center(child: Checkbox(
            value: allRowsSel ? true : (_selectedRowIds.isEmpty ? false : null),
            tristate: true, onChanged: (_) => _selectAllRows(),
            activeColor: Colors.white, checkColor: context.appSurface,
            side: BorderSide(color: context.appHeaderText.withValues(alpha: 0.38), width: 1.5),
          ))),
        SizedBox(width: AppDS.tableOpenW),
        ...List.generate(cols.length, (i) {
          final col      = cols[i];
          final isDrag   = _draggingColKey == col.key;
          final showDrop = _dropTargetIndex == i;
          final isColSel = _selectionMode && _selectedColKeys.contains(col.key);
          return Row(mainAxisSize: MainAxisSize.min, children: [
            if (showDrop) Container(width: 2, height: AppDS.tableHeaderH, color: AppDS.blue),
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
              Container(width: 2, height: AppDS.tableHeaderH, color: AppDS.blue),
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
    if (isColSelected) bgColor = AppDS.blue800;

    return SizedBox(
      width: width, height: AppDS.tableHeaderH,
      child: Stack(clipBehavior: Clip.none, children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            width: width, height: AppDS.tableHeaderH,
            decoration: BoxDecoration(
              color: bgColor,
              border: Border(right: BorderSide(color: context.appBorder)),
            ),
            padding: const EdgeInsets.only(left: 8, right: 14),
            child: Row(children: [
              if (isColSelected)
                Padding(padding: const EdgeInsets.only(right: 5),
                    child: Icon(Icons.check_box_rounded, size: 11, color: Colors.white.withValues(alpha: 0.85))),
              Expanded(child: Text(col.label,
                  style: AppDS.tableHeaderStyle.copyWith(
                    color: isColSelected ? Colors.white :
                           col.readOnly  ? context.appHeaderText.withValues(alpha: 0.38) : context.appHeaderText,
                  ),
                  overflow: TextOverflow.ellipsis)),
              if (!_selectionMode && isSorted)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(_sortDirs[col.key] == true ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                      size: 11, color: AppDS.blue),
                  if (_sortKeys.length > 1) ...[
                    const SizedBox(width: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                      decoration: BoxDecoration(color: AppDS.blue, borderRadius: BorderRadius.circular(2)),
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
    final Color rowBg   = isSelected ? AppDS.tableRowSel : index.isEven ? AppDS.tableRowEven : AppDS.tableRowOdd;
    final Color cellBase = isSelected ? AppDS.tableRowSel : index.isEven ? AppDS.tableRowEven : AppDS.tableRowOdd;

    return GestureDetector(
      onTap: _selectionMode ? () => _toggleRowSelection(row['sample_code']) : null,
      child: Container(
        height: AppDS.tableRowH,
        decoration: BoxDecoration(
          color: rowBg,
          border: const Border(bottom: BorderSide(color: AppDS.tableBorder, width: 0.5)),
        ),
        child: Row(children: [
          if (_selectionMode)
            Container(
              width: AppDS.tableCheckW, height: AppDS.tableRowH, color: cellBase,
              child: Center(child: Checkbox(
                value: isSelected,
                onChanged: (_) => _toggleRowSelection(row['sample_code']),
                visualDensity: VisualDensity.compact,
                activeColor: AppDS.blue800,
              )),
            ),
          // Open button
          Container(
            width: AppDS.tableOpenW, height: AppDS.tableRowH, color: cellBase,
            child: Center(child: IconButton(
              icon: Icon(Icons.launch_rounded, size: 14,
                  color: _selectionMode ? AppDS.textSecondary : AppDS.textSecondary),
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
        if (!context.canEditModule) { context.warnReadOnly(); return; }
        setState(() {
          _editingCell = {'rowId': row['sample_code'], 'key': col.key};
          _editController.text = row[col.key]?.toString() ?? '';
        });
      },
      child: Container(
        width: width, height: AppDS.tableRowH,
        decoration: BoxDecoration(
          color: cellBase,
          border: const Border(right: BorderSide(color: AppDS.tableBorder)),
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
                      borderSide: const BorderSide(color: AppDS.blue500, width: 1.5)),
                ),
                onSubmitted:  (v) => _commitEdit(row, col.key, v),
                onTapOutside: (_) => _commitEdit(row, col.key, _editController.text),
              ))
            : Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  row[col.key]?.toString() ?? '',
                  style: isReadOnly ? AppDS.tableReadOnlyStyle : AppDS.tableCellStyle,
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
            color: _hovering ? AppDS.blue : Colors.transparent,
            borderRadius: BorderRadius.circular(1),
          ),
        )),
      ),
    );
  }
}

// Thumb widgets provided by /theme/grid_widgets.dart (AppHorizontalThumb, AppVerticalThumb).
