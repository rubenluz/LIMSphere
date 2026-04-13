// stocks_page.dart - Fish stock inventory with rack visualisation, status
// filters, links to lines, add/edit/transfer workflows.

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'stocks_connection_model.dart';
import '/core/fish_db_schema.dart';
import '/core/data_cache.dart';
import '../shared_widgets.dart';
import 'stocks_detail_page.dart';
import '../tanks/tanks_connection_model.dart';
import '/theme/theme.dart';
import '/theme/module_permission.dart';
import '/theme/grid_widgets.dart';
import '../add_stock_dialog.dart';
import '../../requests/requests_page.dart';
import '../../labels/label_page.dart';
import '../../backups/backup_service.dart';




class FishStocksPage extends StatefulWidget {
  const FishStocksPage({super.key});

  @override
  State<FishStocksPage> createState() => _FishStocksPageState();
}

class _FishStocksPageState extends State<FishStocksPage> {
  List<FishStock> _stocks = [];
  List<FishStock> _filtered = [];
  final _searchCtrl = TextEditingController();
  bool _loading = true;
  String? _loadError;
  String? _filterStatus;
  String? _filterHealth;
  String? _filterLine;
  String _sortKey = 'tankId';
  bool _sortAsc = true;
  bool _showFilters = false;
  Map<String, dynamic>? _editingCell;
  final _editController = TextEditingController();
  List<String> _lineNames = [];
  List<String> _activeLineNames = [];
  /// name → fish_line_id, used when writing edits so the FK is always set.
  Map<String, int> _lineIdByName = {};
  /// name → fish_line_date_birth, fallback when FK join returns nothing.
  Map<String, DateTime?> _lineDobByName = {};

  final _vertCtrl  = ScrollController();
  final _horizCtrl = ScrollController();
  final _hOffset   = ValueNotifier<double>(0);
  final _vOffset   = ValueNotifier<double>(0);

  // Text styles — use context-adaptive colors for dark/light mode
  TextStyle get _tsNormal    => GoogleFonts.spaceGrotesk(fontSize: 12.5, color: context.appTextPrimary);
  TextStyle get _tsMono      => GoogleFonts.jetBrainsMono(fontSize: 12,   color: context.appTextPrimary);
  TextStyle get _tsNormalMut => GoogleFonts.spaceGrotesk(fontSize: 12.5, color: context.appTextMuted);
  TextStyle get _tsMonoMut   => GoogleFonts.jetBrainsMono(fontSize: 12,   color: context.appTextMuted);

  static const _cols = [
    ('tankId',            'Tank',         72.0, true),
    ('line',              'Line',        140.0, false),
    ('status',            'Status',      110.0, false),
    ('feedingAmount',     'Feed Amt.',    80.0, false),
    ('feedingAmountUnit', 'Unit',         75.0, false),
    ('foodType',          'Food Type',   130.0, false),
    ('lastBreeding',      'Last Breed',  105.0, false),
    ('ageDays',           'Age (d)',      80.0, true),
    ('ageMonths',         'Age (mo)',     85.0, true),
    ('maturity',          'Maturity',     90.0, true),
    ('total',             'Total',        60.0, true),
    ('males',             '♂',            50.0, false),
    ('females',           '♀',            50.0, false),
    ('juveniles',         'Juv.',         60.0, false),
    ('mortality',         'Dead',         55.0, false),
    ('lastCleaning',      'Last Clean',  105.0, false),
    ('cleaningInt',       'Clean (d)',    80.0, false),
    ('nextCleaning',      'Next Clean',  110.0, false),
    ('health',            'Health',      110.0, false),
    ('responsible',       'Responsible', 130.0, false),
  ];

  @override
  void initState() {
    super.initState();
    _loadStocks();
    _loadActiveLines();
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

  int _asInt(dynamic v, {int fallback = 0}) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? fallback;
  }

  String _normalizedTankId(Map<String, dynamic> row) {
    final raw = (row['fish_stocks_tank_id']?.toString() ?? '').trim().toUpperCase();
    final rack = (row['fish_stocks_rack']?.toString() ?? '').trim().toUpperCase();
    final dbRow = (row['fish_stocks_row']?.toString() ?? '').trim().toUpperCase();
    final dbCol = (row['fish_stocks_column']?.toString() ?? '').trim();

    if (raw.contains('-')) return raw;
    if (RegExp(r'^[A-E]\d{1,2}$').hasMatch(raw)) {
      return '${rack.isNotEmpty ? rack : 'R1'}-$raw';
    }
    if (dbRow.isNotEmpty && dbCol.isNotEmpty) {
      return '${rack.isNotEmpty ? rack : 'R1'}-$dbRow$dbCol';
    }
    return raw.isEmpty ? '—' : raw;
  }

  FishStock _stockFromRow(Map<String, dynamic> row) {
    final fishId = row['fish_stocks_id'];
    final line = (row['fish_stocks_line']?.toString() ?? '').trim();
    final tankId = _normalizedTankId(row);
    final arrivalRaw = row['fish_stocks_arrival_date'];

    final lineData = row['fish_lines'] as Map<String, dynamic>?;
    final liveName = lineData?['fish_line_name']?.toString().trim();
    final dobRaw = lineData?['fish_line_date_birth'];
    return FishStock(
      id: fishId is int ? fishId : int.tryParse(fishId?.toString() ?? ''),
      stockId: fishId?.toString() ?? '—',
      line: (liveName?.isNotEmpty == true) ? liveName! : (line.isEmpty ? 'unknown' : line),
      males: _asInt(row['fish_stocks_males']),
      females: _asInt(row['fish_stocks_females']),
      juveniles: _asInt(row['fish_stocks_juveniles']),
      mortality: _asInt(row['fish_stocks_mortality']),
      tankId: tankId,
      responsible: row['fish_stocks_responsible']?.toString() ?? '',
      status: row['fish_stocks_status']?.toString() ?? 'active',
      health: row['fish_stocks_health_status']?.toString() ?? 'healthy',
      origin: row['fish_stocks_origin']?.toString(),
      experiment: row['fish_stocks_experiment_id']?.toString(),
      notes: row['fish_stocks_notes']?.toString(),
      volumeL: row['fish_stocks_volume_l'] != null
          ? double.tryParse(row['fish_stocks_volume_l'].toString())
          : null,
      arrivalDate: arrivalRaw != null ? DateTime.tryParse(arrivalRaw.toString()) : null,
      created: row['fish_stocks_created_at'] != null
          ? DateTime.tryParse(row['fish_stocks_created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      lineDateBirth: dobRaw != null ? DateTime.tryParse(dobRaw.toString()) : null,
      lastCleaning: row[FishSch.stockLastCleaning] != null
          ? DateTime.tryParse(row[FishSch.stockLastCleaning].toString())
          : null,
      cleaningIntervalDays: row[FishSch.stockCleaningInterval] != null
          ? int.tryParse(row[FishSch.stockCleaningInterval].toString())
          : null,
      feedingSchedule: row[FishSch.stockFeedingSchedule]?.toString(),
      foodType:        row[FishSch.stockFoodType]?.toString(),
      feedingAmount:   row[FishSch.stockFoodAmount] != null
          ? double.tryParse(row[FishSch.stockFoodAmount].toString())
          : null,
      feedingAmountUnit: row[FishSch.stockFeedingAmountUnit]?.toString(),
      lastBreeding:    row[FishSch.stockLastBreeding] != null
          ? DateTime.tryParse(row[FishSch.stockLastBreeding].toString())
          : null,
    );
  }

  Future<void> _loadStocks() async {
    final cached = await DataCache.read('fish_stocks_stocks');
    if (cached != null && mounted) {
      _stocks = cached.cast<Map<String, dynamic>>().map(_stockFromRow).toList();
      _applyFilters();
      setState(() { _loading = false; _loadError = null; });
    } else {
      setState(() { _loading = true; _loadError = null; });
    }
    try {
      final rows = (await Supabase.instance.client
          .from('fish_stocks')
          .select('*, fish_lines!fish_stocks_line_id(fish_line_name, fish_line_date_birth)')
          .not('fish_stocks_line', 'is', null)
          .neq('fish_stocks_line', '')
          .order('fish_stocks_rack')
          .order('fish_stocks_row')
          .order('fish_stocks_column')
          .order('fish_stocks_id') as List<dynamic>)
          .cast<Map<String, dynamic>>();
      await DataCache.write('fish_stocks_stocks', rows);
      if (!mounted) return;
      _stocks = rows.map(_stockFromRow).toList();
      _applyFilters();
      setState(() => _loading = false);
    } catch (e) {
      if (cached == null && mounted) {
        setState(() { _loading = false; _loadError = e.toString(); });
      }
    }
  }

  Future<void> _loadActiveLines() async {
    try {
      // Active lines for the line-name dropdown (editing) — also fetch id for FK writes
      final activeRows = (await Supabase.instance.client
          .from('fish_lines')
          .select('fish_line_id, fish_line_name')
          .eq('fish_line_status', 'active')
          .order('fish_line_name') as List<dynamic>)
          .cast<Map<String, dynamic>>();

      // All lines (any status) for DOB lookup — matches detail page behaviour
      final allRows = (await Supabase.instance.client
          .from('fish_lines')
          .select('fish_line_name, fish_line_date_birth')
          .order('fish_line_name') as List<dynamic>)
          .cast<Map<String, dynamic>>();

      if (mounted) {
        setState(() {
          _activeLineNames = activeRows.map((r) => r['fish_line_name'] as String).toList();
          _lineIdByName = { for (final r in activeRows) r['fish_line_name'] as String: r['fish_line_id'] as int };
          _lineDobByName = {
            for (final r in allRows)
              r['fish_line_name'] as String:
                r['fish_line_date_birth'] != null
                    ? DateTime.tryParse(r['fish_line_date_birth'].toString())
                    : null,
          };
        });
        // Re-apply lineDateBirth to any already-loaded stocks that had null.
        if (_stocks.isNotEmpty) {
          var changed = false;
          for (final s in _stocks) {
            if (s.lineDateBirth == null) {
              final dob = _lineDobByName[s.line];
              if (dob != null) {
                s.lineDateBirthOverride = dob;
                changed = true;
              }
            }
          }
          if (changed) _applyFilters();
        }
      }
    } catch (_) {}
  }

  Future<void> _commitEdit(FishStock s, String key, String raw) async {
    final v = raw.trim();
    // Update model in-place
    String? dbCol;
    dynamic dbVal;
    switch (key) {
      case 'line':
        s.line = v.isEmpty ? s.line : v;
        setState(() => _editingCell = null);
        if (s.id != null) {
          try {
            await Supabase.instance.client
                .from('fish_stocks')
                .update({
                  'fish_stocks_line':    s.line,
                  'fish_stocks_line_id': _lineIdByName[s.line],
                })
                .eq('fish_stocks_id', s.id!);
            unawaited(BackupService.instance.notifyCrudChange('fish_stocks'));
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Save failed: $e'), backgroundColor: AppDS.red));
            }
          }
        }
        return;
      case 'males':       s.males = int.tryParse(v) ?? s.males;         dbCol = 'fish_stocks_males';         dbVal = s.males; break;
      case 'females':     s.females = int.tryParse(v) ?? s.females;     dbCol = 'fish_stocks_females';       dbVal = s.females; break;
      case 'juveniles':   s.juveniles = int.tryParse(v) ?? s.juveniles; dbCol = 'fish_stocks_juveniles';     dbVal = s.juveniles; break;
      case 'mortality':   s.mortality = int.tryParse(v) ?? s.mortality; dbCol = 'fish_stocks_mortality';     dbVal = s.mortality; break;
      case 'tankId':      s.tankId = v.isEmpty ? s.tankId : v;          dbCol = 'fish_stocks_tank_id';       dbVal = s.tankId; break;
      case 'responsible': s.responsible = v;                             dbCol = 'fish_stocks_responsible';   dbVal = v; break;
      case 'status':      s.status = v;                                  dbCol = 'fish_stocks_status';        dbVal = v; break;
      case 'health':      s.health = v;                                  dbCol = 'fish_stocks_health_status'; dbVal = v; break;
      case 'experiment':  s.experiment = v.isEmpty ? null : v;          dbCol = 'fish_stocks_experiment_id';            dbVal = s.experiment; break;
      case 'cleaningInt':
        s.cleaningIntervalDays = v.isEmpty ? null : int.tryParse(v);
        dbCol = FishSch.stockCleaningInterval;
        dbVal = s.cleaningIntervalDays;
        break;
      case 'feedingAmount':
        s.feedingAmount = v.isEmpty ? null : double.tryParse(v);
        dbCol = FishSch.stockFoodAmount;
        dbVal = s.feedingAmount;
        break;
      case 'feedingAmountUnit':
        s.feedingAmountUnit = v.isEmpty ? null : v;
        dbCol = FishSch.stockFeedingAmountUnit;
        dbVal = s.feedingAmountUnit;
        break;
      case 'foodType':
        s.foodType = v.isEmpty ? null : v;
        dbCol = FishSch.stockFoodType;
        dbVal = s.foodType;
        break;
    }
    setState(() => _editingCell = null);
    if (dbCol == null || s.id == null) return;
    try {
      await Supabase.instance.client
          .from('fish_stocks')
          .update({dbCol: dbVal})
          .eq('fish_stocks_id', s.id!);
      unawaited(BackupService.instance.notifyCrudChange('fish_stocks'));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e'), backgroundColor: AppDS.red));
      }
    }
  }

  void _applyFilters() {
    var d = _stocks.toList();
    final q = _searchCtrl.text.toLowerCase();
    if (q.isNotEmpty) {
      d = d.where((r) =>
        r.stockId.toLowerCase().contains(q) ||
        r.line.toLowerCase().contains(q) ||
        r.tankId.toLowerCase().contains(q) ||
        r.responsible.toLowerCase().contains(q) ||
        (r.experiment?.toLowerCase().contains(q) ?? false)
      ).toList();
    }
    if (_filterStatus != null) d = d.where((r) => r.status == _filterStatus).toList();
    if (_filterHealth != null) d = d.where((r) => r.health == _filterHealth).toList();
    if (_filterLine   != null) d = d.where((r) => r.line   == _filterLine).toList();
    _applySortToList(d);
    _lineNames = _stocks.map((s) => s.line).toSet().toList()..sort();
    setState(() => _filtered = d);
  }

  void _applySortToList(List<FishStock> d) {
    d.sort((a, b) {
      dynamic av, bv;
      switch (_sortKey) {
        case 'stockId':     av = a.stockId;      bv = b.stockId; break;
        case 'tankId':
          final c = _compareTankId(a.tankId, b.tankId);
          return _sortAsc ? c : -c;
        case 'line':        av = a.line;          bv = b.line; break;
        case 'ageDays':     av = a.ageDays;       bv = b.ageDays; break;
        case 'ageMonths':   av = a.ageMonths;     bv = b.ageMonths; break;
        case 'maturity':    av = a.maturity ?? ''; bv = b.maturity ?? ''; break;
        case 'males':       av = a.males;         bv = b.males; break;
        case 'females':     av = a.females;       bv = b.females; break;
        case 'juveniles':   av = a.juveniles;     bv = b.juveniles; break;
        case 'total':       av = a.totalFish;     bv = b.totalFish; break;
        case 'mortality':   av = a.mortality;     bv = b.mortality; break;
        case 'responsible': av = a.responsible;   bv = b.responsible; break;
        case 'status':      av = a.status;        bv = b.status; break;
        case 'health':      av = a.health;        bv = b.health; break;
        default: av = a.stockId; bv = b.stockId;
      }
      int c = (av is num && bv is num)
          ? av.compareTo(bv)
          : av.toString().compareTo(bv.toString());
      return _sortAsc ? c : -c;
    });
  }

  /// Natural sort for tank IDs like "R1-A2" vs "R10-A2" vs "R1-A10".
  /// Splits into rack (natural), row letter, and column number.
  static int _compareTankId(String a, String b) {
    final re = RegExp(r'^([^-]+)-([A-Za-z]+)(\d+)$');
    final ma = re.firstMatch(a);
    final mb = re.firstMatch(b);
    if (ma == null || mb == null) return _naturalStr(a, b);
    final rack = _naturalStr(ma.group(1)!, mb.group(1)!);
    if (rack != 0) return rack;
    final row = ma.group(2)!.compareTo(mb.group(2)!);
    if (row != 0) return row;
    return int.parse(ma.group(3)!).compareTo(int.parse(mb.group(3)!));
  }

  /// Compares two strings treating embedded digit runs numerically.
  /// e.g. "R2" < "R10" (not "R10" < "R2").
  static int _naturalStr(String a, String b) {
    final re = RegExp(r'(\d+)|(\D+)');
    final ta = re.allMatches(a).toList();
    final tb = re.allMatches(b).toList();
    for (var i = 0; i < ta.length && i < tb.length; i++) {
      final sa = ta[i].group(0)!;
      final sb = tb[i].group(0)!;
      final na = int.tryParse(sa);
      final nb = int.tryParse(sb);
      final c = (na != null && nb != null) ? na.compareTo(nb) : sa.compareTo(sb);
      if (c != 0) return c;
    }
    return a.length.compareTo(b.length);
  }

  void _sort(String key) {
    setState(() {
      if (_sortKey == key) {
        _sortAsc = !_sortAsc;
      } else { _sortKey = key; _sortAsc = true; }
    });
    _applyFilters();
  }


  Future<void> _openDetail(FishStock stock) async {
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => TankDetailPage(tank: ZebrafishTank(zebraTankId: stock.tankId)),
    ));
    if (mounted) _loadStocks();
  }

  Future<void> _exportCsv() async {
    final buf = StringBuffer();
    buf.writeln('Tank,Line,Status,Health,Males,Females,Juveniles,Total,Mortality,Responsible,Last Cleaning,Next Cleaning,Last Breeding,Notes');
    for (final s in _filtered) {
      String esc(String? v) => '"${(v ?? '').replaceAll('"', '""')}"';
      final nextClean = (s.lastCleaning != null && s.cleaningIntervalDays != null)
          ? s.lastCleaning!.add(Duration(days: s.cleaningIntervalDays!)).toIso8601String().substring(0, 10)
          : '';
      buf.writeln([
        esc(s.tankId),
        esc(s.line),
        esc(s.status),
        esc(s.health),
        s.males,
        s.females,
        s.juveniles,
        s.totalFish,
        s.mortality,
        esc(s.responsible),
        s.lastCleaning != null ? s.lastCleaning!.toIso8601String().substring(0, 10) : '',
        nextClean,
        s.lastBreeding != null ? s.lastBreeding!.toIso8601String().substring(0, 10) : '',
        esc(s.notes),
      ].join(','));
    }
    try {
      final dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/fish_stocks_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(buf.toString());
      await OpenFilex.open(file.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: AppDS.red));
      }
    }
  }

  bool get _hasActiveFilter =>
      _filterLine != null || _filterStatus != null || _filterHealth != null;

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
        const Icon(Icons.set_meal_outlined, size: 18, color: Color(0xFF0EA5E9)),
        const SizedBox(width: 8),
        Text('Stocks', style: GoogleFonts.spaceGrotesk(
          fontSize: 16, fontWeight: FontWeight.w600,
          color: context.appTextPrimary)),
        const SizedBox(width: 16),
        Expanded(
          child: SizedBox(
            height: 36,
            child: AppSearchBar(controller: _searchCtrl, hint: 'Search stocks…', onClear: _applyFilters),
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
                _showAddStockDialog();
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
                  Text('New Stock', style: GoogleFonts.spaceGrotesk(
                      fontSize: 13, color: AppDS.accent)),
                ])),
            ],
          )
        else ...[
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
              _showAddStockDialog();
            },
            icon: const Icon(Icons.add, size: 16),
            label: const Text('New Stock'),
          ),
        ],
      ]),
    );
  }

  Widget _buildFilterPanel() {
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
            Text('Line', style: GoogleFonts.spaceGrotesk(
                color: context.appTextMuted, fontSize: 11, fontWeight: FontWeight.w600)),
            const SizedBox(width: 12),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  _chip('All', _filterLine == null,
                      () { setState(() => _filterLine = null); _applyFilters(); }),
                  ..._lineNames.map((l) => Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: _chip(l, _filterLine == l,
                        () { setState(() => _filterLine = l); _applyFilters(); }),
                  )),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Text('Status', style: GoogleFonts.spaceGrotesk(
                color: context.appTextMuted, fontSize: 11, fontWeight: FontWeight.w600)),
            const SizedBox(width: 12),
            _chip('All', _filterStatus == null,
                () { setState(() => _filterStatus = null); _applyFilters(); }),
            ...const ['active', 'empty', 'quarantine', 'retired'].map((s) => Padding(
              padding: const EdgeInsets.only(left: 6),
              child: _chip(s, _filterStatus == s,
                  () { setState(() => _filterStatus = s); _applyFilters(); }),
            )),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Text('Health', style: GoogleFonts.spaceGrotesk(
                color: context.appTextMuted, fontSize: 11, fontWeight: FontWeight.w600)),
            const SizedBox(width: 12),
            _chip('All', _filterHealth == null,
                () { setState(() => _filterHealth = null); _applyFilters(); }),
            ...const ['healthy', 'observation', 'treatment', 'sick'].map((h) => Padding(
              padding: const EdgeInsets.only(left: 6),
              child: _chip(h, _filterHealth == h,
                  () { setState(() => _filterHealth = h); _applyFilters(); }),
            )),
          ]),
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
    final tableWidth = _cols.fold(0.0, (s, c) => s + c.$3) + 84;

    return Column(
      children: [
        _buildToolbar(),
        if (_showFilters) _buildFilterPanel(),
        Container(height: 1, color: context.appBorder),
        // ── Table ────────────────────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _loadError != null
                  ? Center(
                      child: Text(
                        'Failed to load stocks: $_loadError',
                        style: GoogleFonts.spaceGrotesk(color: AppDS.red, fontSize: 13),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                      child: Column(children: [
                        Expanded(
                          child: Row(children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: context.appSurface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: context.appBorder),
                                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
                                ),
                                clipBehavior: Clip.antiAlias,
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
                                            const SizedBox(width: 84),
                                            ..._cols.map((c) => SizedBox(
                                              width: c.$3,
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                                child: SortHeader(
                                                  label: c.$2, columnKey: c.$1,
                                                  sortKey: _sortKey, sortAsc: _sortAsc,
                                                  onSort: _sort),
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
                                            itemBuilder: (_, i) {
                                              final s = _filtered[i];
                                              return KeyedSubtree(
                                                key: ValueKey(s.id ?? i),
                                                child: _buildRow(s, i),
                                              );
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
                      ]),
                    ),
        ),
      ],
    );
  }

  Widget _buildRow(FishStock stock, int rowIndex) {
    final rowBg = rowIndex.isEven ? context.appSurface : context.appSurface2;
    return Container(
      decoration: BoxDecoration(
        color: rowBg,
        border: Border(bottom: BorderSide(color: context.appBorder, width: 1)),
      ),
      child: Row(
          children: [
            SizedBox(
              width: 28,
              child: AppIconButton(
                icon: Icons.open_in_new, tooltip: 'Open detail',
                color: AppDS.textMuted,
                onPressed: () => _openDetail(stock)),
            ),
            SizedBox(
              width: 28,
              child: AppIconButton(
                icon: Icons.outbox_outlined, tooltip: 'Quick Request',
                color: AppDS.textMuted,
                onPressed: () => showQuickRequestDialog(
                  context,
                  type: 'fish_eggs',
                  prefillTitle: stock.line,
                )),
            ),
            SizedBox(
              width: 28,
              child: AppIconButton(
                icon: Icons.print_outlined, tooltip: 'Quick Print',
                color: AppDS.textMuted,
                onPressed: () => showQuickPrintDialog(
                  context,
                  category: 'Stocks',
                  entityId: stock.stockId.isNotEmpty ? stock.stockId : null,
                  data: {
                    'fish_stocks_tank_id':    stock.tankId,
                    'fish_stocks_line':       stock.line,
                    'fish_line_name':         stock.line,
                    'fish_stocks_males':      stock.males.toString(),
                    'fish_stocks_females':    stock.females.toString(),
                    'fish_stocks_juveniles':  stock.juveniles.toString(),
                    'fish_stocks_status':     stock.status,
                    'fish_stocks_responsible': stock.responsible,
                    'fish_stocks_arrival_date': stock.arrivalDate != null
                        ? stock.arrivalDate!.toIso8601String().substring(0, 10)
                        : '',
                  },
                )),
            ),
            _cell(stock, 'tankId',       72, mono: true),
            _cell(stock, 'line',        140),
            _statusCell(stock, 'status', 110,
              ['active', 'empty', 'quarantine', 'retired']),
            _cell(stock, 'feedingAmount', 80, mono: true),
            _dropdownCell(stock, 'feedingAmountUnit', 75, stock.feedingAmountUnit,
              ['grams', 'mL', 'clicks']),
            _dropdownCell(stock, 'foodType', 130, stock.foodType,
              ['GEMMA 75', 'GEMMA 150', 'GEMMA 300', 'SPAROS 400-600']),
            _dateCell(stock, 'lastBreeding', 105),
            _cell(stock, 'ageDays',      80, mono: true),
            _cell(stock, 'ageMonths',    85, mono: true),
            _maturityCell(stock,          90),
            _totalCell(stock),
            _cell(stock, 'males',        50),
            _cell(stock, 'females',      50),
            _cell(stock, 'juveniles',    60),
            _cell(stock, 'mortality',    55),
            _dateCell(stock, 'lastCleaning', 105),
            _cell(stock, 'cleaningInt',  80, mono: true),
            _nextCleaningCell(stock, 110),
            _statusCell(stock, 'health', 110,
              ['healthy', 'observation', 'treatment', 'sick']),
            _cell(stock, 'responsible', 130),
          ],
        ),
    );
  }

  Widget _cell(FishStock s, String key, double width, {bool mono = false}) {
    final isEditing = _editingCell != null &&
        _editingCell!['id'] == s.id &&
        _editingCell!['key'] == key;

    String? val;
    switch (key) {
      case 'tankId':      val = s.tankId; break;
      case 'line':        val = s.line; break;
      case 'ageDays':     val = s.ageDays > 0 ? '${s.ageDays}' : null; break;
      case 'ageMonths':   val = s.ageMonths > 0 ? '${s.ageMonths}' : null; break;
      case 'males':       val = '${s.males}'; break;
      case 'females':     val = '${s.females}'; break;
      case 'juveniles':   val = '${s.juveniles}'; break;
      case 'mortality':   val = '${s.mortality}'; break;
      case 'responsible':    val = s.responsible.isEmpty ? null : s.responsible; break;
      case 'experiment':     val = s.experiment; break;
      case 'feedingAmount':  val = s.feedingAmount == null ? null : (s.feedingAmount! % 1 == 0 ? s.feedingAmount!.toInt().toString() : s.feedingAmount!.toString()); break;
      case 'cleaningInt':    val = s.cleaningIntervalDays?.toString(); break;
      default: val = null;
    }

    // Line field: dropdown when editing
    if (key == 'line' && isEditing) {
      return SizedBox(
        width: width,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: DropdownCell(
            value: _activeLineNames.contains(s.line) ? s.line : null,
            options: _activeLineNames,
            onChanged: (v) {
              if (v != null) _commitEdit(s, 'line', v);
            }),
        ),
      );
    }

    final readOnly = key == 'ageDays' || key == 'ageMonths' || key == 'nextCleaning';
    return GestureDetector(
      onDoubleTap: readOnly ? null : () {
        if (!context.canEditModule) { context.warnReadOnly(); return; }
        setState(() {
          _editingCell = {'id': s.id, 'key': key};
          _editController.text = val ?? '';
        });
      },
      child: SizedBox(
        width: width,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: isEditing
              ? TextField(
                  controller: _editController,
                  autofocus: true,
                  style: mono ? _tsMono : _tsNormal,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    filled: true, fillColor: context.appSurface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: AppDS.accent, width: 1.5)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: AppDS.accent, width: 1.5)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: AppDS.accent, width: 1.5)),
                  ),
                  onSubmitted: (v) => _commitEdit(s, key, v),
                  onTapOutside: (_) => _commitEdit(s, key, _editController.text),
                )
              : Text(
                  val ?? '—',
                  style: _cellStyle(key, val, mono),
                  overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }

  TextStyle _cellStyle(String key, String? val, bool mono) {
    final muted = val == null || val == '0' || val == '—';
    if (muted) return mono ? _tsMonoMut : _tsNormalMut;
    Color? color;
    switch (key) {
      case 'males':     color = AppDS.accent; break;
      case 'females':   color = AppDS.pink;   break;
      case 'juveniles': color = AppDS.orange; break;
    }
    if (color != null) {
      return GoogleFonts.jetBrainsMono(fontSize: 12, color: color);
    }
    return mono ? _tsMono : _tsNormal;
  }

  Widget _dropdownCell(FishStock s, String key, double width, String? value, List<String> options) {
    final isEditing = _editingCell?['id'] == s.id && _editingCell?['key'] == key;
    return GestureDetector(
      onDoubleTap: () {
        if (!context.canEditModule) { context.warnReadOnly(); return; }
        setState(() => _editingCell = {'id': s.id, 'key': key});
      },
      child: SizedBox(
        width: width,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: isEditing
              ? DropdownCell(
                  value: options.contains(value) ? value : null,
                  options: options,
                  onChanged: (v) { if (v != null) _commitEdit(s, key, v); })
              : Text(value ?? '—',
                  style: value == null ? _tsNormalMut : _tsNormal,
                  overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }

  Widget _statusCell(FishStock s, String key, double width, List<String> options) {
    final isEditing = _editingCell != null &&
        _editingCell!['id'] == s.id &&
        _editingCell!['key'] == key;
    final val = key == 'status' ? s.status : s.health;
    return GestureDetector(
      onDoubleTap: () {
        if (!context.canEditModule) { context.warnReadOnly(); return; }
        setState(() => _editingCell = {'id': s.id, 'key': key});
      },
      child: SizedBox(
        width: width,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: isEditing
              ? DropdownCell(
                  value: val, options: options,
                  onChanged: (v) {
                    if (v != null) _commitEdit(s, key, v);
                  })
              : StatusBadge(label: val),
        ),
      ),
    );
  }

  Widget _maturityCell(FishStock s, double width) {
    final m = s.maturity;
    final color = switch (m) {
      'Adults'    => AppDS.green,
      'Juveniles' => AppDS.yellow,
      'Larvae'    => AppDS.accent,
      _           => AppDS.textSecondary,
    };
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: m == null
            ? Text('—', style: _tsNormalMut)
            : Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Text(m,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 11, fontWeight: FontWeight.w600, color: color),
                  overflow: TextOverflow.ellipsis),
              ),
      ),
    );
  }

  /// Returns the nominal tank volume in litres based on the row letter in tankId.
  /// tankId format: "R1-A5" → row letter is first char after the dash.
  double _tankVolume(String tankId) {
    final parts = tankId.split('-');
    if (parts.length >= 2 && parts[1].isNotEmpty) {
      return parts[1][0].toUpperCase() == 'A' ? 1.1 : 3.5;
    }
    return 3.5;
  }

  Widget _totalCell(FishStock s) {
    const width = 60.0;
    final total = s.totalFish;
    final vol = s.volumeL ?? _tankVolume(s.tankId);
    final overDense = vol > 0 && total / vol > 10;
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: overDense
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppDS.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppDS.red.withValues(alpha: 0.4)),
                ),
                child: Text('$total',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12, fontWeight: FontWeight.w700,
                    color: AppDS.red),
                  overflow: TextOverflow.ellipsis),
              )
            : Text('$total', style: _tsMono),
      ),
    );
  }

  Widget _dateCell(FishStock s, String key, double width) {
    final current = switch (key) {
      'lastCleaning' => s.lastCleaning,
      'lastBreeding' => s.lastBreeding,
      _ => null,
    };
    final display = current?.toIso8601String().substring(0, 10);
    return GestureDetector(
      onDoubleTap: () async {
        if (!context.canEditModule) { context.warnReadOnly(); return; }
        final picked = await showDatePicker(
          context: context,
          initialDate: current ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2040),
          builder: (ctx, child) => Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(
                primary: AppDS.accent,
                surface: AppDS.surface,
              ),
            ),
            child: child!,
          ),
        );
        if (picked == null || s.id == null) return;
        final String dbCol;
        switch (key) {
          case 'lastCleaning':
            setState(() => s.lastCleaning = picked);
            dbCol = FishSch.stockLastCleaning;
          case 'lastBreeding':
            setState(() => s.lastBreeding = picked);
            dbCol = FishSch.stockLastBreeding;
          default: return;
        }
        try {
          await Supabase.instance.client
              .from('fish_stocks')
              .update({dbCol: picked.toIso8601String().substring(0, 10)})
              .eq('fish_stocks_id', s.id!);
          unawaited(BackupService.instance.notifyCrudChange('fish_stocks'));
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Save failed: $e'), backgroundColor: AppDS.red));
          }
        }
      },
      child: SizedBox(
        width: width,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Text(display ?? '—',
              style: display != null ? _tsMono : _tsMonoMut,
              overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }

  Widget _nextCleaningCell(FishStock s, double width) {
    final next = s.nextCleaning;
    if (next == null) {
      return SizedBox(
        width: width,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Text('—', style: _tsMonoMut),
        ),
      );
    }
    final daysLeft = next.difference(DateTime.now()).inDays;
    final Color color;
    if (daysLeft < 0)            { color = AppDS.red; }
    else if (daysLeft <= 3)      { color = AppDS.yellow; }
    else if (daysLeft <= 7)      { color = AppDS.orange; }
    else                         { color = AppDS.green; }

    final label = daysLeft < 0
        ? '${daysLeft.abs()}d overdue'
        : next.toIso8601String().substring(0, 10);

    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Text(label,
              style: GoogleFonts.jetBrainsMono(
                  fontSize: 11, fontWeight: FontWeight.w600, color: color),
              overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }

  void _showAddStockDialog() {
    final occupied = _stocks.map((s) => s.tankId).toSet();
    final racks = (_stocks
        .map((s) => s.tankId.split('-').first)
        .where((r) => r.isNotEmpty)
        .toSet()
        .toList()..sort());
    showDialog(
      context: context,
      builder: (ctx) => AddStockDialog(
        occupiedTankIds: occupied,
        availableRacks: racks.isEmpty ? ['R1'] : racks,
        onAdd: (stock) => setState(() { _stocks.add(stock); _applyFilters(); }),
      ),
    );
  }
}

