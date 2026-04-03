// label_print_page.dart — Part of label_page.dart.
// Print full page: batch record selection, live preview, ZPL/QL dispatch.
// Widgets: _PrintLabelPage.

part of '../label_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Print full page — record selection, filtering, live preview, print dispatch
// ─────────────────────────────────────────────────────────────────────────────
class _PrintLabelPage extends StatefulWidget {
  final LabelTemplate template;
  final List<PrinterProfile> profiles;
  final PrinterProfile? activeProfile;
  final void Function(PrinterProfile) onProfileChanged;
  final List<Map<String, dynamic>> initialRecords;
  final String entityType;

  const _PrintLabelPage({
    required this.template,
    required this.profiles,
    required this.activeProfile,
    required this.onProfileChanged,
    this.initialRecords = const [],
    this.entityType = 'General',
  });

  @override
  State<_PrintLabelPage> createState() => _PrintLabelPageState();
}

class _PrintLabelPageState extends State<_PrintLabelPage> {
  late PrinterProfile? _activeProfile;
  _ConnState _connState = _ConnState.checking;

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

  double? get _printableW {
    final p = _activeProfile;
    if (p == null) return null;
    if (p.protocol != 'brother_ql' && p.protocol != 'brother_ql_legacy') return null;
    if (p.protocol == 'brother_ql_legacy') {
      return _ql570PrintableWidthMm(widget.template, p.toPrinterConfig());
    }
    return _ql700PrintableWidthMm(widget.template.labelW, p.dpi);
  }

  double? get _printableH {
    final p = _activeProfile;
    if (p == null) return null;
    if (p.protocol != 'brother_ql' && p.protocol != 'brother_ql_legacy') return null;
    return (widget.template.labelH - 3.0).clamp(1.0, widget.template.labelH);
  }

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

  int get _totalLabels {
    final selected = _selectedRecords.length;
    if (_records.isNotEmpty && selected == 0) return 0;
    return (selected == 0 ? 1 : selected) * widget.template.copies;
  }

  Map<String, dynamic> get _previewData {
    final display = _displayRecords;
    if (display.isEmpty) return _sampleDataFor(widget.entityType);
    return display[_previewIndex.clamp(0, display.length - 1)];
  }

  @override
  void initState() {
    super.initState();
    _activeProfile = widget.activeProfile;
    _checkConnection();
    _loadPrefs();
    if (widget.initialRecords.isNotEmpty) {
      _records = List.from(widget.initialRecords);
      _injectQr(_records, widget.entityType);
      _selectedIds = {};
    } else {
      _loadFromDb();
    }
  }

  Future<void> _checkConnection() async {
    if (!mounted) return;
    setState(() => _connState = _ConnState.checking);
    final cfg = _activeProfile?.toPrinterConfig() ?? PrinterConfig();
    final state = await _checkPrinterConnection(cfg);
    if (mounted) setState(() => _connState = state);
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
    if (_records.isNotEmpty && _selectedRecords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Select at least one record to print'),
        backgroundColor: const Color(0xFFF59E0B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
      return;
    }
    final cfg = _activeProfile?.toPrinterConfig() ?? PrinterConfig();
    final proto = (cfg.protocol == 'brother_ql' || cfg.protocol == 'brother_ql_legacy')
        ? 'Brother QL' : 'ZPL';
    setState(() { _isPrinting = true; _status = 'Generating $proto data…'; });
    try {
      final batch =
          _selectedRecords.isEmpty ? <Map<String, dynamic>>[] : _selectedRecords;
      setState(() => _status = 'Connecting to ${cfg.ipAddress}…');
      final tpl = _activeProfile?.applyTo(widget.template) ?? widget.template;
      await _sendToPrinter(tpl, batch, cfg);
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
        backgroundColor: context.appSurface,
        iconTheme: IconThemeData(color: context.appTextPrimary),
        title: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.template.name,
                  style: TextStyle(
                      color: context.appTextPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
              Text(
                '${widget.template.labelW.toInt()}×${widget.template.labelH.toInt()} mm · ${widget.entityType}',
                style: TextStyle(color: context.appTextSecondary, fontSize: 11),
              ),
            ]),
          ),
          if (widget.profiles.isNotEmpty) ...[
            _ProfileSwitcherChip(
              profiles: widget.profiles,
              activeProfile: _activeProfile,
              onSelect: (p) {
                setState(() => _activeProfile = p);
                widget.onProfileChanged(p);
                _checkConnection();
              },
            ),
            const SizedBox(width: 10),
          ],
          GestureDetector(
            onTap: _checkConnection,
            child: Tooltip(
              message: switch (_connState) {
                _ConnState.checking    => 'Checking printer…',
                _ConnState.connected   => 'Connected',
                _ConnState.driverOnly  => 'Driver installed — printer offline',
                _ConnState.unreachable => 'Printer not found — tap to retry',
              },
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                _ConnDot(AppDS.green,             lit: _connState == _ConnState.connected),
                const SizedBox(width: 4),
                _ConnDot(const Color(0xFFF59E0B), lit: _connState == _ConnState.driverOnly),
                const SizedBox(width: 4),
                _ConnDot(AppDS.red,               lit: _connState == _ConnState.unreachable),
              ]),
            ),
          ),
          const SizedBox(width: 8),
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
              onPressed: _isPrinting || _totalLabels == 0 ? null : _doPrint,
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
              child: SingleChildScrollView(
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
                        printableW: _printableW,
                        printableH: _printableH,
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
