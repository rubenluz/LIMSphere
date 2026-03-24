// label_print_dialog.dart - Part of label_page.dart.
// Print full page: batch record selection, search/filter, live preview, ZPL/QL dispatch.
// Widgets: _PrintLabelPage, _FilterBar, _RecordList, _EmptyRecordsPanel.

part of 'label_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Print full page — record selection, filtering, live preview, print dispatch
// ─────────────────────────────────────────────────────────────────────────────
class _PrintLabelPage extends StatefulWidget {
  final LabelTemplate template;
  final PrinterConfig printer;
  final List<Map<String, dynamic>> initialRecords;
  final String entityType;

  const _PrintLabelPage({
    required this.template,
    required this.printer,
    this.initialRecords = const [],
    this.entityType = 'General',
  });

  @override
  State<_PrintLabelPage> createState() => _PrintLabelPageState();
}

class _PrintLabelPageState extends State<_PrintLabelPage> {
  List<Map<String, dynamic>> _records = [];
  Set<dynamic> _selectedIds = {};
  int _previewIndex = 0;
  bool _loading = false;
  bool _isPrinting = false;
  String? _status;

  String _search = '';
  String _statusFilter = '';
  final _activeFilters = <_ActiveFilter>[];
  final _activeSorts = <_SortConfig>[];
  final _searchCtrl = TextEditingController();

  String get _idCol => _idColForCategory(widget.entityType);

  String? get _filterCol => switch (widget.entityType) {
    'Strains'   => 'strain_status',
    'Stocks'    => 'fish_stocks_status',
    'Equipment' => 'eq_status',
    'Samples'   => 'sample_type',
    _ => null,
  };

  String? get _sortCol => switch (widget.entityType) {
    'Strains'   => 'strain_code',
    'Reagents'  => 'reagent_code',
    'Equipment' => 'eq_code',
    'Samples'   => 'sample_code',
    'Stocks'    => 'fish_stocks_tank_id',
    _ => null,
  };

  List<Map<String, dynamic>> get _displayRecords {
    var list = _records.toList();
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list
          .where((r) =>
              r.values.any((v) => v?.toString().toLowerCase().contains(q) == true))
          .toList();
    }
    if (_statusFilter.isNotEmpty) {
      final col = _filterCol;
      if (col != null) {
        list = list.where((r) => r[col]?.toString() == _statusFilter).toList();
      }
    }
    for (final f in _activeFilters) {
      list = list.where((r) {
        final rv = r[f.field]?.toString() ?? '';
        final fv = f.value;
        return switch (f.mode) {
          'contains'   => rv.toLowerCase().contains(fv.toLowerCase()),
          'startsWith' => rv.toLowerCase().startsWith(fv.toLowerCase()),
          'endsWith'   => rv.toLowerCase().endsWith(fv.toLowerCase()),
          'notEq'      => rv != fv,
          _            => rv == fv,
        };
      }).toList();
    }
    final sortPairs = _activeSorts.map((s) => (s.field, s.asc)).toList();
    if (sortPairs.isNotEmpty) {
      list.sort((a, b) {
        for (var k = 0; k < sortPairs.length; k++) {
          final field = sortPairs[k].$1;
          final asc   = sortPairs[k].$2;
          final c = _naturalCompare(a[field]?.toString() ?? '', b[field]?.toString() ?? '');
          if (c != 0) return asc ? c : -c;
        }
        return 0;
      });
    } else {
      final sc = _sortCol;
      if (sc != null) {
        list.sort((a, b) =>
            _naturalCompare(a[sc]?.toString() ?? '', b[sc]?.toString() ?? ''));
      }
    }
    return list;
  }

  List<Map<String, dynamic>> get _selectedRecords =>
      _displayRecords.where((r) => _selectedIds.contains(r[_idCol])).toList();

  List<String> get _filterOptions {
    final col = _filterCol;
    if (col == null) return [];
    return (_records
            .map((r) => r[col]?.toString() ?? '')
            .where((v) => v.isNotEmpty)
            .toSet()
            .toList()
          ..sort());
  }

  int get _totalLabels =>
      (_selectedRecords.isEmpty ? 1 : _selectedRecords.length) *
      widget.template.copies;

  Map<String, dynamic> get _previewData {
    final display = _displayRecords;
    if (display.isEmpty) return _sampleDataFor(widget.entityType);
    return display[_previewIndex.clamp(0, display.length - 1)];
  }

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    if (widget.initialRecords.isNotEmpty) {
      _records = List.from(widget.initialRecords);
      _selectedIds = {};
    } else {
      _loadFromDb();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _search = prefs.getString('print_search_${widget.entityType}') ?? '';
      _statusFilter = prefs.getString('print_status_${widget.entityType}') ?? '';
      _searchCtrl.text = _search;
      final filtersRaw = prefs.getStringList('print_filters_${widget.entityType}') ?? [];
      _activeFilters
        ..clear()
        ..addAll(filtersRaw.map(_ActiveFilter.fromEncoded).whereType<_ActiveFilter>());
      final sortsRaw = prefs.getStringList('print_sorts_${widget.entityType}') ?? [];
      _activeSorts
        ..clear()
        ..addAll(sortsRaw.map(_SortConfig.fromEncoded).whereType<_SortConfig>());
    });
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('print_search_${widget.entityType}', _search);
    await prefs.setString('print_status_${widget.entityType}', _statusFilter);
    await prefs.setStringList('print_filters_${widget.entityType}',
        _activeFilters.map((f) => f.encoded).toList());
    await prefs.setStringList('print_sorts_${widget.entityType}',
        _activeSorts.map((s) => s.encoded).toList());
  }

  Future<void> _loadFromDb() async {
    setState(() { _loading = true; _status = null; });
    try {
      final rows = await Supabase.instance.client
          .from(_tableForEntity(widget.entityType))
          .select(_selectForCategory(widget.entityType)) as List<dynamic>;
      final records = rows.map(_flattenJoins).toList();
      _injectQr(records, widget.entityType);
      if (!mounted) return;
      setState(() {
        _records = records;
        _selectedIds = {};
        _previewIndex = 0;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _status = 'Failed to load: $e'; });
    }
  }

  Future<void> _doPrint() async {
    if (_isPrinting) return;
    final proto = (widget.printer.protocol == 'brother_ql' ||
            widget.printer.protocol == 'brother_ql_legacy')
        ? 'Brother QL'
        : 'ZPL';
    setState(() { _isPrinting = true; _status = 'Generating $proto data…'; });
    try {
      final batch =
          _selectedRecords.isEmpty ? <Map<String, dynamic>>[] : _selectedRecords;
      setState(() => _status = 'Connecting to ${widget.printer.ipAddress}…');
      await _sendToPrinter(widget.template, batch, widget.printer);
      final n = _totalLabels;
      if (!mounted) return;
      setState(() {
        _isPrinting = false;
        _status = 'Sent $n label${n != 1 ? 's' : ''} to printer ✓';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _isPrinting = false; _status = 'Error: $e'; });
    }
  }

  void _toggleAll() {
    final display = _displayRecords;
    final displayIds = display.map((r) => r[_idCol]).toSet();
    final allSel = displayIds.every(_selectedIds.contains);
    setState(() {
      if (allSel) {
        _selectedIds.removeAll(displayIds);
      } else {
        _selectedIds.addAll(displayIds);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final display = _displayRecords;
    final hasRecords = _records.isNotEmpty;
    final isError = _status != null && _status!.startsWith('Error');
    final isDone  = _status != null && _status!.contains('✓');

    return Scaffold(
      backgroundColor: context.appBg,
      appBar: AppBar(
        backgroundColor: AppDS.bg,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.template.name,
              style: const TextStyle(
                  color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
          Text(
            '${widget.template.labelW.toInt()}×${widget.template.labelH.toInt()} mm · ${widget.entityType}',
            style: const TextStyle(color: AppDS.textSecondary, fontSize: 11),
          ),
        ]),
        actions: [
          if (_status != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Center(
                child: Text(_status!,
                    style: TextStyle(
                        fontSize: 12,
                        color: isError
                            ? AppDS.red
                            : isDone
                                ? AppDS.green
                                : AppDS.textSecondary)),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: AppDS.accent,
                  foregroundColor: AppDS.bg,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
              icon: _isPrinting
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          color: AppDS.bg, strokeWidth: 2))
                  : const Icon(Icons.print_rounded, size: 15),
              label: Text(
                  _isPrinting
                      ? 'Printing…'
                      : 'Print $_totalLabels label${_totalLabels != 1 ? 's' : ''}',
                  style: const TextStyle(fontSize: 13)),
              onPressed: _isPrinting ? null : _doPrint,
            ),
          ),
        ],
      ),
      body: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Left: label preview ──────────────────────────────────────────────
        Container(
          width: 260,
          color: const Color(0xFF0A0F1A),
          child: Column(children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 12)
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _PreviewCanvas(
                        template: widget.template,
                        scale: 3.0,
                        sampleData: _previewData,
                      ),
                    ),
                    if (!hasRecords) ...[
                      const SizedBox(height: 10),
                      const Text('Sample preview',
                          style: TextStyle(
                              fontSize: 10, color: AppDS.textSecondary)),
                    ],
                  ]),
                ),
              ),
            ),
            if (display.isNotEmpty)
              Container(
                color: AppDS.surface,
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded, size: 18),
                    color: AppDS.textSecondary,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: _previewIndex > 0
                        ? () => setState(() => _previewIndex--)
                        : null,
                  ),
                  Expanded(
                    child: Text(
                      '${_previewIndex + 1} / ${display.length}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 11, color: AppDS.textSecondary),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded, size: 18),
                    color: AppDS.textSecondary,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: _previewIndex < display.length - 1
                        ? () => setState(() => _previewIndex++)
                        : null,
                  ),
                ]),
              ),
          ]),
        ),
        VerticalDivider(width: 1, color: context.appBorder),

        // ── Right: filter bar + record list ─────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                      color: AppDS.accent, strokeWidth: 2))
              : Column(children: [
                  _FilterBar(
                    search: _search,
                    searchCtrl: _searchCtrl,
                    statusFilter: _statusFilter,
                    filterOptions: _filterOptions,
                    filterLabel: _filterLabelFor(widget.entityType),
                    hasRecords: hasRecords,
                    records: _records,
                    allFields: _allColsForCategory(widget.entityType),
                    activeFilters: _activeFilters,
                    activeSorts: _activeSorts,
                    onLoad: _loadFromDb,
                    onSearchChanged: (v) {
                      setState(() { _search = v; _previewIndex = 0; });
                      _savePrefs();
                    },
                    onStatusChanged: (v) {
                      setState(() { _statusFilter = v ?? ''; _previewIndex = 0; });
                      _savePrefs();
                    },
                    onAddFilter: (f) {
                      setState(() { _activeFilters.add(f); _previewIndex = 0; });
                      _savePrefs();
                    },
                    onRemoveFilter: (i) {
                      setState(() { _activeFilters.removeAt(i); _previewIndex = 0; });
                      _savePrefs();
                    },
                    onAddSort: (s) {
                      setState(() { _activeSorts.add(s); _previewIndex = 0; });
                      _savePrefs();
                    },
                    onRemoveSort: (i) {
                      setState(() { _activeSorts.removeAt(i); _previewIndex = 0; });
                      _savePrefs();
                    },
                    onToggleSortDir: (i) {
                      setState(() => _activeSorts[i] = _activeSorts[i].toggled());
                      _savePrefs();
                    },
                  ),
                  Divider(height: 1, color: context.appBorder),
                  if (!hasRecords)
                    Expanded(
                        child: _EmptyRecordsPanel(
                            entityType: widget.entityType, onLoad: _loadFromDb))
                  else if (display.isEmpty)
                    Expanded(
                      child: Center(
                        child: Text('No records match the filter.',
                            style: TextStyle(
                                fontSize: 13,
                                color: context.appTextSecondary)),
                      ),
                    )
                  else
                    Expanded(
                      child: _RecordList(
                        records: display,
                        selectedIds: _selectedIds,
                        idCol: _idCol,
                        previewIndex: _previewIndex,
                        entityType: widget.entityType,
                        onToggle: (r) {
                          final id = r[_idCol];
                          setState(() {
                            if (_selectedIds.contains(id)) {
                              _selectedIds.remove(id);
                            } else {
                              _selectedIds.add(id);
                            }
                          });
                        },
                        onToggleAll: _toggleAll,
                        onTapRow: (i) => setState(() => _previewIndex = i),
                      ),
                    ),
                  Divider(height: 1, color: context.appBorder),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: Row(children: [
                      Text(
                        hasRecords
                            ? '${_selectedRecords.length} of ${display.length} shown · ${_records.length} total · $_totalLabels label${_totalLabels != 1 ? 's' : ''}'
                            : 'No records loaded — printing will use sample data',
                        style: TextStyle(
                            fontSize: 11,
                            color: context.appTextSecondary),
                      ),
                    ]),
                  ),
                ]),
        ),
      ]),
    );
  }
}

int _naturalCompare(String a, String b) {
  final re = RegExp(r'\d+');
  int i = 0, j = 0;
  while (i < a.length && j < b.length) {
    final ma = re.matchAsPrefix(a, i);
    final mb = re.matchAsPrefix(b, j);
    if (ma != null && mb != null) {
      final na = int.parse(ma.group(0)!);
      final nb = int.parse(mb.group(0)!);
      if (na != nb) return na.compareTo(nb);
      i = ma.end; j = mb.end;
    } else {
      final ca = a.codeUnitAt(i);
      final cb = b.codeUnitAt(j);
      if (ca != cb) return ca.compareTo(cb);
      i++; j++;
    }
  }
  return a.length.compareTo(b.length);
}

String _filterLabelFor(String entityType) => switch (entityType) {
  'Strains'   => 'Status',
  'Stocks'    => 'Status',
  'Equipment' => 'Status',
  'Samples'   => 'Type',
  _ => '',
};

// ─────────────────────────────────────────────────────────────────────────────
// Filter bar — search, active-filter chips, add-filter row, quick values, sort
// ─────────────────────────────────────────────────────────────────────────────
class _FilterBar extends StatefulWidget {
  final String search;
  final TextEditingController searchCtrl;
  final String statusFilter;
  final List<String> filterOptions;
  final String filterLabel;
  final bool hasRecords;
  final List<Map<String, dynamic>> records;
  final List<String> allFields;
  final List<_ActiveFilter> activeFilters;
  final List<_SortConfig> activeSorts;
  final VoidCallback onLoad;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onStatusChanged;
  final void Function(_ActiveFilter) onAddFilter;
  final void Function(int) onRemoveFilter;
  final void Function(_SortConfig) onAddSort;
  final void Function(int) onRemoveSort;
  final void Function(int) onToggleSortDir;

  const _FilterBar({
    required this.search,
    required this.searchCtrl,
    required this.statusFilter,
    required this.filterOptions,
    required this.filterLabel,
    required this.hasRecords,
    required this.records,
    required this.allFields,
    required this.activeFilters,
    required this.activeSorts,
    required this.onLoad,
    required this.onSearchChanged,
    required this.onStatusChanged,
    required this.onAddFilter,
    required this.onRemoveFilter,
    required this.onAddSort,
    required this.onRemoveSort,
    required this.onToggleSortDir,
  });

  @override
  State<_FilterBar> createState() => _FilterBarState();
}

class _FilterBarState extends State<_FilterBar> {
  String? _field;
  String _mode = 'eq';
  final _valueCtrl = TextEditingController();
  String? _sortField;
  bool _sortAscending = true;
  int _sortAutoKey = 0;

  @override
  void dispose() {
    _valueCtrl.dispose();
    super.dispose();
  }

  List<String> get _quickValues {
    if (_field == null || widget.records.isEmpty) return [];
    return widget.records
        .map((r) => r[_field!]?.toString() ?? '')
        .where((v) => v.isNotEmpty)
        .toSet()
        .toList()
      ..sort(_naturalCompare);
  }

  void _addFilter() {
    final v = _valueCtrl.text.trim();
    if (_field == null || v.isEmpty) return;
    widget.onAddFilter(_ActiveFilter(_field!, _mode, v));
    _valueCtrl.clear();
  }

  void _addQuick(String value) {
    if (_field == null) return;
    widget.onAddFilter(_ActiveFilter(_field!, _mode, value));
  }

  void _addSort() {
    if (_sortField == null) return;
    widget.onAddSort(_SortConfig(_sortField!, asc: _sortAscending));
    setState(() { _sortField = null; _sortAutoKey++; });
  }

  Widget _modeBtn(BuildContext ctx, String m) {
    final active = _mode == m;
    final label = switch (m) {
      'notEq'      => 'is not',
      'contains'   => 'contains',
      'startsWith' => 'starts',
      'endsWith'   => 'ends',
      _            => 'is',
    };
    return GestureDetector(
      onTap: () => setState(() => _mode = m),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: active ? AppDS.accent.withValues(alpha: 0.2) : ctx.appBg,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: active ? AppDS.accent : ctx.appBorder),
        ),
        child: Text(label,
            style: TextStyle(fontSize: 10,
                color: active ? AppDS.accent : ctx.appTextSecondary,
                fontWeight: FontWeight.bold)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final qv = _quickValues;
    return Container(
      color: context.appSurface,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Row 1: search + status + load ──────────────────────────────
          Row(children: [
            Expanded(
              child: TextField(
                controller: widget.searchCtrl,
                style: TextStyle(fontSize: 13, color: context.appTextPrimary),
                decoration: InputDecoration(
                  hintText: 'Search…',
                  hintStyle: TextStyle(color: context.appTextMuted, fontSize: 13),
                  prefixIcon: Icon(Icons.search_rounded, size: 16, color: context.appTextMuted),
                  suffixIcon: widget.search.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear_rounded, size: 14, color: context.appTextSecondary),
                          onPressed: () { widget.searchCtrl.clear(); widget.onSearchChanged(''); })
                      : null,
                  isDense: true, filled: true, fillColor: context.appSurface2,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: context.appBorder)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: context.appBorder)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppDS.accent, width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                onChanged: widget.onSearchChanged,
              ),
            ),
            if (widget.filterLabel.isNotEmpty && widget.filterOptions.isNotEmpty) ...[
              const SizedBox(width: 8),
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: widget.statusFilter.isEmpty ? null : widget.statusFilter,
                  hint: Text(widget.filterLabel,
                      style: TextStyle(color: context.appTextMuted, fontSize: 12)),
                  dropdownColor: context.appSurface2,
                  style: TextStyle(color: context.appTextPrimary, fontSize: 12),
                  items: [
                    DropdownMenuItem<String>(value: '',
                        child: Text('All ${widget.filterLabel}',
                            style: TextStyle(color: context.appTextSecondary, fontSize: 12))),
                    ...widget.filterOptions.map((v) =>
                        DropdownMenuItem<String>(value: v, child: Text(v))),
                  ],
                  onChanged: widget.onStatusChanged,
                ),
              ),
            ],
            const SizedBox(width: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                  foregroundColor: AppDS.accent,
                  side: const BorderSide(color: AppDS.accent),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
              icon: const Icon(Icons.refresh_rounded, size: 14),
              label: Text(widget.hasRecords ? 'Reload' : 'Load',
                  style: const TextStyle(fontSize: 12)),
              onPressed: widget.onLoad,
            ),
          ]),

          if (widget.allFields.isNotEmpty) ...[
            // ── Active filter chips ─────────────────────────────────────
            if (widget.activeFilters.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 4, children: [
                for (var i = 0; i < widget.activeFilters.length; i++)
                  _FilterChip(filter: widget.activeFilters[i], onRemove: () => widget.onRemoveFilter(i)),
              ]),
            ],

            // ── Add filter row: field | mode | value | + ────────────────
            const SizedBox(height: 6),
            Row(children: [
              Text('Filter by:', style: TextStyle(fontSize: 10,
                  color: context.appTextSecondary, fontWeight: FontWeight.w600)),
              const SizedBox(width: 6),
              SizedBox(
                width: 160,
                child: Autocomplete<String>(
                  optionsBuilder: (v) {
                    final q = v.text.toLowerCase();
                    return q.isEmpty
                        ? widget.allFields
                        : widget.allFields.where((c) =>
                            _colLabel(c).toLowerCase().contains(q) ||
                            c.toLowerCase().contains(q));
                  },
                  displayStringForOption: _colLabel,
                  onSelected: (col) => setState(() => _field = col),
                  optionsViewBuilder: (ctx, onSel, opts) => Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        width: 200,
                        constraints: const BoxConstraints(maxHeight: 220),
                        decoration: BoxDecoration(
                          color: AppDS.surface2,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppDS.border),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8)],
                        ),
                        child: ListView(shrinkWrap: true, children: opts.map((col) =>
                          InkWell(
                            onTap: () => onSel(col),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Text(_colLabel(col),
                                  style: const TextStyle(fontSize: 11, color: AppDS.textPrimary)),
                            ),
                          ),
                        ).toList()),
                      ),
                    ),
                  ),
                  fieldViewBuilder: (ctx, ctrl, focus, _) => TextField(
                    controller: ctrl,
                    focusNode: focus,
                    style: TextStyle(fontSize: 11, color: ctx.appTextPrimary),
                    decoration: InputDecoration(
                      hintText: 'Filter field…',
                      hintStyle: TextStyle(color: ctx.appTextMuted, fontSize: 11),
                      isDense: true, filled: true, fillColor: ctx.appBg,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: ctx.appBorder)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: ctx.appBorder)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(color: AppDS.accent)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      suffixIcon: _field != null
                          ? GestureDetector(
                              onTap: () { ctrl.clear(); setState(() => _field = null); },
                              child: Icon(Icons.clear_rounded, size: 12, color: ctx.appTextSecondary))
                          : null,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _modeBtn(context, 'eq'),
              const SizedBox(width: 2),
              _modeBtn(context, 'notEq'),
              const SizedBox(width: 2),
              _modeBtn(context, 'contains'),
              const SizedBox(width: 2),
              _modeBtn(context, 'startsWith'),
              const SizedBox(width: 2),
              _modeBtn(context, 'endsWith'),
              const SizedBox(width: 6),
              SizedBox(
                width: 120,
                child: TextField(
                  controller: _valueCtrl,
                  style: TextStyle(fontSize: 11, color: context.appTextPrimary),
                  decoration: InputDecoration(
                    hintText: 'Value…',
                    hintStyle: TextStyle(color: context.appTextMuted, fontSize: 11),
                    isDense: true, filled: true, fillColor: context.appBg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: context.appBorder)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: context.appBorder)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: AppDS.accent)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  ),
                  onSubmitted: (_) => _addFilter(),
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: _addFilter,
                child: Container(
                  width: 26, height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppDS.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppDS.accent),
                  ),
                  child: const Icon(Icons.add_rounded, size: 16, color: AppDS.accent),
                ),
              ),
            ]),

            // ── Quick values + Sort ─────────────────────────────────────
            const SizedBox(height: 6),
            Row(children: [
              if (qv.isNotEmpty) ...[
                Text('Quick:', style: TextStyle(fontSize: 10,
                    color: context.appTextSecondary, fontWeight: FontWeight.w600)),
                const SizedBox(width: 4),
                Flexible(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: qv.take(25).map((v) =>
                      GestureDetector(
                        onTap: () => _addQuick(v),
                        child: Container(
                          margin: const EdgeInsets.only(right: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppDS.surface3,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppDS.border),
                          ),
                          child: Text(v, style: const TextStyle(fontSize: 10, color: AppDS.textPrimary)),
                        ),
                      ),
                    ).toList()),
                  ),
                ),
                SizedBox(height: 16, child: VerticalDivider(color: context.appBorder, indent: 0, endIndent: 0)),
                const SizedBox(width: 8),
              ],
            ]),

            // sort chips
            if (widget.activeSorts.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 4, children: [
                for (var i = 0; i < widget.activeSorts.length; i++)
                  _SortChip(
                    sort: widget.activeSorts[i],
                    onRemove: () => widget.onRemoveSort(i),
                    onToggleDir: () => widget.onToggleSortDir(i),
                  ),
              ]),
            ],

            // add sort row
            const SizedBox(height: 6),
            Row(children: [
              Text('Sort by:', style: TextStyle(fontSize: 10,
                  color: context.appTextSecondary, fontWeight: FontWeight.w600)),
              const SizedBox(width: 4),
              SizedBox(
                width: 160,
                child: Autocomplete<String>(
                  key: ValueKey(_sortAutoKey),
                  optionsBuilder: (v) {
                    final q = v.text.toLowerCase();
                    final used = widget.activeSorts.map((s) => s.field).toSet();
                    final available = widget.allFields.where((c) => !used.contains(c));
                    return q.isEmpty
                        ? available
                        : available.where((c) =>
                            _colLabel(c).toLowerCase().contains(q) ||
                            c.toLowerCase().contains(q));
                  },
                  displayStringForOption: _colLabel,
                  onSelected: (col) => setState(() => _sortField = col),
                  optionsViewBuilder: (ctx, onSel, opts) => Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        width: 200,
                        constraints: const BoxConstraints(maxHeight: 200),
                        decoration: BoxDecoration(
                          color: AppDS.surface2,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppDS.border),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8)],
                        ),
                        child: ListView(shrinkWrap: true, children: opts.map((col) =>
                          InkWell(
                            onTap: () => onSel(col),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Text(_colLabel(col),
                                  style: const TextStyle(fontSize: 11, color: AppDS.textPrimary)),
                            ),
                          ),
                        ).toList()),
                      ),
                    ),
                  ),
                  fieldViewBuilder: (ctx, ctrl, focus, _) => TextField(
                    controller: ctrl,
                    focusNode: focus,
                    style: TextStyle(fontSize: 11, color: ctx.appTextPrimary),
                    decoration: InputDecoration(
                      hintText: 'Sort field…',
                      hintStyle: TextStyle(color: ctx.appTextMuted, fontSize: 11),
                      isDense: true, filled: true, fillColor: ctx.appBg,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: ctx.appBorder)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: ctx.appBorder)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(color: AppDS.purple)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      suffixIcon: _sortField != null
                          ? GestureDetector(
                              onTap: () { ctrl.clear(); setState(() => _sortField = null); },
                              child: Icon(Icons.clear_rounded, size: 12, color: ctx.appTextSecondary))
                          : null,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => setState(() => _sortAscending = !_sortAscending),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: context.appBg,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: context.appBorder),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(_sortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                        size: 12, color: context.appTextSecondary),
                    const SizedBox(width: 3),
                    Text(_sortAscending ? 'A→Z' : 'Z→A',
                        style: TextStyle(fontSize: 10, color: context.appTextSecondary)),
                  ]),
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: _addSort,
                child: Container(
                  width: 26, height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppDS.purple.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppDS.purple),
                  ),
                  child: const Icon(Icons.add_rounded, size: 16, color: AppDS.purple),
                ),
              ),
            ]),
          ],
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final _ActiveFilter filter;
  final VoidCallback onRemove;
  const _FilterChip({required this.filter, required this.onRemove});

  String get _modeLabel => switch (filter.mode) {
    'notEq'      => 'is not',
    'contains'   => 'contains',
    'startsWith' => 'starts',
    'endsWith'   => 'ends',
    _            => 'is',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 3, 4, 3),
      decoration: BoxDecoration(
        color: AppDS.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppDS.accent.withValues(alpha: 0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('${_colLabel(filter.field)} $_modeLabel ${filter.value}',
            style: const TextStyle(fontSize: 10, color: AppDS.accent)),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: onRemove,
          child: const Icon(Icons.close_rounded, size: 12, color: AppDS.accent),
        ),
      ]),
    );
  }
}

class _SortChip extends StatelessWidget {
  final _SortConfig sort;
  final VoidCallback onRemove;
  final VoidCallback onToggleDir;
  const _SortChip({required this.sort, required this.onRemove, required this.onToggleDir});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 3, 4, 3),
      decoration: BoxDecoration(
        color: AppDS.purple.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppDS.purple.withValues(alpha: 0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(_colLabel(sort.field),
            style: const TextStyle(fontSize: 10, color: AppDS.purple)),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: onToggleDir,
          child: Icon(
            sort.asc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            size: 12, color: AppDS.purple,
          ),
        ),
        const SizedBox(width: 2),
        GestureDetector(
          onTap: onRemove,
          child: const Icon(Icons.close_rounded, size: 12, color: AppDS.purple),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Record list — shows filtered records with select checkboxes
// ─────────────────────────────────────────────────────────────────────────────
class _RecordList extends StatelessWidget {
  final List<Map<String, dynamic>> records;
  final Set<dynamic> selectedIds;
  final String idCol;
  final int previewIndex;
  final String entityType;
  final void Function(Map<String, dynamic>) onToggle;
  final VoidCallback onToggleAll;
  final void Function(int) onTapRow;

  const _RecordList({
    required this.records,
    required this.selectedIds,
    required this.idCol,
    required this.previewIndex,
    required this.entityType,
    required this.onToggle,
    required this.onToggleAll,
    required this.onTapRow,
  });

  // Top line: scientific name for strains, code/id otherwise
  String _recordLabel(Map<String, dynamic> r) {
    if (entityType == 'Strains') {
      final sci = r['strain_scientific_name'];
      if (sci != null && sci.toString().isNotEmpty) return sci.toString();
    }
    for (final k in [
      'strain_code', 'reagent_code', 'eq_code', 'sample_code',
      'fish_stocks_tank_id', 'code', 'name', 'id',
    ]) {
      final v = r[k];
      if (v != null && v.toString().isNotEmpty) return v.toString();
    }
    return r.values.firstOrNull?.toString() ?? '—';
  }

  // Bottom line: "code · medium" for strains, otherwise name/type
  String _recordSubLabel(Map<String, dynamic> r) {
    if (entityType == 'Strains') {
      final code   = r['strain_code']?.toString() ?? '';
      final medium = r['strain_medium']?.toString() ?? '';
      if (code.isNotEmpty && medium.isNotEmpty) return '$code · $medium';
      if (code.isNotEmpty) return code;
    }
    for (final k in [
      'reagent_name', 'eq_name', 'sample_type',
      'fish_stocks_line', 'name', 'type',
    ]) {
      final v = r[k];
      if (v != null && v.toString().isNotEmpty) return v.toString();
    }
    return '';
  }

  Widget _scientificNameWidget(String name, TextStyle base) =>
      _scientificNameText(name, base, overflow: TextOverflow.ellipsis);

  @override
  Widget build(BuildContext context) {
    final allSelected = records.every((r) => selectedIds.contains(r[idCol]));
    final selCount = records.where((r) => selectedIds.contains(r[idCol])).length;
    return Column(children: [
      InkWell(
        onTap: onToggleAll,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          color: context.appSurface,
          child: Row(children: [
            Icon(
              allSelected
                  ? Icons.check_box_rounded
                  : Icons.check_box_outline_blank_rounded,
              size: 17,
              color: allSelected ? AppDS.accent : context.appTextSecondary,
            ),
            const SizedBox(width: 10),
            Text(allSelected ? 'Deselect all' : 'Select all',
                style: TextStyle(
                    fontSize: 12, color: context.appTextSecondary)),
            const Spacer(),
            Text('$selCount/${records.length}',
                style: TextStyle(
                    fontSize: 11, color: context.appTextSecondary)),
          ]),
        ),
      ),
      Divider(height: 1, color: context.appBorder),
      Expanded(
        child: ListView.builder(
          itemCount: records.length,
          itemBuilder: (ctx, i) {
            final r = records[i];
            final id = r[idCol];
            final isSel = selectedIds.contains(id);
            final isPreview = i == previewIndex;
            return InkWell(
              onTap: () => onTapRow(i),
              child: Container(
                color: isPreview
                    ? AppDS.accent.withValues(alpha: 0.08)
                    : Colors.transparent,
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => onToggle(r),
                    child: Icon(
                      isSel
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded,
                      size: 16,
                      color:
                          isSel ? AppDS.accent : ctx.appTextSecondary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      if (entityType == 'Strains')
                        _scientificNameWidget(
                          _recordLabel(r),
                          TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isPreview ? AppDS.accent : ctx.appTextPrimary),
                        )
                      else
                        Text(
                          _recordLabel(r),
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isPreview ? AppDS.accent : ctx.appTextPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (_recordSubLabel(r).isNotEmpty)
                        Text(
                          _recordSubLabel(r),
                          style: TextStyle(
                              fontSize: 10,
                              color: ctx.appTextSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ]),
                  ),
                  if (isPreview)
                    const Icon(Icons.visibility_rounded,
                        size: 13, color: AppDS.accent),
                ]),
              ),
            );
          },
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty records state
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyRecordsPanel extends StatelessWidget {
  final String entityType;
  final VoidCallback onLoad;
  const _EmptyRecordsPanel({required this.entityType, required this.onLoad});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.table_rows_outlined,
              size: 40, color: context.appTextSecondary),
          const SizedBox(height: 14),
          Text('No records loaded',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.appTextPrimary)),
          const SizedBox(height: 6),
          Text(
            'Load $entityType from the database to print with real data,\nor print now using sample placeholder values.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: context.appTextSecondary),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
                foregroundColor: AppDS.accent,
                side: const BorderSide(color: AppDS.accent)),
            icon: const Icon(Icons.download_rounded, size: 15),
            label: Text('Load all $entityType',
                style: const TextStyle(fontSize: 12)),
            onPressed: onLoad,
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Active filter model
// ─────────────────────────────────────────────────────────────────────────────
class _SortConfig {
  final String field;
  final bool asc;
  const _SortConfig(this.field, {this.asc = true});

  _SortConfig toggled() => _SortConfig(field, asc: !asc);

  String get encoded => '$field\x00${asc ? 'asc' : 'desc'}';

  static _SortConfig? fromEncoded(String s) {
    final p = s.split('\x00');
    if (p.length != 2) return null;
    return _SortConfig(p[0], asc: p[1] != 'desc');
  }
}

class _ActiveFilter {
  final String field;
  final String mode;  // eq | contains | startsWith | endsWith
  final String value;
  const _ActiveFilter(this.field, this.mode, this.value);

  String get encoded => '$field\x00$mode\x00$value';

  static _ActiveFilter? fromEncoded(String s) {
    final p = s.split('\x00');
    if (p.length != 3) return null;
    return _ActiveFilter(p[0], p[1], p[2]);
  }
}
