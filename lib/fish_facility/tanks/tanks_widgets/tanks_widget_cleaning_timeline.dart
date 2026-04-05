import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/theme/theme.dart';

class TanksWidgetCleaningTimeline extends StatelessWidget {
  final List<({String label, DateTime date})> events;
  final bool loading;

  const TanksWidgetCleaningTimeline({
    super.key,
    required this.events,
    required this.loading,
  });

  static Color _color(int daysLeft) {
    if (daysLeft < 0)  return AppDS.red;
    if (daysLeft == 0) return AppDS.orange;
    if (daysLeft <= 3) return const Color(0xFFF59E0B);
    return AppDS.green;
  }

  static String _badge(int daysLeft) {
    if (daysLeft < 0)  return '${daysLeft.abs()}d overdue';
    if (daysLeft == 0) return 'Today';
    return 'in ${daysLeft}d';
  }

  static String _weekday(int d) =>
      ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d - 1];

  static String _month(int m) =>
      ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
       'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m - 1];

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (loading) {
      content = const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    } else if (events.isEmpty) {
      content = Text('No tank cleanings due in the next 30 days.',
          style: GoogleFonts.spaceGrotesk(fontSize: 12, color: context.appTextMuted));
    } else {
      final grouped = <DateTime, List<({String label, DateTime date})>>{};
      for (final e in events) {
        final d = DateTime(e.date.year, e.date.month, e.date.day);
        grouped.putIfAbsent(d, () => []).add(e);
      }
      final dates = grouped.keys.toList()..sort();
      final now   = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(dates.length, (i) {
          final date      = dates[i];
          final evts      = grouped[date]!;
          final daysLeft  = date.difference(today).inDays;
          final color     = _color(daysLeft);
          final isLast    = i == dates.length - 1;
          final dateLabel =
              '${_weekday(date.weekday)} ${date.day} ${_month(date.month)}';

          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(children: [
                  Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  if (!isLast)
                    Expanded(child: Container(width: 2, color: context.appBorder)),
                ]),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text(dateLabel,
                              style: GoogleFonts.spaceGrotesk(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: color)),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(_badge(daysLeft),
                                style: GoogleFonts.spaceGrotesk(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: color)),
                          ),
                        ]),
                        const SizedBox(height: 4),
                        ...evts.map((e) => Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text('· ${e.label}',
                                  style: GoogleFonts.spaceGrotesk(
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
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appSurface2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.appBorder2)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.cleaning_services_outlined, size: 14, color: AppDS.accent),
          const SizedBox(width: 6),
          Expanded(child: Text('Cleaning Timeline',
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 13, fontWeight: FontWeight.w700,
                  color: context.appTextPrimary))),
        ]),
        const SizedBox(height: 10),
        Divider(height: 1, color: context.appBorder),
        const SizedBox(height: 8),
        content,
      ]),
    );
  }
}
