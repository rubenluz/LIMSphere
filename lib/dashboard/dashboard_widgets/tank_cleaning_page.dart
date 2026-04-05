// tank_cleaning_page.dart - Tank cleaning log and schedule: lists pending and
// completed cleaning tasks, mark-done workflow.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/theme/theme.dart';

class TankCleaningPage extends StatefulWidget {
  const TankCleaningPage({super.key});

  @override
  State<TankCleaningPage> createState() => _TankCleaningPageState();
}

class _CleaningRow {
  final String tankId;
  final String line;
  final DateTime lastCleaning;
  final int intervalDays;
  final DateTime nextCleaning;
  final int daysLeft;

  const _CleaningRow({
    required this.tankId,
    required this.line,
    required this.lastCleaning,
    required this.intervalDays,
    required this.nextCleaning,
    required this.daysLeft,
  });
}

class _TankCleaningPageState extends State<TankCleaningPage> {
  List<_CleaningRow> _all = [];
  List<_CleaningRow> _filtered = [];
  bool _loading = true;
  int _windowDays = 7;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await Supabase.instance.client
          .from('fish_stocks')
          .select(
              'fish_stocks_tank_id, fish_stocks_line, fish_stocks_last_tank_cleaning, fish_stocks_cleaning_interval_days, fish_lines!fish_stocks_line_id(fish_line_name)')
          .eq('fish_stocks_status', 'active')
          .not('fish_stocks_last_tank_cleaning', 'is', null)
          .not('fish_stocks_cleaning_interval_days', 'is', null);

      final now = DateTime.now();
      final items = <_CleaningRow>[];

      for (final row in rows as List) {
        final last = DateTime.tryParse(row['fish_stocks_last_tank_cleaning'].toString());
        final interval = int.tryParse(row['fish_stocks_cleaning_interval_days'].toString());
        if (last == null || interval == null || interval <= 0) continue;

        final next = last.add(Duration(days: interval));
        final daysLeft = next.difference(now).inDays;

        final lineData = row['fish_lines'] as Map<String, dynamic>?;
        final lineName = lineData?['fish_line_name']?.toString()
            ?? row['fish_stocks_line']?.toString()
            ?? '—';

        items.add(_CleaningRow(
          tankId:      row['fish_stocks_tank_id']?.toString() ?? '—',
          line:        lineName,
          lastCleaning: last,
          intervalDays: interval,
          nextCleaning: next,
          daysLeft:    daysLeft,
        ));
      }

      items.sort((a, b) => a.daysLeft.compareTo(b.daysLeft));

      if (mounted) {
        setState(() {
          _all = items;
          _loading = false;
          _applyFilter();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilter() {
    setState(() {
      _filtered = _all.where((r) => r.daysLeft <= _windowDays).toList();
    });
  }

  Color _rowColor(int daysLeft) {
    if (daysLeft < 0)       return AppDS.red;
    if (daysLeft <= 3)      return AppDS.yellow;
    if (daysLeft <= 7)      return AppDS.orange;
    return AppDS.green;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBg,
      appBar: AppBar(
        backgroundColor: context.appSurface2,
        foregroundColor: context.appTextPrimary,
        iconTheme: IconThemeData(color: context.appTextPrimary),
        title: Row(children: [
          const Icon(Icons.cleaning_services_outlined, size: 18, color: AppDS.accent),
          const SizedBox(width: 8),
          Text('Tank Cleaning Schedule',
              style: GoogleFonts.spaceGrotesk(
                  color: context.appTextPrimary, fontWeight: FontWeight.w600, fontSize: 16)),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 18),
            onPressed: _load,
            tooltip: 'Refresh',
            color: context.appTextSecondary,
          ),
        ],
      ),
      body: Column(children: [
        // ── Filter bar ────────────────────────────────────────────────────────
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: context.appBg,
            border: Border(bottom: BorderSide(color: context.appBorder)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Text('Show:',
                style: GoogleFonts.spaceGrotesk(
                    color: context.appTextSecondary, fontSize: 13)),
            const SizedBox(width: 10),
            _FilterBtn(label: 'Next 3 days',
                selected: _windowDays == 3,
                onTap: () { setState(() => _windowDays = 3); _applyFilter(); }),
            const SizedBox(width: 8),
            _FilterBtn(label: 'Next 7 days',
                selected: _windowDays == 7,
                onTap: () { setState(() => _windowDays = 7); _applyFilter(); }),
            const Spacer(),
            if (!_loading)
              Text('${_filtered.length} tank${_filtered.length == 1 ? '' : 's'}',
                  style: GoogleFonts.spaceGrotesk(
                      color: context.appTextMuted, fontSize: 12)),
          ]),
        ),
        // ── Column header ─────────────────────────────────────────────────────
        Container(
          height: 32,
          color: context.appSurface2,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            const SizedBox(width: 3), // accent strip space
            _Hdr('TANK', flex: 2),
            _Hdr('LINE', flex: 4),
            _Hdr('LAST CLEAN', flex: 2),
            _Hdr('INTERVAL', flex: 2),
            _Hdr('NEXT CLEAN', flex: 2),
            _Hdr('STATUS', flex: 3),
          ]),
        ),
        Container(height: 1, color: context.appBorder),
        // ── Rows ──────────────────────────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _filtered.isEmpty
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.cleaning_services_outlined,
                            size: 48, color: context.appTextMuted),
                        const SizedBox(height: 12),
                        Text(
                          'No tanks due in the next $_windowDays days.',
                          style: GoogleFonts.spaceGrotesk(
                              color: context.appTextMuted, fontSize: 15),
                        ),
                      ]),
                    )
                  : ListView.builder(
                      itemCount: _filtered.length,
                      itemExtent: 44,
                      itemBuilder: (_, i) {
                        final r = _filtered[i];
                        final color = _rowColor(r.daysLeft);
                        final statusLabel = r.daysLeft < 0
                            ? '${r.daysLeft.abs()}d overdue'
                            : '${r.daysLeft}d left';

                        return Container(
                          decoration: BoxDecoration(
                            color: i.isEven ? context.appSurface : context.appBg,
                            border: Border(
                                bottom: BorderSide(color: context.appBorder)),
                          ),
                          child: Row(children: [
                            // Left accent strip
                            Container(width: 3, color: color),
                            const SizedBox(width: 13),
                            Expanded(flex: 2, child: _Cell(r.tankId, mono: true)),
                            Expanded(flex: 4, child: _Cell(r.line)),
                            Expanded(
                                flex: 2,
                                child: _Cell(
                                    r.lastCleaning
                                        .toIso8601String()
                                        .substring(0, 10),
                                    mono: true)),
                            Expanded(
                                flex: 2,
                                child: _Cell('${r.intervalDays}d', mono: true)),
                            Expanded(
                                flex: 2,
                                child: _Cell(
                                    r.nextCleaning
                                        .toIso8601String()
                                        .substring(0, 10),
                                    mono: true)),
                            Expanded(
                              flex: 3,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 9),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                        color: color.withValues(alpha: 0.35)),
                                  ),
                                  child: Text(statusLabel,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.jetBrainsMono(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: color)),
                                ),
                              ),
                            ),
                          ]),
                        );
                      },
                    ),
        ),
      ]),
    );
  }
}

// ── Local helpers ─────────────────────────────────────────────────────────────

class _Hdr extends StatelessWidget {
  final String label;
  final int flex;
  const _Hdr(this.label, {this.flex = 1});

  @override
  Widget build(BuildContext context) => Expanded(
        flex: flex,
        child: Text(label,
            style: GoogleFonts.spaceGrotesk(
                color: context.appTextMuted,
                fontSize: 10,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w600)),
      );
}

class _Cell extends StatelessWidget {
  final String text;
  final bool mono;
  const _Cell(this.text, {this.mono = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(text,
            overflow: TextOverflow.ellipsis,
            style: mono
                ? GoogleFonts.jetBrainsMono(
                    color: context.appTextSecondary, fontSize: 12)
                : GoogleFonts.spaceGrotesk(
                    color: context.appTextSecondary, fontSize: 12)),
      );
}

class _FilterBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterBtn(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppDS.accent.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: selected ? AppDS.accent : context.appBorder),
        ),
        child: Text(label,
            style: GoogleFonts.spaceGrotesk(
                color: selected ? AppDS.accent : context.appTextSecondary,
                fontSize: 12,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.normal)),
      ),
    );
  }
}
