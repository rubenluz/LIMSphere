// fish_lines_page.dart - Fish line inventory grid: genetics info, search/filter,
// CSV export, detail page navigation.
// Dialog class in fish_lines_dialogs.dart (part).

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'fish_lines_connection_model.dart';
import '/core/fish_db_schema.dart';
import '/supabase/supabase_manager.dart';
import '../../camera/qr_scanner/qr_code_rules.dart';
import '/core/data_cache.dart';
import '../shared_widgets.dart';
import 'fish_lines_detail_page.dart';
import '/theme/theme.dart';
import '/theme/module_permission.dart';
import '/theme/grid_widgets.dart';

part 'fish_lines_dialogs.dart';



class FishLinesPage extends StatefulWidget {
  const FishLinesPage({super.key});

  @override
  State<FishLinesPage> createState() => _FishLinesPageState();
}

class _FishLinesPageState extends State<FishLinesPage> {
  List<FishLine> _lines = [];
  List<FishLine> _filtered = [];
  final _searchCtrl = TextEditingController();
  bool _loading = true;
  String? _loadError;
  String? _filterType;
  String? _filterStatus;
  String? _filterReporter;
  String _sortKey = 'fishlineName';
  bool _sortAsc = true;
  bool _showFilters = false;
  Map<String, dynamic>? _editingCell;
  final _editController = TextEditingController();

  final _vertCtrl  = ScrollController();
  final _horizCtrl = ScrollController();
  final _hOffset   = ValueNotifier<double>(0);
  final _vOffset   = ValueNotifier<double>(0);

  static const _cols = [
    ('fishlineName',         'Name',        180.0, false),
    ('fishlineDateBirth',    'DOB',         100.0, false),
    ('ageDays',              'Days',         70.0,  false),
    ('ageMonths',            'Mo.',          58.0,  false),
    ('stockMales',           '♂',            50.0,  false),
    ('stockFemales',         '♀',            50.0,  false),
    ('stockJuveniles',       'Juv',          50.0,  false),
    ('stockTotal',           'Total',        65.0,  false),
    ('fishlineType',         'Type',        100.0, false),
    ('fishlineOriginLab',    'Origin Lab',  150.0, false),
    ('fishlineAlias',        'Alias',       110.0, false),
    ('fishlineStatus',       'Status',      110.0, false),
    ('fishlineZygosity',     'Zygosity',    110.0, false),
    ('fishlineGeneration',   'Gen.',         60.0, false),
    ('fishlineAffectedGene', 'Gene',         90.0, true),
    ('fishlineReporter',     'Reporter',     80.0, false),
    ('fishlineTargetTissue', 'Tissue',      120.0, false),
    ('fishlineSource',       'Source',      100.0, false),
    ('fishlineZfinId',       'ZFIN ID',     130.0, true),
    ('fishlineCryopreserved','Cryo',         60.0, false),
    ('fishlineSpfStatus',    'SPF',          80.0, false),
    ('fishlineNotes',        'Notes',       150.0, false),
  ];

  @override
  void initState() {
    super.initState();
    _loadLines();
    _searchCtrl.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _editController.dispose();
    _vertCtrl.dispose();
    _horizCtrl.dispose();
    _hOffset.dispose();
    _vOffset.dispose();
    super.dispose();
  }

  void _aggregateStockCounts(List<Map<String, dynamic>> stockRows) {
    final countsById = <int, (int, int, int, int)>{};
    for (final r in stockRows) {
      final id = r['fish_stocks_line_id'] as int;
      final m = (r['fish_stocks_males']     as int?) ?? 0;
      final f = (r['fish_stocks_females']   as int?) ?? 0;
      final j = (r['fish_stocks_juveniles'] as int?) ?? 0;
      final prev = countsById[id] ?? (0, 0, 0, 0);
      countsById[id] = (prev.$1 + m, prev.$2 + f, prev.$3 + j, prev.$4 + m + f + j);
    }
    for (final line in _lines) {
      final c = line.fishlineId != null ? countsById[line.fishlineId] : null;
      if (c != null) {
        line.stockMales     = c.$1;
        line.stockFemales   = c.$2;
        line.stockJuveniles = c.$3;
        line.stockTotal     = c.$4;
      }
    }
  }

  Future<void> _loadLines() async {
    final cachedLines = await DataCache.read('fish_lines');
    final cachedCounts = await DataCache.read('fish_stocks_counts');
    if (cachedLines != null && cachedCounts != null && mounted) {
      _lines = cachedLines.cast<Map<String, dynamic>>().map(FishLine.fromMap).toList();
      _aggregateStockCounts(cachedCounts.cast<Map<String, dynamic>>());
      _applyFilters();
      setState(() { _loading = false; _loadError = null; });
    } else {
      setState(() { _loading = true; _loadError = null; });
    }
    try {
      final rows = (await Supabase.instance.client
          .from('fish_lines')
          .select()
          .order('fish_line_name') as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final stockRows = (await Supabase.instance.client
          .from('fish_stocks')
          .select('fish_stocks_line_id, fish_stocks_males, fish_stocks_females, fish_stocks_juveniles')
          .not('fish_stocks_line_id', 'is', null) as List<dynamic>)
          .cast<Map<String, dynamic>>();
      await DataCache.write('fish_lines', rows);
      await DataCache.write('fish_stocks_counts', stockRows);
      if (!mounted) return;
      _lines = rows.map(FishLine.fromMap).toList();
      _aggregateStockCounts(stockRows);
      _applyFilters();
      setState(() => _loading = false);
    } catch (e) {
      if (cachedLines == null && mounted) {
        setState(() { _loading = false; _loadError = e.toString(); });
      }
    }
  }

  void _applyFilters() {
    var d = _lines.toList();
    final q = _searchCtrl.text.toLowerCase();
    if (q.isNotEmpty) {
      d = d.where((r) =>
        r.fishlineName.toLowerCase().contains(q) ||
        (r.fishlineAlias?.toLowerCase().contains(q) ?? false) ||
        (r.fishlineAffectedGene?.toLowerCase().contains(q) ?? false) ||
        (r.fishlineOriginLab?.toLowerCase().contains(q) ?? false) ||
        (r.fishlineZfinId?.toLowerCase().contains(q) ?? false)
      ).toList();
    }
    if (_filterType != null) d = d.where((r) => r.fishlineType == _filterType).toList();
    if (_filterStatus != null) d = d.where((r) => r.fishlineStatus == _filterStatus).toList();
    if (_filterReporter != null) d = d.where((r) => r.fishlineReporter == _filterReporter).toList();

    d.sort((a, b) {
      dynamic av, bv;
      switch (_sortKey) {
        case 'fishlineName':       av = a.fishlineName; bv = b.fishlineName; break;
        case 'fishlineAlias':      av = a.fishlineAlias ?? ''; bv = b.fishlineAlias ?? ''; break;
        case 'fishlineType':       av = a.fishlineType ?? ''; bv = b.fishlineType ?? ''; break;
        case 'fishlineStatus':     av = a.fishlineStatus ?? ''; bv = b.fishlineStatus ?? ''; break;
        case 'fishlineZygosity':   av = a.fishlineZygosity ?? ''; bv = b.fishlineZygosity ?? ''; break;
        case 'fishlineGeneration': av = a.fishlineGeneration ?? ''; bv = b.fishlineGeneration ?? ''; break;
        case 'fishlineAffectedGene': av = a.fishlineAffectedGene ?? ''; bv = b.fishlineAffectedGene ?? ''; break;
        case 'fishlineOriginLab':  av = a.fishlineOriginLab ?? ''; bv = b.fishlineOriginLab ?? ''; break;
        case 'fishlineDateBirth':
        case 'ageDays':
        case 'ageMonths':
          av = a.fishlineDateBirth ?? DateTime(0); bv = b.fishlineDateBirth ?? DateTime(0); break;
        case 'stockMales':     av = a.stockMales;     bv = b.stockMales;     break;
        case 'stockFemales':   av = a.stockFemales;   bv = b.stockFemales;   break;
        case 'stockJuveniles': av = a.stockJuveniles; bv = b.stockJuveniles; break;
        case 'stockTotal':     av = a.stockTotal;     bv = b.stockTotal;     break;
        default: av = a.fishlineName; bv = b.fishlineName;
      }
      final c = av.toString().compareTo(bv.toString());
      return _sortAsc ? c : -c;
    });

    setState(() => _filtered = d);
  }

  void _sort(String key) {
    setState(() {
      if (_sortKey == key) {
        _sortAsc = !_sortAsc;
      } else { _sortKey = key; _sortAsc = true; }
    });
    _applyFilters();
  }


  void _openDetail(FishLine line) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => FishLineDetailPage(
        fishLine: line,
        onSaved: _loadLines,
      ),
    ));
  }

  Future<void> _exportCsv() async {
    final buf = StringBuffer();
    buf.writeln('ID,Name,Alias,Type,Status,Zygosity,Generation,Gene,Reporter,Tissue,Origin Lab,DOB,Source,ZFIN ID,Cryopreserved,SPF,Males,Females,Juveniles,Total,Notes');
    for (final l in _filtered) {
      String esc(String? v) => '"${(v ?? '').replaceAll('"', '""')}"';
      buf.writeln([
        l.fishlineId ?? '',
        esc(l.fishlineName),
        esc(l.fishlineAlias),
        esc(l.fishlineType),
        esc(l.fishlineStatus),
        esc(l.fishlineZygosity),
        esc(l.fishlineGeneration),
        esc(l.fishlineAffectedGene),
        esc(l.fishlineReporter),
        esc(l.fishlineTargetTissue),
        esc(l.fishlineOriginLab),
        l.fishlineDateBirth != null ? l.fishlineDateBirth!.toIso8601String().substring(0, 10) : '',
        esc(l.fishlineSource),
        esc(l.fishlineZfinId),
        l.fishlineCryopreserved ? 'Yes' : 'No',
        esc(l.fishlineSpfStatus),
        l.stockMales,
        l.stockFemales,
        l.stockJuveniles,
        l.stockTotal,
        esc(l.fishlineNotes),
      ].join(','));
    }
    try {
      final dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/fish_lines_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(buf.toString());
      await OpenFilex.open(file.path);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  bool get _hasActiveFilter =>
      _filterType != null || _filterStatus != null || _filterReporter != null;

  Widget _buildToolbar() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: context.appSurface2,
        border: Border(bottom: BorderSide(color: context.appBorder)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        if (MediaQuery.of(context).size.width < 700) ...[
          IconButton(
            icon: const Icon(Icons.menu_rounded, size: 20),
            color: context.appTextSecondary,
            tooltip: 'Menu',
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ],
        const Icon(Icons.science_outlined, size: 18, color: Color(0xFF7DD3FC)),
        const SizedBox(width: 8),
        Text('Fish Lines', style: GoogleFonts.spaceGrotesk(
          fontSize: 16, fontWeight: FontWeight.w600,
          color: context.appTextPrimary)),
        const SizedBox(width: 16),
        Expanded(
          child: SizedBox(
            height: 36,
            child: AppSearchBar(controller: _searchCtrl, hint: 'Search lines…', onClear: _applyFilters),
          ),
        ),
        if (MediaQuery.of(context).size.width < 700)
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: context.appTextSecondary, size: 20),
            tooltip: 'More options',
            offset: const Offset(0, 36),
            color: context.appSurface2,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: context.appBorder2)),
            onSelected: (v) {
              if (v == 'filter') setState(() => _showFilters = !_showFilters);
              if (v == 'export') _exportCsv();
              if (v == 'add') {
                if (!context.canEditModule) { context.warnReadOnly(); return; }
                _showAddLineDialog();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'filter',
                child: Row(children: [
                  Icon(Icons.tune, size: 16,
                      color: _showFilters ? AppDS.accent : context.appTextSecondary),
                  const SizedBox(width: 10),
                  Text(_showFilters ? 'Hide Filters' : 'Show Filters',
                      style: GoogleFonts.spaceGrotesk(fontSize: 13, color: context.appTextPrimary)),
                  if (_hasActiveFilter) ...[
                    const Spacer(),
                    Container(width: 7, height: 7,
                        decoration: const BoxDecoration(color: AppDS.accent, shape: BoxShape.circle)),
                  ],
                ])),
              PopupMenuItem(
                value: 'export',
                child: Row(children: [
                  Icon(Icons.download_outlined, size: 16, color: context.appTextSecondary),
                  const SizedBox(width: 10),
                  Text('Export CSV', style: GoogleFonts.spaceGrotesk(
                      fontSize: 13, color: context.appTextPrimary)),
                ])),
              PopupMenuItem(
                value: 'add',
                child: Row(children: [
                  const Icon(Icons.add, size: 16, color: AppDS.accent),
                  const SizedBox(width: 10),
                  Text('New Line', style: GoogleFonts.spaceGrotesk(
                      fontSize: 13, color: AppDS.accent)),
                ])),
            ],
          )
        else ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '${_filtered.length} of ${_lines.length}',
              style: GoogleFonts.spaceGrotesk(fontSize: 12, color: context.appTextMuted),
            ),
          ),
          Tooltip(
            message: _showFilters ? 'Hide filters' : 'Show filters',
            child: Stack(children: [
              IconButton(
                icon: Icon(Icons.tune,
                    color: _showFilters ? AppDS.accent : context.appTextSecondary,
                    size: 18),
                onPressed: () => setState(() => _showFilters = !_showFilters),
              ),
              if (_hasActiveFilter)
                Positioned(
                  right: 6, top: 6,
                  child: Container(
                    width: 7, height: 7,
                    decoration: const BoxDecoration(color: AppDS.accent, shape: BoxShape.circle),
                  ),
                ),
            ]),
          ),
          Tooltip(
            message: 'Export CSV',
            child: IconButton(
              icon: Icon(Icons.download_outlined, color: context.appTextSecondary, size: 18),
              onPressed: _exportCsv,
            ),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppDS.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              minimumSize: const Size(0, 36),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              textStyle: GoogleFonts.spaceGrotesk(fontSize: 13),
            ),
            onPressed: () {
              if (!context.canEditModule) { context.warnReadOnly(); return; }
              _showAddLineDialog();
            },
            icon: const Icon(Icons.add, size: 16),
            label: const Text('New Line'),
          ),
        ],
      ]),
    );
  }

  Widget _buildFilterPanel() {
    final reporters = _lines
        .where((l) => l.fishlineReporter != null)
        .map((l) => l.fishlineReporter!)
        .toSet().toList()..sort();
    return Container(
      decoration: BoxDecoration(
        color: context.appSurface,
        border: Border(bottom: BorderSide(color: context.appBorder)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Text('Type', style: GoogleFonts.spaceGrotesk(
                color: context.appTextMuted, fontSize: 11, fontWeight: FontWeight.w600)),
            const SizedBox(width: 12),
            _chip('All', _filterType == null,
                () { setState(() => _filterType = null); _applyFilters(); }),
            ...const ['WT', 'transgenic', 'mutant', 'CRISPR', 'KO'].map((t) => Padding(
              padding: const EdgeInsets.only(left: 6),
              child: _chip(t, _filterType == t,
                  () { setState(() => _filterType = t); _applyFilters(); }),
            )),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Text('Status', style: GoogleFonts.spaceGrotesk(
                color: context.appTextMuted, fontSize: 11, fontWeight: FontWeight.w600)),
            const SizedBox(width: 12),
            _chip('All', _filterStatus == null,
                () { setState(() => _filterStatus = null); _applyFilters(); }),
            ...const ['active', 'archived', 'cryopreserved', 'lost'].map((s) => Padding(
              padding: const EdgeInsets.only(left: 6),
              child: _chip(s, _filterStatus == s,
                  () { setState(() => _filterStatus = s); _applyFilters(); }),
            )),
          ]),
          if (reporters.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(children: [
              Text('Reporter', style: GoogleFonts.spaceGrotesk(
                  color: context.appTextMuted, fontSize: 11, fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
              _chip('All', _filterReporter == null,
                  () { setState(() => _filterReporter = null); _applyFilters(); }),
              ...reporters.map((r) => Padding(
                padding: const EdgeInsets.only(left: 6),
                child: _chip(r, _filterReporter == r,
                    () { setState(() => _filterReporter = r); _applyFilters(); }),
              )),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? AppDS.accent.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? AppDS.accent : AppDS.border,
              width: selected ? 1.5 : 1),
        ),
        child: Text(label,
            style: GoogleFonts.spaceGrotesk(
                color: selected ? AppDS.accent : AppDS.textSecondary,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tableWidth = _cols.fold(0.0, (s, c) => s + c.$3) + 36;

    return Column(
      children: [
        _buildToolbar(),
        if (_showFilters) _buildFilterPanel(),
        Divider(height: 1, color: context.appBorder),
        // ── Table ────────────────────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _loadError != null
                  ? Center(child: Text(
                      'Failed to load lines: $_loadError',
                      style: GoogleFonts.spaceGrotesk(color: AppDS.red, fontSize: 13)))
                  : Padding(
            padding: const EdgeInsets.all(8),
            child: Column(children: [
              Expanded(
                child: Row(children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppDS.tableBorder),
                        boxShadow: const [BoxShadow(color: AppDS.shadow, blurRadius: 4, offset: Offset(0, 2))],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: NotificationListener<ScrollNotification>(
                          onNotification: (n) {
                            if (n is ScrollUpdateNotification) {
                              if (n.metrics.axis == Axis.horizontal) {
                                _hOffset.value = _horizCtrl.hasClients ? _horizCtrl.offset : 0.0;
                              } else if (n.metrics.axis == Axis.vertical) {
                                _vOffset.value = _vertCtrl.hasClients ? _vertCtrl.offset : 0.0;
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
                                        padding: const EdgeInsets.symmetric(horizontal: 6),
                                        child: SortHeader(
                                          label: c.$2, columnKey: c.$1,
                                          sortKey: _sortKey, sortAsc: _sortAsc, onSort: _sort),
                                      ),
                                    )),
                                  ]),
                                ),
                                Container(height: 1, color: context.appBorder),
                                // Rows
                                Expanded(
                                  child: ListView.builder(
                                    controller: _vertCtrl,
                                    itemCount: _filtered.length,
                                    itemExtent: AppDS.tableRowH,
                                    itemBuilder: (_, i) => _buildRow(_filtered[i], i),
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
                    contentLength: _filtered.length * AppDS.tableRowH,
                    topPadding: AppDS.tableHeaderH,
                    offset: _vOffset,
                    onScrollTo: (y) {
                      final max = _vertCtrl.hasClients ? _vertCtrl.position.maxScrollExtent : 0.0;
                      final clamped = y.clamp(0.0, max);
                      _vertCtrl.jumpTo(clamped);
                      _vOffset.value = clamped;
                    },
                  ),
                ]),
              ),
              const SizedBox(height: 4),
              AppHorizontalThumb(
                contentWidth: tableWidth,
                offset: _hOffset,
                onScrollTo: (x) {
                  final max = _horizCtrl.hasClients ? _horizCtrl.position.maxScrollExtent : 0.0;
                  final clamped = x.clamp(0.0, max);
                  _horizCtrl.jumpTo(clamped);
                  _hOffset.value = clamped;
                },
              ),
              const SizedBox(height: 8),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildRow(FishLine line, int rowIndex) {
    final rowBg = rowIndex.isEven ? AppDS.tableRowEven : AppDS.tableRowOdd;
    return Container(
      decoration: BoxDecoration(
        color: rowBg,
        border: const Border(bottom: BorderSide(color: AppDS.tableBorder, width: 1)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: AppIconButton(
              icon: Icons.open_in_new, tooltip: 'Open detail page',
              color: AppDS.textMuted,
              onPressed: () => _openDetail(line)),
          ),
          _nameCell(line, 180),
          _dateCell(line, 100),
          _ageCell(line, 70, inMonths: false),
          _ageCell(line, 58, inMonths: true),
          _stockCountCell(line.stockMales,     50, AppDS.accent),
          _stockCountCell(line.stockFemales,   50, AppDS.pink),
          _stockCountCell(line.stockJuveniles, 50, AppDS.orange),
          _stockCountCell(line.stockTotal,     65, AppDS.tableText, bold: true),
          _typeCell(line, 100),
          _textCell(line, 'fishlineOriginLab', 150),
          _textCell(line, 'fishlineAlias', 110),
          _statusCell(line, 110),
          _menuCell(line, 'fishlineZygosity', 110,
              const ['homozygous', 'heterozygous', 'unknown']),
          _menuCell(line, 'fishlineGeneration', 60,
              const ['F1', 'F2', 'F3', 'F4', 'F5']),
          _textCell(line, 'fishlineAffectedGene', 90, mono: true),
          _textCell(line, 'fishlineReporter', 80),
          _textCell(line, 'fishlineTargetTissue', 120),
          _menuCell(line, 'fishlineSource', 100,
              const ['ZIRC', 'EZRC', 'collaborator', 'in-house', 'other']),
          _textCell(line, 'fishlineZfinId', 130, mono: true),
          _cryoCell(line, 60),
          _textCell(line, 'fishlineSpfStatus', 80),
          _textCell(line, 'fishlineNotes', 150),
        ],
      ),
    );
  }

  // ── Edit helpers ────────────────────────────────────────────────────────────

  static const _editDeco = InputDecoration(
    isDense: true,
    contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    filled: true, fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(4)),
        borderSide: BorderSide(color: AppDS.accent, width: 1.5)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(4)),
        borderSide: BorderSide(color: AppDS.accent, width: 1.5)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(4)),
        borderSide: BorderSide(color: AppDS.accent, width: 1.5)),
  );

  String? _fieldVal(FishLine l, String key) {
    switch (key) {
      case 'fishlineName':         return l.fishlineName;
      case 'fishlineAlias':        return l.fishlineAlias;
      case 'fishlineType':         return l.fishlineType;
      case 'fishlineStatus':       return l.fishlineStatus;
      case 'fishlineZygosity':     return l.fishlineZygosity;
      case 'fishlineGeneration':   return l.fishlineGeneration;
      case 'fishlineAffectedGene': return l.fishlineAffectedGene;
      case 'fishlineReporter':     return l.fishlineReporter;
      case 'fishlineTargetTissue': return l.fishlineTargetTissue;
      case 'fishlineOriginLab':    return l.fishlineOriginLab;
      case 'fishlineZfinId':       return l.fishlineZfinId;
      case 'fishlineSpfStatus':    return l.fishlineSpfStatus;
      case 'fishlineSource':       return l.fishlineSource;
      case 'fishlineNotes':        return l.fishlineNotes;
      default: return null;
    }
  }

  String _dbCol(String key) {
    switch (key) {
      case 'fishlineName':         return FishSch.lineName;
      case 'fishlineAlias':        return FishSch.lineAlias;
      case 'fishlineType':         return FishSch.lineType;
      case 'fishlineStatus':       return FishSch.lineStatus;
      case 'fishlineZygosity':     return FishSch.lineZygosity;
      case 'fishlineGeneration':   return FishSch.lineGeneration;
      case 'fishlineAffectedGene': return FishSch.lineAffectedGene;
      case 'fishlineReporter':     return FishSch.lineReporter;
      case 'fishlineTargetTissue': return FishSch.lineTargetTissue;
      case 'fishlineOriginLab':    return FishSch.lineOriginLab;
      case 'fishlineZfinId':       return FishSch.lineZfinId;
      case 'fishlineSpfStatus':    return FishSch.lineSpfStatus;
      case 'fishlineSource':       return FishSch.lineSource;
      case 'fishlineNotes':        return FishSch.lineNotes;
      case 'fishlineDateBirth':    return FishSch.lineDateBirth;
      default: return key;
    }
  }

  void _applyLocal(FishLine l, String key, String? s) {
    switch (key) {
      case 'fishlineName':         if (s != null) l.fishlineName = s; break;
      case 'fishlineAlias':        l.fishlineAlias = s; break;
      case 'fishlineType':         l.fishlineType = s; break;
      case 'fishlineStatus':       l.fishlineStatus = s; break;
      case 'fishlineZygosity':     l.fishlineZygosity = s; break;
      case 'fishlineGeneration':   l.fishlineGeneration = s; break;
      case 'fishlineAffectedGene': l.fishlineAffectedGene = s; break;
      case 'fishlineReporter':     l.fishlineReporter = s; break;
      case 'fishlineTargetTissue': l.fishlineTargetTissue = s; break;
      case 'fishlineOriginLab':    l.fishlineOriginLab = s; break;
      case 'fishlineZfinId':       l.fishlineZfinId = s; break;
      case 'fishlineSpfStatus':    l.fishlineSpfStatus = s; break;
      case 'fishlineSource':       l.fishlineSource = s; break;
      case 'fishlineNotes':        l.fishlineNotes = s; break;
    }
  }

  Future<void> _commitEdit(FishLine l, String key, String value) async {
    if (l.fishlineId == null) return;
    final s = value.isEmpty ? null : value;
    setState(() { _applyLocal(l, key, s); _editingCell = null; });
    try {
      await Supabase.instance.client
          .from(FishSch.linesTable)
          .update({_dbCol(key): s})
          .eq(FishSch.lineId, l.fishlineId!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e'), backgroundColor: AppDS.red));
      }
    }
  }

  Future<void> _commitDate(FishLine l, DateTime date) async {
    if (l.fishlineId == null) return;
    final iso = '${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}';
    setState(() { l.fishlineDateBirth = date; _editingCell = null; });
    try {
      await Supabase.instance.client
          .from(FishSch.linesTable)
          .update({FishSch.lineDateBirth: iso})
          .eq(FishSch.lineId, l.fishlineId!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e'), backgroundColor: AppDS.red));
      }
    }
  }

  Future<void> _toggleCryo(FishLine l) async {
    if (l.fishlineId == null) return;
    final newVal = !l.fishlineCryopreserved;
    setState(() => l.fishlineCryopreserved = newVal);
    try {
      await Supabase.instance.client
          .from(FishSch.linesTable)
          .update({FishSch.lineCryopreserved: newVal})
          .eq(FishSch.lineId, l.fishlineId!);
    } catch (e) {
      if (mounted) {
        setState(() => l.fishlineCryopreserved = !newVal);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e'), backgroundColor: AppDS.red));
      }
    }
  }

  Future<void> _showMenuPicker(
      FishLine l, String key, List<String> options, Offset pos) async {
    final current = _fieldVal(l, key);
    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx + 1, pos.dy + 1),
      color: AppDS.surface2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppDS.border)),
      items: options.map((o) => PopupMenuItem<String>(
        value: o,
        child: Row(children: [
          Text(o, style: GoogleFonts.spaceGrotesk(
            fontSize: 13, color: AppDS.textPrimary,
            fontWeight: current == o ? FontWeight.w700 : FontWeight.normal)),
          if (current == o) ...[
            const Spacer(),
            const Icon(Icons.check, size: 14, color: AppDS.accent)],
        ]),
      )).toList(),
    );
    if (result != null && result != current) await _commitEdit(l, key, result);
  }

  Future<void> _showDatePickerDialog(FishLine l) async {
    DateTime? selected;
    final current = l.fishlineDateBirth;
    final result = await showDialog<DateTime>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDs) => AlertDialog(
          backgroundColor: AppDS.surface2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppDS.border2)),
          title: Text('Date of Birth',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 15, fontWeight: FontWeight.w700, color: AppDS.textPrimary)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              width: 300,
              child: Theme(
                data: ThemeData.light(),
                child: CalendarDatePicker(
                  initialDate: current ?? DateTime.now(),
                  firstDate: DateTime(1990),
                  lastDate: DateTime.now(),
                  onDateChanged: (d) => setDs(() => selected = d),
                ),
              ),
            ),
            if (selected != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppDS.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppDS.accent.withValues(alpha: 0.4))),
                child: Text(
                  '${selected!.year}-${selected!.month.toString().padLeft(2,"0")}-${selected!.day.toString().padLeft(2,"0")}',
                  style: GoogleFonts.jetBrainsMono(
                    fontWeight: FontWeight.w600, color: AppDS.accent, fontSize: 13)),
              ),
            ],
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppDS.accent, foregroundColor: AppDS.bg),
              onPressed: selected != null ? () => Navigator.pop(ctx, selected) : null,
              child: const Text('Set Date')),
          ],
        ),
      ),
    );
    if (result != null && mounted) await _commitDate(l, result);
  }

  // ── Cell widgets ────────────────────────────────────────────────────────────

  Widget _nameCell(FishLine l, double w) {
    final isEditing = _editingCell?['id'] == l.fishlineId &&
        _editingCell?['key'] == 'fishlineName';
    return GestureDetector(
      onDoubleTap: () {
        if (!context.canEditModule) { context.warnReadOnly(); return; }
        setState(() {
          _editingCell = {'id': l.fishlineId, 'key': 'fishlineName'};
          _editController.text = l.fishlineName;
        });
      },
      child: SizedBox(
        width: w,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: isEditing
              ? TextField(
                  controller: _editController, autofocus: true,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 12.5, fontWeight: FontWeight.w600,
                    color: AppDS.tableText),
                  decoration: _editDeco,
                  onSubmitted: (v) => _commitEdit(l, 'fishlineName', v),
                  onTapOutside: (_) =>
                      _commitEdit(l, 'fishlineName', _editController.text),
                )
              : Text(l.fishlineName,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 12.5, fontWeight: FontWeight.w600,
                    color: AppDS.tableText),
                  overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }

  Widget _textCell(FishLine l, String key, double w, {bool mono = false}) {
    final isEditing =
        _editingCell?['id'] == l.fishlineId && _editingCell?['key'] == key;
    final val = _fieldVal(l, key);
    return GestureDetector(
      onDoubleTap: () {
        if (!context.canEditModule) { context.warnReadOnly(); return; }
        setState(() {
          _editingCell = {'id': l.fishlineId, 'key': key};
          _editController.text = val ?? '';
        });
      },
      child: SizedBox(
        width: w,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: isEditing
              ? TextField(
                  controller: _editController, autofocus: true,
                  style: mono
                      ? GoogleFonts.jetBrainsMono(
                          fontSize: 11.5, color: AppDS.tableText)
                      : GoogleFonts.spaceGrotesk(
                          fontSize: 12, color: AppDS.tableText),
                  decoration: _editDeco,
                  onSubmitted: (v) => _commitEdit(l, key, v),
                  onTapOutside: (_) =>
                      _commitEdit(l, key, _editController.text),
                )
              : Text(
                  val ?? '—',
                  style: (mono
                      ? GoogleFonts.jetBrainsMono(fontSize: 11.5)
                      : GoogleFonts.spaceGrotesk(fontSize: 12))
                      .copyWith(
                          color: val == null
                              ? AppDS.tableTextMute
                              : AppDS.tableText),
                  overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }

  Widget _menuCell(
      FishLine l, String key, double w, List<String> options) {
    final val = _fieldVal(l, key);
    return GestureDetector(
      onDoubleTapDown: (d) {
        _showMenuPicker(l, key, options, d.globalPosition);
      },
      child: SizedBox(
        width: w,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Text(val ?? '—',
            style: GoogleFonts.spaceGrotesk(fontSize: 12,
                color: val == null ? AppDS.tableTextMute : AppDS.tableText),
            overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }

  Widget _typeCell(FishLine l, double w) {
    return GestureDetector(
      onDoubleTapDown: (d) => _showMenuPicker(l, 'fishlineType',
          const ['WT', 'transgenic', 'mutant', 'CRISPR', 'KO', 'KI'],
          d.globalPosition),
      child: SizedBox(
        width: w,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: StatusBadge(
              label: l.fishlineType,
              overrideStatus: l.fishlineType?.toLowerCase()),
        ),
      ),
    );
  }

  Widget _statusCell(FishLine l, double w) {
    return GestureDetector(
      onDoubleTapDown: (d) => _showMenuPicker(l, 'fishlineStatus',
          const ['active', 'archived', 'cryopreserved', 'lost'],
          d.globalPosition),
      child: SizedBox(
        width: w,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: StatusBadge(label: l.fishlineStatus),
        ),
      ),
    );
  }

  Widget _dateCell(FishLine l, double w) {
    return GestureDetector(
      onDoubleTap: () => _showDatePickerDialog(l),
      child: SizedBox(
        width: w,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Text(
            l.fishlineDateBirth?.toIso8601String().split('T')[0] ?? '—',
            style: GoogleFonts.jetBrainsMono(fontSize: 11,
                color: l.fishlineDateBirth == null
                    ? AppDS.tableTextMute
                    : AppDS.tableText)),
        ),
      ),
    );
  }

  Widget _stockCountCell(int count, double w, Color color, {bool bold = false}) =>
    SizedBox(
      width: w,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Text(
          count > 0 ? '$count' : '—',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 11,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            color: count > 0 ? color : AppDS.tableTextMute),
        ),
      ),
    );

  Widget _ageCell(FishLine l, double w, {required bool inMonths}) {
    final days = l.fishlineDateBirth != null
        ? DateTime.now().difference(l.fishlineDateBirth!).inDays
        : null;
    final val = days == null
        ? '—'
        : inMonths ? (days ~/ 30).toString() : days.toString();
    return SizedBox(
      width: w,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Text(val,
          style: GoogleFonts.jetBrainsMono(fontSize: 11,
              color: days == null ? AppDS.tableTextMute : AppDS.tableText)),
      ),
    );
  }

  Widget _cryoCell(FishLine l, double w) => GestureDetector(
    onTap: () => _toggleCryo(l),
    child: SizedBox(
      width: w,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Icon(
          l.fishlineCryopreserved ? Icons.ac_unit : Icons.remove,
          size: 14,
          color: l.fishlineCryopreserved ? AppDS.accent : AppDS.textMuted),
      ),
    ),
  );

  void _showAddLineDialog() {
    showDialog(context: context, builder: (_) => _AddLineDialog(
      onAdd: (line) => setState(() { _lines.add(line); _applyFilters(); }),
    ));
  }
}

