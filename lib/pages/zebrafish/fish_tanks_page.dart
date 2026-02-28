import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/models/connection_model.dart';
import 'shared_widgets.dart';
import 'tank_detail_page.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────
class _DS {
  static const Color bg        = Color(0xFF0F172A);
  static const Color surface   = Color(0xFF1E293B);
  static const Color surface2  = Color(0xFF1A2438);
  static const Color surface3  = Color(0xFF243044);
  static const Color border    = Color(0xFF334155);
  static const Color border2   = Color(0xFF2D3F55);
  static const Color accent    = Color(0xFF38BDF8);
  static const Color green     = Color(0xFF22C55E);
  static const Color yellow    = Color(0xFFEAB308);
  static const Color orange    = Color(0xFFF97316);
  static const Color red       = Color(0xFFEF4444);
  static const Color sentinel  = Color(0xFFEC4899); // pink — sentinel fish
  static const Color textPrimary   = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted     = Color(0xFF64748B);
}

// ─── ZebTec rack geometry ─────────────────────────────────────────────────────
//
//  Row A  : 15 positions × 1.5 L   (top shelf)
//  Rows B-E: 10 positions × 3.5 L  (main rack)
//
//  Proportionality rule (same total row width for ALL rows):
//    15 × cellW_1.5  ==  10 × cellW_3.5
//    => cellW_1.5 = availableW / 15
//    => cellW_3.5 = availableW / 10
//    => 8L slot    = 2 × cellW_3.5   (merges 2 adjacent 3.5L positions)
//
//  We use a LayoutBuilder to compute availableW at runtime so the rack
//  always fills the full container width regardless of window size.

const _rowLabels  = ['A', 'B', 'C', 'D', 'E'];
const _rowACount  = 15;    // 1.5 L
const _rowBECount = 10;    // 3.5 L
const _labelW     = 44.0;  // row-label column width
const _gap        = 3.0;   // inner padding per cell (each side)
const _rowHTop    = 54.0;  // row A cell height
const _rowHMain   = 82.0;  // rows B-E cell height

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
  bool    _showLabels   = true;
  bool    _loading      = true;
  String? _error;

  final Map<String, List<ZebrafishTank>> _racks = {
    'R1': _buildDefaultRack('R1'),
    'R2': _buildDefaultRack('R2'),
    'R3': _buildDefaultRack('R3'),
  };

  ZebrafishTank? _menuTank;
  Offset         _menuOffset = Offset.zero;

  @override
  void initState() {
    super.initState();
    _loadFromSupabase();
  }

  String? _canonicalTankId(Map<String, dynamic> row) {
    final raw = (row['fish_tank_id']?.toString() ?? '').trim().toUpperCase();
    final rack = (row['fish_rack']?.toString() ?? '').trim().toUpperCase();
    final r = (row['fish_row']?.toString() ?? '').trim().toUpperCase();
    final c = (row['fish_column']?.toString() ?? '').trim();

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
  Future<void> _loadFromSupabase() async {
    try {
      final rows = await Supabase.instance.client
          .from('fish_stocks')
          .select()
          .order('fish_rack')
          .order('fish_row')
          .order('fish_column') as List<dynamic>;

      for (final row in rows) {
        final data = Map<String, dynamic>.from(row as Map);
        final id = _canonicalTankId(data);
        if (id == null) continue;
        for (final list in _racks.values) {
          final idx = list.indexWhere((t) => t.zebraTankId == id);
          if (idx >= 0) { list[idx] = _fromRow(data, list[idx]); break; }
        }
      }
      setState(() => _loading = false);
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  ZebrafishTank _fromRow(Map<String, dynamic> r, ZebrafishTank def) =>
    def.copyWith(
      zebraLine:         r['fish_line'],
      zebraGenotype:     r['fish_genotype'],
      zebraMales:        r['fish_males'],
      zebraFemales:      r['fish_females'],
      zebraJuveniles:    r['fish_juveniles'],
      zebraResponsible:  r['fish_responsible'],
      zebraStatus:       r['fish_status'] ?? 'empty',
      zebraHealthStatus: r['fish_health_status'] ?? 'healthy',
      zebraTankType:     (r['fish_sentinel_status'] == 'sentinel')
          ? 'sentinel'
          : (r['fish_tank_type'] ?? 'holding'),
      zebraExperimentId: r['fish_experiment_id'],
      zebraNotes:        r['fish_notes'],
      zebraTemperatureC: (r['fish_temperature_c'] as num?)?.toDouble(),
      zebraPh:           (r['fish_ph'] as num?)?.toDouble(),
    );

  Future<void> _persist(ZebrafishTank t) async {
    try {
      final isSentinel = t.zebraTankType == 'sentinel';
      final persistedTankType = isSentinel ? 'holding' : (t.zebraTankType ?? 'holding');
      await Supabase.instance.client.from('fish_stocks').upsert({
        'fish_tank_id':     t.zebraTankId,
        'fish_rack':        t.zebraRack,
        'fish_row':         t.zebraRow,
        'fish_column':      t.zebraColumn,
        'fish_volume_l':    t.zebraVolumeL,
        'fish_line':        t.zebraLine,
        'fish_genotype':    t.zebraGenotype,
        'fish_males':       t.zebraMales ?? 0,
        'fish_females':     t.zebraFemales ?? 0,
        'fish_juveniles':   t.zebraJuveniles ?? 0,
        'fish_responsible': t.zebraResponsible,
        'fish_status':      t.zebraStatus ?? 'empty',
        'fish_health_status': t.zebraHealthStatus ?? 'healthy',
        'fish_tank_type':   persistedTankType,
        'fish_sentinel_status': isSentinel ? 'sentinel' : 'none',
        'fish_experiment_id': t.zebraExperimentId,
        'fish_notes':       t.zebraNotes,
      }, onConflict: 'fish_tank_id');
    } catch (_) {}
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

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final tanks     = _rackTanks;
    final occupied  = tanks.where(_isOccupied).length;
    final empties   = tanks.where((t) => t.zebraStatus == 'empty').length;
    final sentinels = tanks.where(_isSentinel).length;

    return GestureDetector(
      onTap: () => setState(() => _menuTank = null),
      child: Stack(children: [
        Column(children: [
          // ── Toolbar ──────────────────────────────────────────────────
          Container(
            color: _DS.surface,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(children: [
              ..._racks.keys.map((r) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _rackTab(r))),
              const SizedBox(width: 12),
              _chip('${tanks.length} tanks',  _DS.textMuted),
              const SizedBox(width: 6),
              _chip('$occupied occupied',     _DS.green),
              const SizedBox(width: 6),
              _chip('$empties empty',         _DS.textSecondary),
              if (sentinels > 0) ...[
                const SizedBox(width: 6),
                _chip('$sentinels sentinel',  _DS.sentinel),
              ],
              const Spacer(),
              Text('Labels', style: GoogleFonts.spaceGrotesk(
                fontSize: 12, color: _DS.textSecondary)),
              const SizedBox(width: 6),
              Switch(value: _showLabels, activeColor: _DS.accent,
                onChanged: (v) => setState(() => _showLabels = v)),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.settings_outlined, size: 14),
                label: const Text('8 L'),
                onPressed: _showRackSettings,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _DS.textSecondary,
                  side: const BorderSide(color: _DS.border))),
            ]),
          ),
          Container(height: 1, color: _DS.border),

          // ── Body ─────────────────────────────────────────────────────
          if (_loading)
            const Expanded(child: Center(
              child: CircularProgressIndicator()))
          else if (_error != null)
            Expanded(child: Center(child: Text('Error: $_error',
              style: GoogleFonts.spaceGrotesk(color: _DS.red, fontSize: 13))))
          else
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _rackHeader(),
                    const SizedBox(height: 16),
                    LayoutBuilder(builder: (ctx, box) {
                      // Total width minus label column and its gap
                      final avail = box.maxWidth - _labelW - 8;
                      return _buildRack(avail);
                    }),
                    const SizedBox(height: 20),
                    _buildLegend(),
                  ],
                ),
              ),
            ),
        ]),
        if (_menuTank != null) _buildContextMenu(),
      ]),
    );
  }

  // ── Rack header ───────────────────────────────────────────────────────────
  Widget _rackHeader() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    decoration: BoxDecoration(
      color: _DS.surface2,
      borderRadius: BorderRadius.circular(8),
      border: const Border(left: BorderSide(color: _DS.accent, width: 3))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Tecniplast ZebTec — Rack $_selectedRack',
        style: GoogleFonts.spaceGrotesk(
          fontSize: 14, fontWeight: FontWeight.w700, color: _DS.textPrimary)),
      const SizedBox(height: 2),
      Text('Row A: 15 × 1.5 L  ·  Rows B-E: 10 × 3.5 L each  ·  '
        '2 × 3.5 L can be merged into 1 × 8 L',
        style: GoogleFonts.jetBrainsMono(
          fontSize: 10, color: _DS.textSecondary)),
    ]),
  );

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
        color: _DS.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _DS.border2, width: 1.5),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.35),
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
                    fontSize: 7, color: _DS.accent,
                    fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                ],
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: isTop
                        ? _DS.accent.withOpacity(0.15) : _DS.surface3,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isTop
                          ? _DS.accent.withOpacity(0.5) : _DS.border)),
                  child: Center(child: Text(label,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12, fontWeight: FontWeight.w700,
                      color: isTop ? _DS.accent : _DS.textMuted))),
                ),
                if (!isTop) ...[
                  const SizedBox(height: 3),
                  Text('3.5L', style: GoogleFonts.jetBrainsMono(
                    fontSize: 8, color: _DS.textMuted)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Tank cells — Expanded fills remaining width = availW exactly
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: tanks.map((t) {
                // 8L slot takes 2 × cellW
                final slotW = t.isEightLiter ? cellW * 2.0 : cellW;
                return SizedBox(
                  width: slotW,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: _gap),
                    child: _tankCell(t, isTop),
                  ),
                );
              }).toList(),
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

    // Colors
    final Color bg, border;
    if (isSent) {
      bg     = _DS.sentinel.withOpacity(0.12);
      border = _DS.sentinel.withOpacity(0.65);
    } else {
      switch (tank.zebraStatus) {
        case 'quarantine':
          bg = _DS.yellow.withOpacity(0.07); border = _DS.yellow.withOpacity(0.55); break;
        case 'retired':
          bg = _DS.red.withOpacity(0.04);    border = _DS.red.withOpacity(0.35);    break;
        case 'active':
          if (hasFish) {
            bg = _DS.green.withOpacity(0.07); border = _DS.border;
          } else {
            // Active but no fish: dashed-style accent
            bg = _DS.accent.withOpacity(0.05); border = _DS.accent.withOpacity(0.38);
          }
          break;
        default: // empty
          bg = _DS.surface2; border = _DS.border.withOpacity(0.28);
      }
    }

    // Health dot
    final Color healthDot = switch (tank.zebraHealthStatus) {
      'sick'        => _DS.red,
      'treatment'   => _DS.orange,
      'observation' => _DS.yellow,
      _             => _DS.green,
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
                        fontSize: 7.5,
                        color: occupied ? _DS.textMuted : _DS.border),
                      overflow: TextOverflow.clip),
                    if (!isTop && _showLabels && occupied) ...[
                      const SizedBox(height: 1),
                      if (tank.zebraLine != null)
                        Text(tank.zebraLine!,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 8.0, fontWeight: FontWeight.w700,
                            color: isSent ? _DS.sentinel : _DS.textPrimary),
                          overflow: TextOverflow.ellipsis, maxLines: 2),
                      const SizedBox(height: 1),
                      if (hasFish)
                        Text(
                          '♂${tank.zebraMales ?? 0} ♀${tank.zebraFemales ?? 0}'
                          '${(tank.zebraJuveniles ?? 0) > 0 ? ' J${tank.zebraJuveniles}' : ''}',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 7.0, color: _DS.textSecondary),
                          overflow: TextOverflow.clip)
                      else
                        Text('no fish',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 7.0, color: _DS.accent,
                            fontStyle: FontStyle.italic)),
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
                        color: _DS.surface3,
                        borderRadius: BorderRadius.circular(3)),
                      child: Text(tank.volumeLabel,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 6.5, color: _DS.textMuted)))),
                // Health dot
                if (occupied)
                  Positioned(bottom: 1, right: 2,
                    child: Container(width: 5, height: 5,
                      decoration: BoxDecoration(
                        color: healthDot, shape: BoxShape.circle))),
                // 8L badge
                if (tank.isEightLiter)
                  Positioned(bottom: 1, left: 3,
                    child: Text('8L',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 7, color: _DS.accent,
                        fontWeight: FontWeight.w700))),
                // Sentinel pink dot top-left
                if (isSent)
                  Positioned(top: 0, left: 0,
                    child: Container(width: 5, height: 5,
                      decoration: const BoxDecoration(
                        color: _DS.sentinel,
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
  void _showMenu(ZebrafishTank tank, Offset pos) {
    setState(() { _menuTank = tank; _menuOffset = pos; });
  }

  Widget _buildContextMenu() {
    final tank    = _menuTank!;
    final sz      = MediaQuery.of(context).size;
    double l = _menuOffset.dx, t = _menuOffset.dy;
    const mw = 226.0, mh = 360.0;
    if (l + mw > sz.width)  l = sz.width  - mw - 8;
    if (t + mh > sz.height) t = sz.height - mh - 8;
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
            color: _DS.surface2,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _DS.border2),
            boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.55),
              blurRadius: 22, offset: const Offset(0, 5))]),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: _DS.border))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(tank.zebraTankId,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12, fontWeight: FontWeight.w700,
                        color: _DS.accent)),
                    const SizedBox(width: 6),
                    StatusBadge(label: tank.zebraStatus),
                    if (isSent) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: _DS.sentinel.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _DS.sentinel.withOpacity(0.4))),
                        child: Text('SENTINEL',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 8, fontWeight: FontWeight.w700,
                            color: _DS.sentinel))),
                    ],
                  ]),
                  if (tank.zebraLine != null) ...[
                    const SizedBox(height: 2),
                    Text(tank.zebraLine!,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 11, color: _DS.textSecondary)),
                  ],
                  Text(tank.volumeLabel,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9, color: _DS.textMuted)),
                ],
              ),
            ),

            _mi(Icons.info_outline,  'View Details', _DS.textPrimary, () {
              setState(() => _menuTank = null);
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => TankDetailPage(tank: tank)));
            }),
            _mi(Icons.edit_outlined, 'Edit Tank', _DS.textPrimary, () {
              setState(() => _menuTank = null);
              _showEditDialog(tank);
            }),

            // Mark active (no fish) vs clear
            if (!isOcc)
              _mi(Icons.check_circle_outline, 'Mark Active (no fish)',
                _DS.accent, () {
                  final u = tank.copyWith(zebraStatus: 'active');
                  setState(() { _patch(u); _menuTank = null; });
                  _persist(u);
                })
            else
              _mi(Icons.remove_circle_outline, 'Clear Tank',
                _DS.orange, () async {
                  setState(() => _menuTank = null);
                  final ok = await showConfirmDialog(context,
                    title: 'Clear Tank',
                    message: 'Remove all data from ${tank.zebraTankId}?',
                    confirmLabel: 'Clear',
                    confirmColor: _DS.orange);
                  if (ok && mounted) {
                    final u = tank.copyWith(
                      zebraStatus: 'empty',
                      zebraLine: null, zebraGenotype: null,
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
              _DS.sentinel,
              () {
                final u = tank.copyWith(
                  zebraTankType: isSent ? 'holding' : 'sentinel',
                  zebraStatus:   isSent ? tank.zebraStatus : 'active');
                setState(() { _patch(u); _menuTank = null; });
                _persist(u);
              }),

            // 8L toggle
            if (!tank.isTopRow)
              _mi(Icons.swap_horiz,
                tank.isEightLiter ? 'Revert to 2 × 3.5 L' : 'Convert to 8 L',
                _DS.accent, () {
                  final next = !tank.isEightLiter;
                  final u = tank.copyWith(
                    isEightLiter: next, zebraVolumeL: next ? 8.0 : 3.5);
                  setState(() { _patch(u); _menuTank = null; });
                  _persist(u);
                }),

            const Divider(height: 1, color: _DS.border),
            _mi(Icons.refresh, 'Reset to Empty', _DS.red, () async {
              setState(() => _menuTank = null);
              final ok = await showConfirmDialog(context,
                title: 'Reset Tank',
                message: 'Permanently clear ${tank.zebraTankId}?',
                confirmLabel: 'Reset');
              if (ok && mounted) {
                final u = tank.copyWith(
                  zebraStatus: 'empty', zebraLine: null,
                  zebraGenotype: null,  zebraMales: 0,
                  zebraFemales: 0,      zebraJuveniles: 0,
                  zebraTankType: 'holding',
                  isEightLiter: false,
                  zebraVolumeL: tank.isTopRow ? 1.5 : 3.5);
                setState(() => _patch(u));
                _persist(u);
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
    showDialog(context: context, builder: (_) => _EditTankDialog(
      tank: tank,
      onSave: (u) { setState(() => _patch(u)); _persist(u); },
    ));
  }

  // ── 8L config dialog ──────────────────────────────────────────────────────
  void _showRackSettings() {
    showDialog(context: context, builder: (_) => _RackSettingsDialog(
      tanks: _rackTanks.where((t) => !t.isTopRow).toList(),
      onUpdate: (list) {
        setState(() { for (final t in list) _patch(t); });
        for (final t in list) _persist(t);
      },
    ));
  }

  // ── Toolbar widgets ───────────────────────────────────────────────────────
  Widget _rackTab(String rack) {
    final sel = _selectedRack == rack;
    return InkWell(
      onTap: () => setState(() => _selectedRack = rack),
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? _DS.accent.withOpacity(0.15) : _DS.surface2,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: sel ? _DS.accent : _DS.border, width: sel ? 1.5 : 1)),
        child: Text(rack, style: GoogleFonts.jetBrainsMono(
          fontSize: 12, fontWeight: FontWeight.w700,
          color: sel ? _DS.accent : _DS.textSecondary)),
      ),
    );
  }

  Widget _chip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.09),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.22))),
    child: Text(label, style: GoogleFonts.spaceGrotesk(
      fontSize: 11, fontWeight: FontWeight.w600, color: color)),
  );

  // ── Legend ────────────────────────────────────────────────────────────────
  Widget _buildLegend() {
    return Wrap(spacing: 16, runSpacing: 8, children: [
      Text('Tank:', style: GoogleFonts.spaceGrotesk(
        fontSize: 11, color: _DS.textMuted, fontWeight: FontWeight.w700)),
      _li('Active + fish',   _DS.green),
      _li('Active, no fish', _DS.accent),
      _li('Sentinel',        _DS.sentinel),
      _li('Quarantine',      _DS.yellow),
      _li('Empty',           _DS.textMuted),
      _li('Retired',         _DS.red),
      const SizedBox(width: 4),
      Text('Health:', style: GoogleFonts.spaceGrotesk(
        fontSize: 11, color: _DS.textMuted, fontWeight: FontWeight.w700)),
      _li('Healthy',     _DS.green,  dot: true),
      _li('Observation', _DS.yellow, dot: true),
      _li('Treatment',   _DS.orange, dot: true),
      _li('Sick',        _DS.red,    dot: true),
    ]);
  }

  Widget _li(String label, Color color, {bool dot = false}) =>
    Row(mainAxisSize: MainAxisSize.min, children: [
      dot
          ? Container(width: 7, height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle))
          : Container(width: 13, height: 13,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: color.withOpacity(0.45)))),
      const SizedBox(width: 4),
      Text(label, style: GoogleFonts.spaceGrotesk(
        fontSize: 11, color: _DS.textSecondary)),
    ]);
}

// ─── EDIT TANK DIALOG ─────────────────────────────────────────────────────────
class _EditTankDialog extends StatefulWidget {
  final ZebrafishTank tank;
  final ValueChanged<ZebrafishTank> onSave;
  const _EditTankDialog({required this.tank, required this.onSave});

  @override
  State<_EditTankDialog> createState() => _EditTankDialogState();
}

class _EditTankDialogState extends State<_EditTankDialog> {
  late TextEditingController _line, _geno, _males, _females, _juvs,
      _resp, _exp, _notes;
  late String _status, _health, _type;

  @override
  void initState() {
    super.initState();
    final t = widget.tank;
    _line   = TextEditingController(text: t.zebraLine ?? '');
    _geno   = TextEditingController(text: t.zebraGenotype ?? '');
    _males  = TextEditingController(text: '${t.zebraMales ?? 0}');
    _females= TextEditingController(text: '${t.zebraFemales ?? 0}');
    _juvs   = TextEditingController(text: '${t.zebraJuveniles ?? 0}');
    _resp   = TextEditingController(text: t.zebraResponsible ?? '');
    _exp    = TextEditingController(text: t.zebraExperimentId ?? '');
    _notes  = TextEditingController(text: t.zebraNotes ?? '');
    _status = t.zebraStatus ?? 'active';
    _health = t.zebraHealthStatus ?? 'healthy';
    _type   = t.zebraTankType ?? 'holding';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _DS.surface2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: _DS.border2)),
      title: Row(children: [
        Text('Edit ${widget.tank.zebraTankId}',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 16, fontWeight: FontWeight.w700, color: _DS.textPrimary)),
        const SizedBox(width: 8),
        StatusBadge(label: _status),
        const SizedBox(width: 6),
        Text(widget.tank.volumeLabel,
          style: GoogleFonts.jetBrainsMono(fontSize: 10, color: _DS.textMuted)),
      ]),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _f('Fish Line', _line),
            const SizedBox(height: 8),
            _f('Genotype', _geno),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _f('Males ♂', _males)),
              const SizedBox(width: 8),
              Expanded(child: _f('Females ♀', _females)),
              const SizedBox(width: 8),
              Expanded(child: _f('Juveniles', _juvs)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _dd('Status', _status,
                ['active', 'empty', 'quarantine', 'retired'],
                (v) => setState(() => _status = v ?? _status))),
              const SizedBox(width: 8),
              Expanded(child: _dd('Health', _health,
                ['healthy', 'observation', 'treatment', 'sick'],
                (v) => setState(() => _health = v ?? _health))),
              const SizedBox(width: 8),
              Expanded(child: _dd('Type', _type,
                ['holding', 'breeding', 'quarantine', 'experimental', 'sentinel'],
                (v) => setState(() => _type = v ?? _type))),
            ]),
            const SizedBox(height: 8),
            _f('Responsible', _resp),
            const SizedBox(height: 8),
            _f('Experiment ID', _exp, mono: true),
            const SizedBox(height: 8),
            _f('Notes', _notes),
          ],
        )),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            foregroundColor: _DS.textSecondary,
            side: const BorderSide(color: _DS.border)),
          child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _DS.accent, foregroundColor: _DS.bg),
          onPressed: () {
            widget.onSave(widget.tank.copyWith(
              zebraLine:        _line.text.isEmpty  ? null : _line.text,
              zebraGenotype:    _geno.text.isEmpty  ? null : _geno.text,
              zebraMales:       int.tryParse(_males.text),
              zebraFemales:     int.tryParse(_females.text),
              zebraJuveniles:   int.tryParse(_juvs.text),
              zebraResponsible: _resp.text.isEmpty  ? null : _resp.text,
              zebraStatus:      _status,
              zebraHealthStatus:_health,
              zebraTankType:    _type,
              zebraExperimentId:_exp.text.isEmpty   ? null : _exp.text,
              zebraNotes:       _notes.text.isEmpty ? null : _notes.text,
            ));
            Navigator.pop(context);
          },
          child: const Text('Save')),
      ],
    );
  }

  Widget _f(String l, TextEditingController c, {bool mono = false}) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(l, style: GoogleFonts.spaceGrotesk(
        fontSize: 11, color: _DS.textMuted, fontWeight: FontWeight.w700)),
      const SizedBox(height: 3),
      TextField(controller: c,
        style: (mono ? GoogleFonts.jetBrainsMono(fontSize: 13)
            : GoogleFonts.spaceGrotesk(fontSize: 13))
            .copyWith(color: _DS.textPrimary),
        decoration: InputDecoration(
          isDense: true, filled: true, fillColor: _DS.surface3,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: _DS.border)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: _DS.accent, width: 1.5)))),
    ]);

  Widget _dd(String l, String val, List<String> opts, ValueChanged<String?> cb) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(l, style: GoogleFonts.spaceGrotesk(
        fontSize: 11, color: _DS.textMuted, fontWeight: FontWeight.w700)),
      const SizedBox(height: 3),
      DropdownButtonFormField<String>(
        value: opts.contains(val) ? val : opts.first,
        dropdownColor: _DS.surface2,
        style: GoogleFonts.spaceGrotesk(color: _DS.textPrimary, fontSize: 13),
        items: opts.map((v) =>
          DropdownMenuItem(value: v, child: Text(v))).toList(),
        onChanged: cb,
        decoration: InputDecoration(
          isDense: true, filled: true, fillColor: _DS.surface3,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: _DS.border)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: _DS.accent, width: 1.5)))),
    ]);
}

// ─── 8L CONFIG DIALOG ────────────────────────────────────────────────────────
class _RackSettingsDialog extends StatefulWidget {
  final List<ZebrafishTank> tanks;
  final ValueChanged<List<ZebrafishTank>> onUpdate;
  const _RackSettingsDialog({required this.tanks, required this.onUpdate});

  @override
  State<_RackSettingsDialog> createState() => _RackSettingsDialogState();
}

class _RackSettingsDialogState extends State<_RackSettingsDialog> {
  late List<ZebrafishTank> _tanks;

  @override
  void initState() {
    super.initState();
    _tanks = List.from(widget.tanks);
  }

  @override
  Widget build(BuildContext context) {
    final byRow = <String, List<ZebrafishTank>>{};
    for (final t in _tanks) byRow.putIfAbsent(t.zebraRow ?? '?', () => []).add(t);
    final sortedRows = byRow.keys.toList()
      ..sort()
      ..removeWhere((k) => k == 'A');

    return AlertDialog(
      backgroundColor: _DS.surface2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: _DS.border2)),
      title: Text('8 L Slot Configuration',
        style: GoogleFonts.spaceGrotesk(
          fontSize: 16, fontWeight: FontWeight.w700, color: _DS.textPrimary)),
      content: SizedBox(width: 540, height: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tap any slot to toggle between 3.5 L and 8 L. '
              'An 8 L slot spans 2 adjacent positions.',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 12, color: _DS.textSecondary)),
            const SizedBox(height: 14),
            Expanded(child: SingleChildScrollView(
              child: Column(
                children: sortedRows.map(
                  (r) => _rowCfg(r, byRow[r]!)).toList()))),
          ],
        ),
      ),
      actions: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _DS.accent, foregroundColor: _DS.bg),
          onPressed: () {
            widget.onUpdate(_tanks);
            Navigator.pop(context);
          },
          child: const Text('Apply')),
      ],
    );
  }

  Widget _rowCfg(String row, List<ZebrafishTank> tanks) =>
    Padding(padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Row $row', style: GoogleFonts.spaceGrotesk(
          fontSize: 12, fontWeight: FontWeight.w700, color: _DS.textSecondary)),
        const SizedBox(height: 6),
        Wrap(spacing: 5, runSpacing: 5, children: tanks.map((t) {
          final is8 = t.isEightLiter;
          return InkWell(
            onTap: () {
              setState(() {
                final idx = _tanks.indexWhere(
                  (x) => x.zebraTankId == t.zebraTankId);
                if (idx >= 0) {
                  _tanks[idx] = _tanks[idx].copyWith(
                    isEightLiter: !is8, zebraVolumeL: !is8 ? 8.0 : 3.5);
                }
              });
            },
            borderRadius: BorderRadius.circular(5),
            child: Container(
              width: 54, height: 36,
              decoration: BoxDecoration(
                color: is8 ? _DS.accent.withOpacity(0.15) : _DS.surface3,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: is8 ? _DS.accent : _DS.border)),
              child: Column(mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(t.zebraColumn ?? '', style: GoogleFonts.jetBrainsMono(
                    fontSize: 9, color: _DS.textMuted)),
                  Text(is8 ? '8 L' : '3.5 L',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9, fontWeight: FontWeight.w700,
                      color: is8 ? _DS.accent : _DS.textMuted)),
                ]),
            ),
          );
        }).toList()),
      ]),
    );
}
