// maintenance_overview_widget.dart - Dashboard widget showing water QC
// maintenance items: last done, next due date, and status badge.
// Data source: water_qc_maintenance table (key, last_done_date, optimal_days).

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io' show Platform;
import '../../theme/theme.dart';

class MaintenanceOverviewWidget extends StatefulWidget {
  const MaintenanceOverviewWidget({super.key});

  @override
  State<MaintenanceOverviewWidget> createState() =>
      _MaintenanceOverviewWidgetState();
}

class _MaintenanceOverviewWidgetState
    extends State<MaintenanceOverviewWidget> {
  static const _accent = Color(0xFFA855F7); // purple

  static const _labels = <String, String>{
    'ph_calibration':           'pH Calibration',
    'conductivity_calibration': 'Conductivity Calibration',
    'temperature_check':        'Temperature Check',
    'ro_filter_sediment':       'RO pre-filter (Sediments 5µm)',
    'ro_filter_carbon':         'RO pre-filter (Active carbon)',
  };

  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await Supabase.instance.client
          .from('water_qc_maintenance')
          .select();
      if (!mounted) return;
      setState(() {
        _items = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _isDesktop(BuildContext context) {
    if (kIsWeb) return true;
    try {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        return true;
      }
    } catch (_) {}
    return MediaQuery.of(context).size.width >= 600;
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // Returns items sorted by urgency: overdue / never done first, due soon, ok.
  List<Map<String, dynamic>> get _sorted {
    final now = DateTime.now();
    int urgency(Map<String, dynamic> row) {
      final raw = row['last_done_date'];
      if (raw == null) return 0;
      final last = DateTime.tryParse(raw.toString());
      if (last == null) return 0;
      final days = (row['optimal_days'] as num?)?.toInt() ?? 30;
      final daysLeft = last.add(Duration(days: days)).difference(now).inDays;
      if (daysLeft < 0) return 0;
      if (daysLeft <= 7) return 1;
      return 2;
    }

    return [..._items]..sort((a, b) => urgency(a).compareTo(urgency(b)));
  }

  Widget _buildList(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'No maintenance data',
          style: GoogleFonts.spaceGrotesk(
              color: context.appTextMuted, fontSize: 13),
        ),
      );
    }

    final now = DateTime.now();

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: _sorted.length,
      separatorBuilder: (_, _) =>
          Divider(height: 1, color: context.appBorder, indent: 12, endIndent: 12),
      itemBuilder: (ctx, i) {
        final row = _sorted[i];
        final key = row['key']?.toString() ?? '';
        final label = _labels[key] ?? key;
        final rawDate = row['last_done_date'];
        final lastDate =
            rawDate != null ? DateTime.tryParse(rawDate.toString()) : null;
        final optimalDays = (row['optimal_days'] as num?)?.toInt() ?? 30;

        String lastStr = '—';
        String nextStr = '—';
        Color badgeColor = context.appTextMuted;
        String badgeStr = '—';

        if (lastDate != null) {
          lastStr = _fmtDate(lastDate);
          final nextDate = lastDate.add(Duration(days: optimalDays));
          nextStr = _fmtDate(nextDate);
          final daysLeft = nextDate.difference(now).inDays;
          if (daysLeft < 0) {
            badgeColor = AppDS.red;
            badgeStr = '${daysLeft.abs()}d overdue';
          } else if (daysLeft <= 7) {
            badgeColor = AppDS.yellow;
            badgeStr = daysLeft == 0 ? 'today' : 'in ${daysLeft}d';
          } else {
            badgeColor = AppDS.green;
            badgeStr = 'in ${daysLeft}d';
          }
        } else {
          badgeColor = AppDS.red;
          badgeStr = 'never done';
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: context.appTextPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.15),
                    border: Border.all(
                        color: badgeColor.withValues(alpha: 0.5)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    badgeStr,
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: badgeColor),
                  ),
                ),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.history_rounded,
                    size: 11, color: context.appTextMuted),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    'Last: $lastStr',
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.jetBrainsMono(
                        fontSize: 10, color: context.appTextMuted),
                  ),
                ),
                const SizedBox(width: 12),
                Icon(Icons.event_outlined,
                    size: 11, color: context.appTextMuted),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    'Next: $nextStr',
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.jetBrainsMono(
                        fontSize: 10, color: context.appTextSecondary),
                  ),
                ),
              ]),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final desktop = _isDesktop(context);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: _accent, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      height: desktop ? 400 : null,
      child: Column(
        mainAxisSize: desktop ? MainAxisSize.max : MainAxisSize.min,
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
            child: Row(children: [
              const Icon(Icons.build_circle_outlined, size: 18, color: _accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Fish Facility Maintenance',
                  style: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: context.appTextPrimary),
                ),
              ),
              if (!_loading)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _accent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_items.length}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(Icons.refresh,
                    size: 16, color: context.appTextMuted),
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 24, minHeight: 24),
                tooltip: 'Refresh',
                onPressed: _load,
              ),
            ]),
          ),
          Divider(height: 1, color: context.appBorder),

          // ── List ──────────────────────────────────────────────────────────
          if (desktop)
            Expanded(
              child: SingleChildScrollView(child: _buildList(context)),
            )
          else
            _buildList(context),
        ],
      ),
    );
  }
}
