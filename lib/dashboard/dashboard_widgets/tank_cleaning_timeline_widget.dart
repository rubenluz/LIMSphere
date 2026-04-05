// tank_cleaning_timeline_widget.dart - Timeline of tank cleaning events;
// completion status colour coding; historical and upcoming view.

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io' show Platform;
import '/theme/theme.dart';

class TankCleaningTimelineWidget extends StatefulWidget {
  const TankCleaningTimelineWidget({super.key});

  @override
  State<TankCleaningTimelineWidget> createState() =>
      _TankCleaningTimelineWidgetState();
}

class _TankCleaningTimelineWidgetState
    extends State<TankCleaningTimelineWidget> {
  List<_CleaningEvent> _events = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
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

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await Supabase.instance.client
          .from('fish_stocks')
          .select(
              'fish_stocks_tank_id, fish_stocks_line, fish_stocks_last_tank_cleaning, fish_stocks_cleaning_interval_days')
          .eq('fish_stocks_status', 'active');

      final now = DateTime.now();
      final cutoff = now.add(const Duration(days: 30));
      final events = <_CleaningEvent>[];

      for (final row in rows as List) {
        final lastRaw = row['fish_stocks_last_tank_cleaning'];
        final intervalRaw = row['fish_stocks_cleaning_interval_days'];
        if (lastRaw == null || intervalRaw == null) { continue; }

        final last = DateTime.tryParse(lastRaw.toString());
        final interval = int.tryParse(intervalRaw.toString());
        if (last == null || interval == null || interval <= 0) { continue; }

        final next = last.add(Duration(days: interval));
        if (next.isAfter(cutoff)) { continue; }

        final tankId = (row['fish_stocks_tank_id'] ?? '').toString();
        final line = (row['fish_stocks_line'] ?? '').toString();
        final label = tankId.isNotEmpty
            ? (line.isNotEmpty ? '$tankId · $line' : tankId)
            : line;

        events.add(_CleaningEvent(label: label, date: next));
      }

      events.sort((a, b) => a.date.compareTo(b.date));
      if (mounted) { setState(() { _events = events; _loading = false; }); }
    } catch (e) {
      debugPrint('TankCleaningTimelineWidget error: $e');
      if (mounted) { setState(() => _loading = false); }
    }
  }

  Color _color(int daysLeft) {
    if (daysLeft < 0) { return Colors.red; }
    if (daysLeft == 0) { return Colors.orange; }
    if (daysLeft <= 3) { return Colors.amber; }
    return AppDS.green;
  }

  String _badge(int daysLeft) {
    if (daysLeft < 0) { return '${daysLeft.abs()}d overdue'; }
    if (daysLeft == 0) { return 'Today'; }
    return 'in ${daysLeft}d';
  }

  static String _weekday(int d) =>
      ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d - 1];
  static String _month(int m) =>
      ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
       'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m - 1];

  Widget _buildContent() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_events.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text('No tank cleanings due in the next 30 days.',
            style: TextStyle(color: context.appTextSecondary, fontSize: 13)),
      );
    }

    // Group by date (day only)
    final grouped = <DateTime, List<_CleaningEvent>>{};
    for (final e in _events) {
      final d = DateTime(e.date.year, e.date.month, e.date.day);
      grouped.putIfAbsent(d, () => []).add(e);
    }
    final dates = grouped.keys.toList()..sort();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(dates.length, (i) {
          final date = dates[i];
          final events = grouped[date]!;
          final daysLeft = date.difference(today).inDays;
          final color = _color(daysLeft);
          final isLast = i == dates.length - 1;
          final dateLabel =
              '${_weekday(date.weekday)} ${date.day} ${_month(date.month)}';

          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Timeline spine
                Column(children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(width: 2, color: context.appBorder),
                    ),
                ]),
                const SizedBox(width: 10),
                // Content
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text(dateLabel,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: color)),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(_badge(daysLeft),
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: color)),
                          ),
                        ]),
                        const SizedBox(height: 4),
                        ...events.map((e) => Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text('· ${e.label}',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: context.appTextPrimary),
                                  overflow: TextOverflow.ellipsis),
                            )),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
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
      height: desktop ? 400 : null,
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
                child: Text('Cleaning Timeline',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: context.appTextPrimary)),
              ),
            ]),
          ),
          Divider(height: 1, color: context.appBorder),
          if (desktop)
            Expanded(child: SingleChildScrollView(child: _buildContent()))
          else
            _buildContent(),
        ],
      ),
    );
  }
}

class _CleaningEvent {
  final String label;
  final DateTime date;
  const _CleaningEvent({required this.label, required this.date});
}
