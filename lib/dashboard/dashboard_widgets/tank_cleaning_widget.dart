// tank_cleaning_widget.dart - Dashboard widget summarising tank cleaning status:
// overdue, due today, upcoming; colour-coded indicators.

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io' show Platform;
import '/theme/theme.dart';

/// Tank Cleaning Widget — Shows cleaning schedule summary for active fish stocks.
class TankCleaningWidget extends StatefulWidget {
  const TankCleaningWidget({super.key});

  @override
  State<TankCleaningWidget> createState() => _TankCleaningWidgetState();
}

class _TankCleaningWidgetState extends State<TankCleaningWidget> {
  int _overdue  = 0;
  int _soon3    = 0;
  int _soon7    = 0;
  int _ok       = 0;
  int _noSched  = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool _isDesktop(BuildContext context) {
    if (kIsWeb) return true;
    try {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) return true;
    } catch (_) {}
    return MediaQuery.of(context).size.width >= 600;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await Supabase.instance.client
          .from('fish_stocks')
          .select(
              'fish_stocks_last_tank_cleaning, fish_stocks_cleaning_interval_days')
          .eq('fish_stocks_status', 'active');

      int overdue = 0, soon3 = 0, soon7 = 0, ok = 0, noSched = 0;
      final now = DateTime.now();

      for (final row in rows as List) {
        final lastRaw     = row['fish_stocks_last_tank_cleaning'];
        final intervalRaw = row['fish_stocks_cleaning_interval_days'];
        if (lastRaw == null || intervalRaw == null) { noSched++; continue; }

        final last     = DateTime.tryParse(lastRaw.toString());
        final interval = int.tryParse(intervalRaw.toString());
        if (last == null || interval == null || interval <= 0) { noSched++; continue; }

        final daysLeft = last.add(Duration(days: interval)).difference(now).inDays;

        if (daysLeft < 0)       { overdue++; }
        else if (daysLeft <= 3) { soon3++;   }
        else if (daysLeft <= 7) { soon7++;   }
        else                    { ok++;      }
      }

      if (!mounted) return;
      setState(() {
        _overdue = overdue;
        _soon3   = soon3;
        _soon7   = soon7;
        _ok      = ok;
        _noSched = noSched;
        _loading = false;
      });
    } catch (e) {
      debugPrint('TankCleaningWidget error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _statusCard(String label, int count, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(50),
        border: Border.all(color: color.withAlpha(150)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: TextStyle(fontSize: 12, color: context.appTextPrimary))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(count.toString(),
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 13)),
        ),
      ]),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _statusCard('OVERDUE',      _overdue, Colors.red,    Icons.error_outline),
        const SizedBox(height: 6),
        _statusCard('Due ≤ 3 days', _soon3,   Colors.orange, Icons.schedule),
        const SizedBox(height: 6),
        _statusCard('Due ≤ 7 days', _soon7,   Colors.amber,  Icons.event_outlined),
        const SizedBox(height: 6),
        _statusCard('OK',           _ok,      Colors.green,  Icons.check_circle_outline),
        const SizedBox(height: 6),
        _statusCard('No schedule',  _noSched, Colors.grey,   Icons.help_outline),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final desktop = _isDesktop(context);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppDS.accent, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      height: desktop ? 360 : null,
      child: Column(
        mainAxisSize: desktop ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
            child: Row(children: [
              const Icon(Icons.cleaning_services_outlined,
                  size: 20, color: AppDS.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Tank Cleaning',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14,
                        color: context.appTextPrimary)),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 16),
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 24, minHeight: 24),
                onPressed: _load,
                tooltip: 'Refresh',
              ),
            ]),
          ),
          Divider(height: 1, color: context.appBorder),
          if (desktop)
            Expanded(
                child: SingleChildScrollView(child: _buildContent()))
          else
            _buildContent(),
        ],
      ),
    );
  }
}
