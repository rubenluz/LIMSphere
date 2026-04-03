// ── tanks_page.dart ───────────────────────────────────────────────────────────
// ZebTec rack visualization: 5-row × multi-position grid with per-tank editing,
// feeding/cleaning schedules, add/remove rack, CSV export.
// Dialog classes extracted to tanks_dialogs.dart (part).
// Note: on the tank label, show feeding frequency before food type, e.g. '2x - GEMMA 300'.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:io';
import '/core/data_cache.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'tanks_connection_model.dart';
import '../shared_widgets.dart';
import '../stocks/stocks_detail_page.dart';
import '/theme/theme.dart';
import '../add_stock_dialog.dart';
import '../../labels/label_page.dart';
import 'tanks_widgets/tanks_widget_active_stocks.dart';
import 'tanks_widgets/tanks_widget_active_fish_lines.dart';
import 'tanks_widgets/tanks_widget_cleaning_timeline.dart';

part 'tanks_dialogs.dart';
part 'tanks_edit_dialog_desktop.dart';
part 'tanks_edit_dialog_mobile.dart';
part 'tanks_mobile_view.dart';


// ─── ZebTec rack geometry ─────────────────────────────────────────────────────
//
//  Row A  : 15 positions × 1.1 L   (top shelf)
//  Rows B-E: 10 positions × 2.4 L  (main rack)
//
//  Proportionality rule (same total row width for ALL rows):
//    15 × cellW_1.1  ==  10 × cellW_2.4
//    => cellW_1.1 = availableW / 15
//    => cellW_2.4 = availableW / 10
//    => 4.8 L slot = 2 × cellW_2.4   (merges 2 adjacent 2.4 L positions)
//
//  We use a LayoutBuilder to compute availableW at runtime so the rack
//  always fills the full container width regardless of window size.

const _rowLabels  = ['A', 'B', 'C', 'D', 'E'];
const _rowACount  = 15;    // 1.1 L
const _rowBECount = 10;    // 2.4 L
const _labelW     = 44.0;  // row-label column width
const _gap        = 3.0;   // inner padding per cell (each side)
const _rowHTop    = 72.0;  // row A cell height
const _rowHMain   = 96.0;  // rows B-E cell height

// ─── Tank state helpers ───────────────────────────────────────────────────────
bool _isOccupied(ZebrafishTank t) =>
    t.zebraStatus != null && t.zebraStatus != 'empty' && t.zebraStatus != 'retired';

bool _hasFish(ZebrafishTank t) =>
    ((t.zebraMales ?? 0) + (t.zebraFemales ?? 0) + (t.zebraJuveniles ?? 0)) > 0;

bool _isSentinel(ZebrafishTank t) => t.zebraTankType == 'sentinel';

// ─── Default rack ─────────────────────────────────────────────────────────────
List<ZebrafishTank> _buildDefaultRack(String rack) {
  final out = <ZebrafishTank>[];
  for (int r = 0; r < _rowLabels.length; r++) {
    final row   = _rowLabels[r];
    final isTop = r == 0;
    final cols  = isTop ? _rowACount : _rowBECount;
    for (int c = 1; c <= cols; c++) {
      out.add(ZebrafishTank(
        zebraTankId:       '$rack-$row$c',
        zebraRack:         rack,
        zebraRow:          row,
        zebraColumn:       '$c',
        zebraVolumeL:      isTop ? 1.5 : 3.5,
        zebraTankType:     'holding',
        zebraStatus:       'empty',
        zebraHealthStatus: 'healthy',
        isEightLiter:      false,
        isTopRow:          isTop,
        rackRowIndex:      r,
        rackColIndex:      c,
      ));
    }
  }
  return out;
}

// ─── Page ─────────────────────────────────────────────────────────────────────
class FishTanksPage extends StatefulWidget {
  const FishTanksPage({super.key});

  @override
  State<FishTanksPage> createState() => _FishTanksPageState();
}

class _FishTanksPageState extends State<FishTanksPage> {
  String  _selectedRack = 'R1';
  final   _showLabels   = true;
  bool    _loading      = true;
  String? _error;

  List<({String label, DateTime date})> _cleaningEvents = [];
  bool _cleaningLoading = false;

  final Map<String, List<ZebrafishTank>> _racks = {
    'R1': _buildDefaultRack('R1'),
  };

  ZebrafishTank? _menuTank;
  Offset         _menuOffset = Offset.zero;

  @override
  void initState() {
    super.initState();
    _loadFromSupabase();
    _loadCleaningTimeline();
  }

  String? _canonicalTankId(Map<String, dynamic> row) {
    final raw = (row['fish_stocks_tank_id']?.toString() ?? '').trim().toUpperCase();
    final rack = (row['fish_stocks_rack']?.toString() ?? '').trim().toUpperCase();
    final r = (row['fish_stocks_row']?.toString() ?? '').trim().toUpperCase();
    final c = (row['fish_stocks_column']?.toString() ?? '').trim();

    if (raw.isNotEmpty) {
      if (raw.contains('-')) return raw;
      if (RegExp(r'^[A-E]\d{1,2}$').hasMatch(raw)) {
        return '${rack.isNotEmpty ? rack : 'R1'}-$raw';
      }
    }

    if (r.isNotEmpty && c.isNotEmpty) {
      return '${rack.isNotEmpty ? rack : 'R1'}-$r$c';
    }
    return null;
  }

  // ── Supabase ──────────────────────────────────────────────────────────────
  void _applyStockRows(List<dynamic> rows) {
    for (final row in rows) {
      final rackId = (row as Map)['fish_stocks_rack']?.toString().toUpperCase();
      if (rackId != null && rackId.isNotEmpty && !_racks.containsKey(rackId)) {
        _racks[rackId] = _buildDefaultRack(rackId);
      }
    }
    for (final row in rows) {
      final data = Map<String, dynamic>.from(row as Map);
      final id = _canonicalTankId(data);
      if (id == null) continue;
      for (final list in _racks.values) {
        final idx = list.indexWhere((t) => t.zebraTankId == id);
        if (idx >= 0) { list[idx] = _fromRow(data, list[idx]); break; }
      }
    }
  }

  Future<void> _loadFromSupabase() async {
    final cached = await DataCache.read('fish_stocks_tanks');
    if (cached != null && mounted) {
      _racks.clear();
      _racks['R1'] = _buildDefaultRack('R1');
      _applyStockRows(cached);
      setState(() => _loading = false);
    } else {
      setState(() => _loading = true);
    }
    try {
      final rows = await Supabase.instance.client
          .from('fish_stocks')
          .select('*, fish_lines!fish_stocks_line_id(fish_line_name)')
          .order('fish_stocks_rack')
          .order('fish_stocks_row')
          .order('fish_stocks_column') as List<dynamic>;
      await DataCache.write('fish_stocks_tanks', rows);
      if (!mounted) return;
      _racks.clear();
      _racks['R1'] = _buildDefaultRack('R1');
      _applyStockRows(rows);
      setState(() => _loading = false);
    } catch (e) {
      if (cached == null && mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _loadCleaningTimeline() async {
    if (mounted) setState(() => _cleaningLoading = true);
    try {
      final rows = await Supabase.instance.client
          .from('fish_stocks')
          .select('fish_stocks_tank_id, fish_stocks_line, fish_stocks_last_tank_cleaning, fish_stocks_cleaning_interval_days')
          .eq('fish_stocks_status', 'active');

      final now    = DateTime.now();
      final cutoff = now.add(const Duration(days: 30));
      final events = <({String label, DateTime date})>[];

      for (final row in rows as List) {
        final lastRaw     = row['fish_stocks_last_tank_cleaning'];
        final intervalRaw = row['fish_stocks_cleaning_interval_days'];
        if (lastRaw == null || intervalRaw == null) continue;
        final last     = DateTime.tryParse(lastRaw.toString());
        final interval = int.tryParse(intervalRaw.toString());
        if (last == null || interval == null || interval <= 0) continue;
        final next = last.add(Duration(days: interval));
        if (next.isAfter(cutoff)) continue;
        final tankId = (row['fish_stocks_tank_id'] ?? '').toString();
        final line   = (row['fish_stocks_line'] ?? '').toString();
        final label  = tankId.isNotEmpty
            ? (line.isNotEmpty ? '$tankId · $line' : tankId)
            : line;
        events.add((label: label, date: next));
      }

      events.sort((a, b) => a.date.compareTo(b.date));
      if (mounted) setState(() { _cleaningEvents = events; _cleaningLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _cleaningLoading = false);
    }
  }

  ZebrafishTank _fromRow(Map<String, dynamic> r, ZebrafishTank def) {
    final volL = (r['fish_stocks_volume_l'] as num?)?.toDouble();
    // A-row merges at 2.2 L; B-E rows merge at 4.8 L
    final is8  = def.isTopRow
        ? (volL != null && volL >= 2.4)
        : (volL != null && volL >= 8.0);
    final lineData  = r['fish_lines'] as Map<String, dynamic>?;
    final liveName  = lineData?['fish_line_name']?.toString();
    return def.copyWith(
      zebraId:           r['fish_stocks_id'] as int?,
      zebraVolumeL:      volL,
      isEightLiter:      is8,
      zebraLine:         liveName ?? r['fish_stocks_line'],
      zebraLineId:       r['fish_stocks_line_id'] as int?,
      zebraMales:        r['fish_stocks_males'],
      zebraFemales:      r['fish_stocks_females'],
      zebraJuveniles:    r['fish_stocks_juveniles'],
      zebraResponsible:  r['fish_stocks_responsible'],
      zebraStatus:       r['fish_stocks_status'] ?? 'empty',
      zebraHealthStatus: r['fish_stocks_health_status'] ?? 'healthy',
      zebraTankType:     (r['fish_stocks_sentinel_status'] == 'sentinel')
          ? 'sentinel'
          : (r['fish_stocks_tank_type'] ?? 'holding'),
      zebraFoodType:     r['fish_stocks_food_type'],
      zebraFoodSource:   r['fish_stocks_food_source'],
      zebraFoodAmount:   (r['fish_stocks_food_amount'] as num?)?.toDouble(),
      zebraFeedingAmountUnit: r['fish_stocks_feeding_amount_unit']?.toString(),
      zebraFeedingSchedule: r['fish_stocks_feeding_schedule'],
      zebraExperimentId: r['fish_stocks_experiment_id'],
      zebraNotes:        r['fish_stocks_notes'],
      zebraTemperatureC: (r['fish_stocks_temperature_c'] as num?)?.toDouble(),
      zebraPh:           (r['fish_stocks_ph'] as num?)?.toDouble(),
      zebraLastTankCleaning: r['fish_stocks_last_tank_cleaning'] != null
          ? DateTime.tryParse(r['fish_stocks_last_tank_cleaning'] as String) : null,
    );
  }

  Future<void> _deleteStock(ZebrafishTank tank) async {
    try {
      await Supabase.instance.client
          .from('fish_stocks')
          .delete()
          .eq('fish_stocks_tank_id', tank.zebraTankId);
      final empty = tank.copyWith(
        zebraStatus: 'empty', zebraLine: null,
        zebraMales: 0, zebraFemales: 0, zebraJuveniles: 0,
        zebraTankType: 'holding', isEightLiter: false,
        zebraVolumeL: tank.isTopRow ? 1.1 : 3.5,
      );
      if (mounted) setState(() => _patch(empty));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Delete error: $e'),
          backgroundColor: AppDS.red.withValues(alpha: 0.9),
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<void> _persist(ZebrafishTank t) async {
    try {
      final isSentinel = t.zebraTankType == 'sentinel';
      final persistedTankType = isSentinel ? 'holding' : (t.zebraTankType ?? 'holding');
      final payload = {
        'fish_stocks_tank_id':     t.zebraTankId,
        'fish_stocks_rack':        t.zebraRack,
        'fish_stocks_row':         t.zebraRow,
        'fish_stocks_column':      t.zebraColumn,
        'fish_stocks_volume_l':    t.zebraVolumeL,
        'fish_stocks_line':        t.zebraLine,
        'fish_stocks_line_id':     t.zebraLineId,
        'fish_stocks_males':       t.zebraMales ?? 0,
        'fish_stocks_females':     t.zebraFemales ?? 0,
        'fish_stocks_juveniles':   t.zebraJuveniles ?? 0,
        'fish_stocks_responsible': t.zebraResponsible,
        'fish_stocks_status':      t.zebraStatus ?? 'empty',
        'fish_stocks_health_status': t.zebraHealthStatus ?? 'healthy',
        'fish_stocks_tank_type':   persistedTankType,
        'fish_stocks_sentinel_status': isSentinel ? 'sentinel' : 'none',
        'fish_stocks_food_type':       t.zebraFoodType,
        'fish_stocks_food_source':     t.zebraFoodSource,
        'fish_stocks_food_amount':     t.zebraFoodAmount,
        'fish_stocks_feeding_schedule': t.zebraFeedingSchedule,
        'fish_stocks_experiment_id':        t.zebraExperimentId,
        'fish_stocks_notes':                t.zebraNotes,
        'fish_stocks_last_tank_cleaning':   t.zebraLastTankCleaning?.toIso8601String().substring(0, 10),
      };
      if (t.zebraId != null) {
        await Supabase.instance.client
            .from('fish_stocks')
            .update(payload)
            .eq('fish_stocks_id', t.zebraId!);
      } else {
        await Supabase.instance.client
            .from('fish_stocks')
            .upsert(payload, onConflict: 'fish_stocks_tank_id');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Save error: $e'),
          backgroundColor: AppDS.red.withValues(alpha: 0.9),
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  // ── Rack helpers ──────────────────────────────────────────────────────────
  List<ZebrafishTank> get _rackTanks => _racks[_selectedRack] ?? [];

  void _patch(ZebrafishTank updated) {
    for (final list in _racks.values) {
      final idx = list.indexWhere((t) => t.zebraTankId == updated.zebraTankId);
      if (idx >= 0) { list[idx] = updated; return; }
    }
  }

  Map<int, List<ZebrafishTank>> get _byRow {
    final m = <int, List<ZebrafishTank>>{};
    for (final t in _rackTanks) {
      m.putIfAbsent(t.rackRowIndex, () => []).add(t);
    }
    for (final k in m.keys) {
      m[k]!.sort((a, b) => a.rackColIndex.compareTo(b.rackColIndex));
    }
    return m;
  }

  Future<void> _exportCsv() async {
    final allTanks = _racks.entries
        .expand((e) => e.value.map((t) => (rack: e.key, tank: t)))
        .toList();
    final buf = StringBuffer();
    buf.writeln('Rack,Tank ID,Type,Row,Column,Volume (L),Line,Males,Females,Juveniles,Responsible,Status,Health,Last Cleaning,Food Type,Feeding Schedule,Experiment,Notes');
    for (final entry in allTanks) {
      final t = entry.tank;
      String esc(String? v) => '"${(v ?? '').replaceAll('"', '""')}"';
      buf.writeln([
        esc(entry.rack),
        esc(t.zebraTankId),
        esc(t.zebraTankType),
        esc(t.zebraRow),
        esc(t.zebraColumn),
        t.zebraVolumeL ?? '',
        esc(t.zebraLine),
        t.zebraMales ?? 0,
        t.zebraFemales ?? 0,
        t.zebraJuveniles ?? 0,
        esc(t.zebraResponsible),
        esc(t.zebraStatus),
        esc(t.zebraHealthStatus),
        t.zebraLastTankCleaning != null ? t.zebraLastTankCleaning!.toIso8601String().substring(0, 10) : '',
        esc(t.zebraFoodType),
        esc(t.zebraFeedingSchedule),
        esc(t.zebraExperimentId),
        esc(t.zebraNotes),
      ].join(','));
    }
    try {
      final dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/tanks_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(buf.toString());
      await OpenFilex.open(file.path);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).size.width < 600) return _buildMobileLayout();
    final tanks     = _rackTanks;
    final occupied  = tanks.where(_isOccupied).length;
    final empties   = tanks.where((t) => t.zebraStatus == 'empty').length;
    final sentinels = tanks.where(_isSentinel).length;
    final totalFish = tanks.fold(0, (s, t) => s + (t.zebraMales ?? 0) + (t.zebraFemales ?? 0) + (t.zebraJuveniles ?? 0));

    return GestureDetector(
      onTap: () => setState(() => _menuTank = null),
      child: Stack(children: [
        Column(children: [
          // ── Toolbar ──────────────────────────────────────────────────
          Container(
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
              const Icon(Icons.grid_view_outlined, size: 18, color: AppDS.accent),
              const SizedBox(width: 8),
              Text('Tank Map', style: GoogleFonts.spaceGrotesk(
                fontSize: 16, fontWeight: FontWeight.w600,
                color: context.appTextPrimary)),
              const SizedBox(width: 16),
              // Rack selector: dropdown if >1 rack, plain label if only one
              if (_racks.length > 1) ...[
                Text('Rack:', style: GoogleFonts.spaceGrotesk(
                  fontSize: 12, color: context.appTextSecondary)),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _selectedRack,
                  dropdownColor: context.appSurface2,
                  underline: const SizedBox(),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: AppDS.accent),
                  items: (_racks.keys.toList()..sort())
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                  onChanged: (v) { if (v != null) setState(() => _selectedRack = v); },
                ),
              ] else
                Text(_selectedRack, style: GoogleFonts.jetBrainsMono(
                  fontSize: 13, fontWeight: FontWeight.w700, color: AppDS.accent)),
              const SizedBox(width: 16),
              _chip('${tanks.length} tanks',  context.appTextMuted),
              const SizedBox(width: 6),
              _chip('$occupied occupied',     AppDS.green),
              const SizedBox(width: 6),
              _chip('$empties empty',         context.appTextSecondary),
              if (sentinels > 0) ...[
                const SizedBox(width: 6),
                _chip('$sentinels sentinel',  AppDS.pink),
              ],
              const SizedBox(width: 6),
              _chip('$totalFish fish',        AppDS.green),
              const Spacer(),
              Tooltip(
                message: 'Export CSV',
                child: IconButton(
                  icon: Icon(Icons.download_outlined, color: context.appTextSecondary, size: 18),
                  onPressed: _exportCsv,
                ),
              ),
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                tooltip: 'Rack options',
                offset: const Offset(0, 36),
                color: context.appSurface2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: context.appBorder2)),
                onSelected: (v) {
                  if (v == 'add') _showAddRackDialog();
                  if (v == 'delete') _showDeleteRackDialog();
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'add',
                    child: Row(children: [
                      const Icon(Icons.add, size: 16, color: AppDS.accent),
                      const SizedBox(width: 8),
                      Text('Add Rack', style: GoogleFonts.spaceGrotesk(
                        fontSize: 13, color: context.appTextPrimary)),
                    ])),
                  PopupMenuItem(
                    value: 'delete',
                    enabled: _racks.length > 1,
                    child: Row(children: [
                      Icon(Icons.delete_outline, size: 16,
                        color: _racks.length > 1 ? AppDS.red : context.appTextMuted),
                      const SizedBox(width: 8),
                      Text('Delete $_selectedRack',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 13,
                          color: _racks.length > 1 ? AppDS.red : context.appTextMuted)),
                    ])),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppDS.accent),
                    borderRadius: BorderRadius.circular(6)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.settings_outlined, size: 14, color: AppDS.accent),
                    const SizedBox(width: 6),
                    Text('Racks', style: GoogleFonts.spaceGrotesk(
                      fontSize: 13, color: AppDS.accent)),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_drop_down, size: 16, color: AppDS.accent),
                  ]),
                ),
              ),
            ]),
          ),
          // ── Body ─────────────────────────────────────────────────────
          if (_loading)
            const Expanded(child: Center(
              child: CircularProgressIndicator()))
          else if (_error != null)
            Expanded(child: Center(child: Text('Error: $_error',
              style: GoogleFonts.spaceGrotesk(color: AppDS.red, fontSize: 13))))
          else
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LayoutBuilder(builder: (ctx, box) {
                      final avail = box.maxWidth - _labelW - 8;
                      return _buildRack(avail);
                    }),
                    const SizedBox(height: 12),
                    _buildLegend(),
                    const SizedBox(height: 20),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: TanksWidgetActiveStocks(rackTanks: _rackTanks)),
                          const SizedBox(width: 12),
                          Expanded(child: TanksWidgetActiveFishLines(rackTanks: _rackTanks)),
                          const SizedBox(width: 12),
                          Expanded(child: TanksWidgetCleaningTimeline(
                            events: _cleaningEvents,
                            loading: _cleaningLoading,
                          )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ]),
        if (_menuTank != null) _buildContextMenu(),
      ]),
    );
  }

  // ── Rack grid ─────────────────────────────────────────────────────────────
  Widget _buildRack(double availW) {
    final rows       = _byRow;
    final sortedKeys = rows.keys.toList()..sort();

    // cellW for each row type — total row always == availW
    final cellW15 = availW / _rowACount;   // row A
    final cellW35 = availW / _rowBECount;  // rows B-E

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.isDark ? AppDS.surface2 : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.appBorder2, width: 1.5),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha:0.35),
          blurRadius: 18, offset: const Offset(0, 5))]),
      child: Column(
        children: sortedKeys.map((rowIdx) {
          final isTop   = rowIdx == 0;
          final cellW   = isTop ? cellW15 : cellW35;
          final rowH    = isTop ? _rowHTop : _rowHMain;
          final padding = isTop ? 12.0 : 4.0;
          return Padding(
            padding: EdgeInsets.only(bottom: padding),
            child: _buildRow(rowIdx, rows[rowIdx]!, isTop, cellW, rowH),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRow(
    int rowIdx, List<ZebrafishTank> tanks,
    bool isTop, double cellW, double rowH) {

    final label = _rowLabels[rowIdx];

    return SizedBox(
      height: rowH,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Row label
          SizedBox(
            width: _labelW,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isTop) ...[
                  Text('TOP', style: GoogleFonts.jetBrainsMono(
                    fontSize: 9, color: AppDS.accent,
                    fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                ],
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: context.appSurface3,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: context.appBorder)),
                  child: Center(child: Text(label,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12, fontWeight: FontWeight.w700,
                      color: context.appTextPrimary))),
                ),
                if (!isTop) ...[
                  const SizedBox(height: 3),
                  Text('3.5L', style: GoogleFonts.jetBrainsMono(
                    fontSize: 8, color: context.appTextMuted)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Tank cells — Expanded fills remaining width = availW exactly
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: () {
                // A merged (8L / 3.0L) tank absorbs the slot to its right,
                // so we skip that right neighbour to keep total flex = row count.
                final widgets = <Widget>[];
                bool skipNext = false;
                for (final t in tanks) {
                  if (skipNext) { skipNext = false; continue; }
                  widgets.add(Expanded(
                    flex: t.isEightLiter ? 2 : 1,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: _gap),
                      child: _tankCell(t, isTop),
                    ),
                  ));
                  if (t.isEightLiter) skipNext = true;
                }
                return widgets;
              }(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Single tank cell ──────────────────────────────────────────────────────
  Widget _tankCell(ZebrafishTank tank, bool isTop) {
    final occupied = _isOccupied(tank);
    final hasFish  = _hasFish(tank);
    final isSent   = _isSentinel(tank);

    // Colors — light rack background, vivid fills for contrast
    final Color bg, border;
    if (isSent) {
      bg     = AppDS.pink.withValues(alpha:0.22);
      border = AppDS.pink.withValues(alpha:0.80);
    } else {
      switch (tank.zebraStatus) {
        case 'quarantine':
          bg = AppDS.yellow.withValues(alpha:0.22); border = AppDS.yellow.withValues(alpha:0.75); break;
        case 'retired':
          bg = AppDS.red.withValues(alpha:0.12);    border = AppDS.red.withValues(alpha:0.55);    break;
        case 'active':
          if (hasFish) {
            bg = AppDS.green.withValues(alpha:0.30); border = AppDS.green.withValues(alpha:0.65);
          } else {
            bg = AppDS.accent.withValues(alpha:0.12); border = AppDS.accent.withValues(alpha:0.40);
          }
          break;
        default: // empty
          bg = (context.isDark ? AppDS.surface3 : Colors.white).withValues(alpha:0.80); border = const Color(0xFFBDD4E8);
      }
    }

    // Text colors: dark on light rack background
    const kTextLine   = Color(0xFF0F172A);  // occupied line name
    const kTextNum    = Color(0xFF334155);  // fish counts
    const kTextCol    = Color(0xFF64748B);  // column number
    const kTextColEmp = Color(0xFFB0CADA); // column on empty

    // Health dot
    final Color healthDot = switch (tank.zebraHealthStatus) {
      'sick'        => AppDS.red,
      'treatment'   => AppDS.orange,
      'observation' => AppDS.yellow,
      _             => AppDS.green,
    };

    return GestureDetector(
      onTapUp:          (d) => _showMenu(tank, d.globalPosition),
      onSecondaryTapUp: (d) => _showMenu(tank, d.globalPosition),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Tooltip(
          message: _tooltip(tank),
          preferBelow: false,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: border,
                width: (occupied || isSent) ? 1.5 : 1)),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Stack(clipBehavior: Clip.hardEdge, children: [
                // Main text content
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tank.zebraColumn ?? '',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9.5,
                        color: occupied ? kTextCol : kTextColEmp),
                      overflow: TextOverflow.clip),
                    if (isTop && _showLabels && occupied && tank.zebraLine != null) ...[
                      const SizedBox(height: 1),
                      Text(tank.zebraLine!,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 8.5, fontWeight: FontWeight.w700,
                          color: isSent ? AppDS.pink : kTextLine),
                        overflow: TextOverflow.ellipsis, maxLines: 1),
                    ],
                    if (!isTop && _showLabels && occupied) ...[
                      const SizedBox(height: 1),
                      if (tank.zebraLine != null)
                        Text(tank.zebraLine!,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 10.0, fontWeight: FontWeight.w700,
                            color: isSent ? AppDS.pink : kTextLine),
                          overflow: TextOverflow.ellipsis, maxLines: 1),
                      const SizedBox(height: 1),
                      if (hasFish)
                        Text(
                          '♂${tank.zebraMales ?? 0} ♀${tank.zebraFemales ?? 0}'
                          '${(tank.zebraJuveniles ?? 0) > 0 ? ' J${tank.zebraJuveniles}' : ''}',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 9.0, color: kTextNum),
                          overflow: TextOverflow.clip)
                      else
                        Text('no fish',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 9.0, color: AppDS.accent,
                            fontStyle: FontStyle.italic)),
                      if (tank.zebraFoodType?.isNotEmpty == true) ...[
                        Text(
                          tank.zebraFoodType!,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 8.0, color: const Color(0xFF9B6B1A)),
                          overflow: TextOverflow.ellipsis, maxLines: 1),
                        if (tank.zebraFeedingSchedule?.isNotEmpty == true ||
                            tank.zebraFoodAmount != null)
                          Text(
                            [
                              if (tank.zebraFeedingSchedule?.isNotEmpty == true)
                                tank.zebraFeedingSchedule!,
                              if (tank.zebraFoodAmount != null)
                                '(${tank.zebraFoodAmount! % 1 == 0 ? tank.zebraFoodAmount!.toInt() : tank.zebraFoodAmount}${tank.zebraFeedingAmountUnit != null ? ' ${tank.zebraFeedingAmountUnit}' : ''})',
                            ].join(' '),
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 8.0, color: const Color(0xFF9B6B1A)),
                            overflow: TextOverflow.ellipsis, maxLines: 1),
                      ],
                      if (tank.zebraResponsible?.isNotEmpty == true)
                        Text(tank.zebraResponsible!,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 8.5, color: kTextCol),
                          overflow: TextOverflow.ellipsis, maxLines: 1),
                    ],
                  ],
                ),
                // Volume badge (non-top only)
                if (!isTop)
                  Positioned(top: 0, right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 3, vertical: 1),
                      decoration: BoxDecoration(
                        color: context.isDark ? AppDS.surface3 : const Color(0xFFDDE9F5),
                        borderRadius: BorderRadius.circular(3)),
                      child: Text(tank.volumeLabel,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 8.5, color: context.appTextSecondary)))),
                // Health dot
                if (occupied)
                  Positioned(bottom: 1, right: 2,
                    child: Container(width: 5, height: 5,
                      decoration: BoxDecoration(
                        color: healthDot, shape: BoxShape.circle))),
                // merge badge (2.4L for top row, 8L for main rows)
                if (tank.isEightLiter)
                  Positioned(bottom: 1, left: 3,
                    child: Text(tank.isTopRow ? '2.4L' : '8L',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 7, color: AppDS.accent,
                        fontWeight: FontWeight.w700))),
                // Sentinel pink dot top-left
                if (isSent)
                  Positioned(top: 0, left: 0,
                    child: Container(width: 5, height: 5,
                      decoration: const BoxDecoration(
                        color: AppDS.pink,
                        shape: BoxShape.circle))),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  String _tooltip(ZebrafishTank t) => [
    '${t.zebraTankId}  ·  ${t.volumeLabel}',
    if (_isSentinel(t))  '★ Sentinel tank',
    'Status: ${t.zebraStatus ?? "empty"}',
    if (t.zebraLine != null) 'Line: ${t.zebraLine}',
    if (_hasFish(t))
      '♂${t.zebraMales ?? 0}  ♀${t.zebraFemales ?? 0}'
      '${(t.zebraJuveniles ?? 0) > 0 ? "  J${t.zebraJuveniles}" : ""}',
    if (_isOccupied(t) && !_hasFish(t)) 'Active — no fish',
  ].join('\n');

  // ── Context menu ──────────────────────────────────────────────────────────
  void _showMenu(ZebrafishTank tank, Offset globalPos) {
    final box = context.findRenderObject() as RenderBox?;
    final local = box != null ? box.globalToLocal(globalPos) : globalPos;
    setState(() { _menuTank = tank; _menuOffset = local; });
  }

  Widget _buildContextMenu() {
    final tank    = _menuTank!;
    final box     = context.findRenderObject() as RenderBox?;
    final sz      = box?.size ?? MediaQuery.of(context).size;
    double l = _menuOffset.dx, t = _menuOffset.dy;
    const mw = 226.0, mh = 360.0;
    if (l + mw > sz.width)  l = sz.width  - mw - 8;
    if (t + mh > sz.height) t = sz.height - mh - 8;
    if (l < 4) l = 4;
    if (t < 4) t = 4;

    final isSent = _isSentinel(tank);
    final isOcc  = _isOccupied(tank);

    return Positioned(
      left: l, top: t,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: mw,
          decoration: BoxDecoration(
            color: context.appSurface2,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: context.appBorder2),
            boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha:0.55),
              blurRadius: 22, offset: const Offset(0, 5))]),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: context.appBorder))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(tank.zebraTankId,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12, fontWeight: FontWeight.w700,
                        color: AppDS.accent)),
                    const SizedBox(width: 6),
                    StatusBadge(label: tank.zebraStatus),
                    if (isSent) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppDS.pink.withValues(alpha:0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppDS.pink.withValues(alpha:0.4))),
                        child: Text('SENTINEL',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 8, fontWeight: FontWeight.w700,
                            color: AppDS.pink))),
                    ],
                  ]),
                  if (tank.zebraLine != null) ...[
                    const SizedBox(height: 2),
                    Text(tank.zebraLine!,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 11, color: context.appTextSecondary)),
                  ],
                  Text(tank.volumeLabel,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9, color: context.appTextMuted)),
                ],
              ),
            ),

            _mi(Icons.info_outline,  'View Details', context.appTextPrimary, () {
              setState(() => _menuTank = null);
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => TankDetailPage(tank: tank, availableRacks: _racks.keys.toList()..sort())));
            }),
            if (!isOcc)
              _mi(Icons.add_circle_outline, 'Add Stock', AppDS.accent, () {
                setState(() => _menuTank = null);
                _showAddStockDialog(tank);
              }),
            if (isOcc)
              _mi(Icons.copy_outlined, 'Duplicate Stock', AppDS.purple, () {
                setState(() => _menuTank = null);
                _showDuplicateStockDialog(tank);
              }),
            if (isOcc || (tank.zebraLine?.isNotEmpty ?? false))
              _mi(Icons.edit_outlined, 'Edit Tank', context.appTextPrimary, () {
                setState(() => _menuTank = null);
                _showEditDialog(tank);
              }),

            // Mark active (no fish) vs clear
            if (!isOcc)
              _mi(Icons.check_circle_outline, 'Mark Active (no fish)',
                AppDS.accent, () {
                  final u = tank.copyWith(zebraStatus: 'active');
                  setState(() { _patch(u); _menuTank = null; });
                  _persist(u);
                })
            else
              _mi(Icons.remove_circle_outline, 'Clear Tank',
                AppDS.orange, () async {
                  setState(() => _menuTank = null);
                  final ok = await showConfirmDialog(context,
                    title: 'Clear Tank',
                    message: 'Remove all data from ${tank.zebraTankId}?',
                    confirmLabel: 'Clear',
                    confirmColor: AppDS.orange);
                  if (ok && mounted) {
                    final u = tank.copyWith(
                      zebraStatus: 'empty',
                      zebraLine: null,
                      zebraMales: 0,  zebraFemales: 0, zebraJuveniles: 0,
                      zebraTankType: 'holding');
                    setState(() => _patch(u));
                    _persist(u);
                  }
                }),

            // Toggle sentinel
            _mi(
              isSent ? Icons.star_outline : Icons.star,
              isSent ? 'Remove Sentinel' : 'Mark as Sentinel',
              AppDS.pink,
              () {
                final u = tank.copyWith(
                  zebraTankType: isSent ? 'holding' : 'sentinel',
                  zebraStatus:   isSent ? tank.zebraStatus : 'active');
                setState(() { _patch(u); _menuTank = null; });
                _persist(u);
              }),

            // merge toggle — last column cannot merge (no right neighbour)
            if (tank.isEightLiter ||
                (tank.isTopRow
                    ? tank.rackColIndex < _rowACount
                    : tank.rackColIndex < _rowBECount))
            _mi(Icons.swap_horiz,
              tank.isEightLiter
                ? (tank.isTopRow ? 'Revert to 2 × 1.1 L' : 'Revert to 2 × 3.5 L')
                : (tank.isTopRow ? 'Convert to 2.4 L'    : 'Convert to 8.0 L'),
              AppDS.accent, () {
                final next  = !tank.isEightLiter;
                final volL  = next
                    ? (tank.isTopRow ? 2.4 : 8.0)
                    : (tank.isTopRow ? 1.5 : 3.5);
                final u = tank.copyWith(isEightLiter: next, zebraVolumeL: volL);
                setState(() { _patch(u); _menuTank = null; });
                _persist(u);
              }),

            _mi(Icons.print_outlined, 'Quick Print', context.appTextPrimary, () {
              setState(() => _menuTank = null);
              final lineVal = tank.zebraLine ?? '';
              showQuickPrintDialog(
                context,
                category: 'Stocks',
                entityId: tank.zebraId != null && tank.zebraId! > 0
                    ? tank.zebraId.toString()
                    : null,
                data: {
                  'fish_stocks_tank_id':     tank.zebraTankId,
                  'fish_stocks_line':        lineVal,
                  'fish_line_name':          lineVal,
                  'fish_stocks_males':       (tank.zebraMales ?? 0).toString(),
                  'fish_stocks_females':     (tank.zebraFemales ?? 0).toString(),
                  'fish_stocks_juveniles':   (tank.zebraJuveniles ?? 0).toString(),
                  'fish_stocks_status':      tank.zebraStatus ?? '',
                  'fish_stocks_responsible': tank.zebraResponsible ?? '',
                },
              );
            }),

            Divider(height: 1, color: context.appBorder),
            _mi(Icons.refresh, 'Reset to Empty', AppDS.red, () async {
              setState(() => _menuTank = null);
              final ok = await showConfirmDialog(context,
                title: 'Reset Tank',
                message: 'Permanently clear ${tank.zebraTankId}?\nThis will delete the stock record from the database.',
                confirmLabel: 'Reset');
              if (ok && mounted) {
                await _deleteStock(tank);
              }
            }),
          ]),
        ),
      ),
    );
  }

  Widget _mi(IconData icon, String label, Color color, VoidCallback fn) =>
    InkWell(
      onTap: fn,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 10),
          Text(label, style: GoogleFonts.spaceGrotesk(
            fontSize: 12.5, color: color)),
        ]),
      ),
    );

  // ── Edit dialog ───────────────────────────────────────────────────────────
  void _showEditDialog(ZebrafishTank tank) {
    final occupied = _occupiedTankIds.difference({tank.zebraTankId});
    final racks    = _racks.keys.toList()..sort();
    void onSave(ZebrafishTank u) {
      setState(() {
        // if position changed, clear the old slot first
        if (u.zebraTankId != tank.zebraTankId) {
          _patch(tank.copyWith(
            zebraStatus: 'empty', zebraLine: null,
            zebraMales: 0, zebraFemales: 0, zebraJuveniles: 0,
          ));
        }
        _patch(u);
      });
      _persist(u);
    }

    if (MediaQuery.of(context).size.width < 600) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
          child: _EditTankDialogMobile(
            tank: tank,
            occupiedTankIds: occupied,
            availableRacks: racks,
            onSave: onSave,
          ),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (_) => _EditTankDialog(
          tank: tank,
          occupiedTankIds: occupied,
          availableRacks: racks,
          onSave: onSave,
        ),
      );
    }
  }

  Set<String> get _occupiedTankIds =>
      _racks.values.expand((l) => l).where(_isOccupied).map((t) => t.zebraTankId).toSet();

  void _showAddStockDialog(ZebrafishTank tank) {
    showDialog(
      context: context,
      builder: (_) => AddStockDialog(
        occupiedTankIds: _occupiedTankIds,
        availableRacks: _racks.keys.toList()..sort(),
        onAdd: (_) => _loadFromSupabase(),
        prefill: FishStockPrefill(
          rack: tank.zebraRack ?? 'R1',
          row:  tank.zebraRow  ?? 'B',
          col:  int.tryParse(tank.zebraColumn ?? '1') ?? 1,
        ),
      ),
    );
  }

  /// Returns (rack, row, col) of the closest available tank to [source],
  /// searching outward same-row first, then other rows, then other racks.
  (String, String, int)? _closestAvailable(ZebrafishTank source) {
    final occupied = _occupiedTankIds;
    final srcRack = source.zebraRack ?? 'R1';
    final srcRow  = source.zebraRow  ?? 'B';
    final srcCol  = int.tryParse(source.zebraColumn ?? '1') ?? 1;

    bool free(String rack, String row, int col) =>
        !occupied.contains('$rack-$row$col');

    // Same rack+row, outward from source column
    final maxColSameRow = srcRow == 'A' ? _rowACount : _rowBECount;
    for (int d = 1; d <= maxColSameRow; d++) {
      for (final c in [srcCol + d, srcCol - d]) {
        if (c >= 1 && c <= maxColSameRow && free(srcRack, srcRow, c)) {
          return (srcRack, srcRow, c);
        }
      }
    }
    // Same rack, other rows
    for (final row in _rowLabels) {
      if (row == srcRow) continue;
      final maxC = row == 'A' ? _rowACount : _rowBECount;
      for (int c = 1; c <= maxC; c++) {
        if (free(srcRack, row, c)) return (srcRack, row, c);
      }
    }
    // Other racks
    for (final rack in _racks.keys) {
      if (rack == srcRack) continue;
      for (final row in _rowLabels) {
        final maxC = row == 'A' ? _rowACount : _rowBECount;
        for (int c = 1; c <= maxC; c++) {
          if (free(rack, row, c)) return (rack, row, c);
        }
      }
    }
    return null;
  }

  Future<void> _showDuplicateStockDialog(ZebrafishTank tank) async {
    Map<String, dynamic>? rawRow;
    try {
      rawRow = await Supabase.instance.client
          .from('fish_stocks')
          .select()
          .eq('fish_stocks_tank_id', tank.zebraTankId)
          .maybeSingle();
    } catch (_) {}
    if (!mounted) return;
    final closest = _closestAvailable(tank);
    showDialog(
      context: context,
      builder: (_) => AddStockDialog(
        occupiedTankIds: _occupiedTankIds,
        availableRacks: _racks.keys.toList()..sort(),
        onAdd: (_) => _loadFromSupabase(),
        prefill: FishStockPrefill(
          line:            tank.zebraLine,
          responsible:     tank.zebraResponsible,
          experiment:      tank.zebraExperimentId,
          notes:           tank.zebraNotes,
          status:          tank.zebraStatus,
          health:          tank.zebraHealthStatus,
          males:           tank.zebraMales     ?? 0,
          females:         tank.zebraFemales   ?? 0,
          juveniles:       tank.zebraJuveniles ?? 0,
          foodType:        tank.zebraFoodType,
          foodSource:      tank.zebraFoodSource,
          foodAmount:      tank.zebraFoodAmount,
          feedingSchedule: tank.zebraFeedingSchedule,
          rack:            closest?.$1,
          row:             closest?.$2,
          col:             closest?.$3,
          rawRow:          rawRow,
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha:0.09),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha:0.22))),
    child: Text(label, style: GoogleFonts.spaceGrotesk(
      fontSize: 11, fontWeight: FontWeight.w600, color: color)),
  );

  // ── Legend ────────────────────────────────────────────────────────────────
  Widget _buildLegend() {
    return Wrap(spacing: 16, runSpacing: 8, children: [
      Text('Tank:', style: GoogleFonts.spaceGrotesk(
        fontSize: 11, color: context.appTextMuted, fontWeight: FontWeight.w700)),
      _li('Active + fish',   AppDS.green),
      _li('Active, no fish', AppDS.accent),
      _li('Sentinel',        AppDS.pink),
      _li('Quarantine',      AppDS.yellow),
      _li('Empty',           context.appTextMuted),
      _li('Retired',         AppDS.red),
      const SizedBox(width: 4),
      Text('Health:', style: GoogleFonts.spaceGrotesk(
        fontSize: 11, color: context.appTextMuted, fontWeight: FontWeight.w700)),
      _li('Healthy',     AppDS.green,  dot: true),
      _li('Observation', AppDS.yellow, dot: true),
      _li('Treatment',   AppDS.orange, dot: true),
      _li('Sick',        AppDS.red,    dot: true),
    ]);
  }

  Widget _li(String label, Color color, {bool dot = false}) =>
    Row(mainAxisSize: MainAxisSize.min, children: [
      dot
          ? Container(width: 7, height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle))
          : Container(width: 13, height: 13,
              decoration: BoxDecoration(
                color: color.withValues(alpha:0.15),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: color.withValues(alpha:0.45)))),
      const SizedBox(width: 4),
      Text(label, style: GoogleFonts.spaceGrotesk(
        fontSize: 11, color: context.appTextSecondary)),
    ]);

  // ── Add Rack dialog ───────────────────────────────────────────────────────
  void _showAddRackDialog() {
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: context.appSurface2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: context.appBorder2)),
      title: Text('Add Rack', style: GoogleFonts.spaceGrotesk(
        fontSize: 16, fontWeight: FontWeight.w700, color: context.appTextPrimary)),
      content: SizedBox(width: 280,
        child: TextField(
          controller: ctrl,
          autofocus: true,
          style: GoogleFonts.jetBrainsMono(color: context.appTextPrimary),
          decoration: InputDecoration(
            labelText: 'Rack name (e.g. R2)',
            labelStyle: GoogleFonts.spaceGrotesk(color: context.appTextSecondary),
            filled: true, fillColor: context.appSurface3,
            border: OutlineInputBorder(borderSide: BorderSide(color: context.appBorder)),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: AppDS.accent, width: 1.5))),
        )),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text('Cancel', style: GoogleFonts.spaceGrotesk(color: context.appTextSecondary))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppDS.accent, foregroundColor: AppDS.bg),
          onPressed: () {
            final name = ctrl.text.trim().toUpperCase();
            if (name.isNotEmpty && !_racks.containsKey(name)) {
              final defaultTanks = _buildDefaultRack(name);
              setState(() {
                _racks[name] = defaultTanks;
                _selectedRack = name;
              });
              for (final t in defaultTanks) { _persist(t); }
            }
            Navigator.pop(ctx);
          },
          child: const Text('Add')),
      ],
    ));
  }

  // ── Delete Rack dialog ────────────────────────────────────────────────────
  void _showDeleteRackDialog() {
    if (_racks.length <= 1) return;
    final rackId    = _selectedRack;
    final tankCount = (_racks[rackId] ?? []).length;
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: context.appSurface2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: context.appBorder2)),
      title: Text('Delete Rack $rackId?', style: GoogleFonts.spaceGrotesk(
        fontSize: 16, fontWeight: FontWeight.w700, color: AppDS.red)),
      content: Text(
        'This will permanently remove all $tankCount tank records for rack $rackId from the database.',
        style: GoogleFonts.spaceGrotesk(fontSize: 13, color: context.appTextSecondary)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text('Cancel', style: GoogleFonts.spaceGrotesk(color: context.appTextSecondary))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppDS.red, foregroundColor: Colors.white),
          onPressed: () async {
            Navigator.pop(ctx);
            try {
              await Supabase.instance.client
                  .from('fish_stocks')
                  .delete()
                  .eq('fish_stocks_rack', rackId);
            } catch (_) {}
            final remaining = _racks.keys.where((k) => k != rackId).toList()..sort();
            setState(() {
              _racks.remove(rackId);
              _selectedRack = remaining.first;
            });
          },
          child: const Text('Delete')),
      ],
    ));
  }

}

