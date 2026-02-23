import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'sample_detail_page.dart';
import '../excel_import_page.dart';

// ── Column definition ────────────────────────────────────────────────────────
class ColDef {
  final String key;
  final String label;
  final double width;
  final bool readOnly;
  const ColDef(this.key, this.label, {this.width = 140, this.readOnly = false});
}

const List<ColDef> sampleColumns = [
  ColDef('number',       'Nº',                   width: 60,  readOnly: true),
  ColDef('rebeca',       'REBECA',                width: 110),
  ColDef('ccpi',         'CCPI',                  width: 110),
  ColDef('date',         'Date',                  width: 110),
  ColDef('country',      'Country',               width: 120),
  ColDef('archipelago',  'Archipelago',           width: 130),
  ColDef('island',       'Island',                width: 120),
  ColDef('municipality', 'Municipality',          width: 140),
  ColDef('local',        'Local',                 width: 150),
  ColDef('habitat_type', 'Habitat Type',          width: 130),
  ColDef('habitat_1',    'Habitat 1',             width: 130),
  ColDef('habitat_2',    'Habitat 2',             width: 130),
  ColDef('habitat_3',    'Habitat 3',             width: 130),
  ColDef('method',       'Method',                width: 130),
  ColDef('photos',       'Photos',                width: 100),
  ColDef('gps',          'GPS',                   width: 160),
  ColDef('temperature',  '°C',                    width: 80),
  ColDef('ph',           'pH',                    width: 80),
  ColDef('conductivity', 'Conductivity (µS/cm)',  width: 170),
  ColDef('oxygen',       'O₂ (mg/L)',             width: 100),
  ColDef('salinity',     'Salinity',              width: 100),
  ColDef('radiation',    'Solar Radiation',       width: 130),
  ColDef('responsible',  'Responsible',           width: 140),
  ColDef('observations', 'Observations',          width: 200),
];

// ── Page ─────────────────────────────────────────────────────────────────────
class SamplesPage extends StatefulWidget {
  const SamplesPage({super.key});

  @override
  State<SamplesPage> createState() => _SamplesPageState();
}

class _SamplesPageState extends State<SamplesPage> {
  List<Map<String, dynamic>> _rows = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  String _search = '';
  String? _sortKey;
  bool _sortAsc = true;

  // Editing state
  Map<String, dynamic>? _editingCell; // {rowId, key}
  final _editController = TextEditingController();
  final _searchController = TextEditingController();

  final _hScroll = ScrollController();
  final _vScroll = ScrollController();
  final _hOffset = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    _load();
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

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await Supabase.instance.client
          .from('samples')
          .select()
          .order('number', ascending: true);
      _rows = List<Map<String, dynamic>>.from(res);
      _applyFilter();
    } catch (e) {
      _snack('Error loading samples: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilter() {
    final q = _search.toLowerCase();
    _filtered = q.isEmpty
        ? List.from(_rows)
        : _rows.where((r) {
            return r.values.any((v) => v?.toString().toLowerCase().contains(q) == true);
          }).toList();
    _applySort();
  }

  void _applySort() {
    if (_sortKey != null) {
      _filtered.sort((a, b) {
        final av = a[_sortKey]?.toString() ?? '';
        final bv = b[_sortKey]?.toString() ?? '';
        return _sortAsc ? av.compareTo(bv) : bv.compareTo(av);
      });
    }
    if (mounted) setState(() {});
  }

  void _onSort(String key) {
    setState(() {
      if (_sortKey == key) {
        _sortAsc = !_sortAsc;
      } else {
        _sortKey = key;
        _sortAsc = true;
      }
    });
    _applySort();
  }

  Future<void> _commitEdit(Map<String, dynamic> row, String key, String value) async {
    final id = row['id'];
    try {
      await Supabase.instance.client
          .from('samples')
          .update({key: value.isEmpty ? null : value})
          .eq('id', id);
      final idx = _rows.indexWhere((r) => r['id'] == id);
      if (idx != -1) _rows[idx][key] = value.isEmpty ? null : value;
      _applyFilter();
    } catch (e) {
      _snack('Save error: $e');
    }
    setState(() => _editingCell = null);
  }

  Future<void> _addRow() async {
    try {
      final res = await Supabase.instance.client
          .from('samples')
          .insert({'number': (_rows.length + 1)})
          .select()
          .single();
      _rows.add(Map<String, dynamic>.from(res));
      _applyFilter();
    } catch (e) {
      _snack('Error adding row: $e');
    }
  }

  Future<void> _deleteRow(Map<String, dynamic> row) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Sample?'),
        content: Text('Delete sample ${row['rebeca'] ?? row['id']}? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await Supabase.instance.client.from('samples').delete().eq('id', row['id']);
      _rows.removeWhere((r) => r['id'] == row['id']);
      _applyFilter();
    } catch (e) {
      _snack('Delete error: $e');
    }
  }

  void _openDetail(Map<String, dynamic> row) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SampleDetailPage(sampleId: row['id'], onSaved: _load),
      ),
    );
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Samples'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load, tooltip: 'Refresh'),
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Import from Excel',
            onPressed: () async {
              final imported = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => const ExcelImportPage(mode: 'samples'),
                ),
              );
              if (imported == true) _load();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildToolbar(),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(child: _buildGrid()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addRow,
        icon: const Icon(Icons.add),
        label: const Text('New Sample'),
      ),
    );
  }

  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search samples…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _search = '');
                          _applyFilter();
                        },
                      )
                    : null,
                isDense: true,
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) {
                setState(() => _search = v);
                _applyFilter();
              },
            ),
          ),
          const SizedBox(width: 12),
          Text('${_filtered.length} record(s)',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    if (_filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.science_outlined, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text('No samples found.'),
          ],
        ),
      );
    }

    final totalWidth = sampleColumns.fold(0.0, (s, c) => s + c.width) + 80;

    return Column(
      children: [
        // Header — the ONLY ScrollController/ScrollPosition in the whole grid
        Scrollbar(
          controller: _hScroll,
          thumbVisibility: true,
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              _hOffset.value = _hScroll.hasClients ? _hScroll.offset : 0;
              return false;
            },
            child: SingleChildScrollView(
              controller: _hScroll,
              scrollDirection: Axis.horizontal,
              child: SizedBox(width: totalWidth, child: _buildHeaderRow()),
            ),
          ),
        ),
        const Divider(height: 1),
        // Body — rows are translated horizontally via ValueNotifier, no extra controllers
        Expanded(
          child: ListView.builder(
            controller: _vScroll,
            itemCount: _filtered.length,
            itemExtent: 40,
            itemBuilder: (ctx, i) => ValueListenableBuilder<double>(
              valueListenable: _hOffset,
              builder: (ctx, offset, _) => OverflowBox(
                alignment: Alignment.topLeft,
                minWidth: totalWidth,
                maxWidth: totalWidth,
                child: Transform.translate(
                  offset: Offset(-offset, 0),
                  child: SizedBox(
                    width: totalWidth,
                    child: _buildDataRow(_filtered[i], i),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderRow() {
    return Container(
      height: 44,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          ...sampleColumns.map((col) => _buildHeaderCell(col)),
          // Actions column
          SizedBox(
            width: 80,
            child: Center(
              child: Text('Actions',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(ColDef col) {
    final isSorted = _sortKey == col.key;
    return InkWell(
      onTap: () => _onSort(col.key),
      child: SizedBox(
        width: col.width,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  col.label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isSorted)
                Icon(_sortAsc ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 12, color: Theme.of(context).colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDataRow(Map<String, dynamic> row, int index) {
    final isEven = index.isEven;
    return Container(
      height: 40,
      color: isEven
          ? Theme.of(context).colorScheme.surface
          : Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
      child: Row(
        children: [
          ...sampleColumns.map((col) => _buildDataCell(row, col)),
          // Action buttons
          SizedBox(
            width: 80,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.open_in_new, size: 16),
                  tooltip: 'Open detail',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: () => _openDetail(row),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                  tooltip: 'Delete',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: () => _deleteRow(row),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataCell(Map<String, dynamic> row, ColDef col) {
    final isEditing = _editingCell?['rowId'] == row['id'] &&
        _editingCell?['key'] == col.key;

    return GestureDetector(
      onDoubleTap: col.readOnly
          ? null
          : () {
              setState(() {
                _editingCell = {'rowId': row['id'], 'key': col.key};
                _editController.text = row[col.key]?.toString() ?? '';
              });
            },
      child: Container(
        width: col.width,
        height: 40,
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: Colors.grey.shade200)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: isEditing
            ? Center(
                child: TextField(
                  controller: _editController,
                  autofocus: true,
                  style: const TextStyle(fontSize: 12),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (v) => _commitEdit(row, col.key, v),
                  onTapOutside: (_) => _commitEdit(row, col.key, _editController.text),
                ),
              )
            : Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  row[col.key]?.toString() ?? '',
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
      ),
    );
  }
}