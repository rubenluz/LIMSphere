// transfer_timeline_widget.dart - Timeline visualization of strain transfer
// events over the past and upcoming weeks; date-grouped rows.

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io' show Platform;
import '/theme/theme.dart';

class TransferTimelineWidget extends StatefulWidget {
  const TransferTimelineWidget({super.key});

  @override
  State<TransferTimelineWidget> createState() => _TransferTimelineWidgetState();
}

class _TransferTimelineWidgetState extends State<TransferTimelineWidget> {
  // One entry per periodicity: {periodicity in days → earliest next date}
  List<_PeriodGroup> _groups = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool _isDesktop(BuildContext context) {
    if (kIsWeb) { return true; }
    try {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) { return true; }
    } catch (_) {}
    return MediaQuery.of(context).size.width >= 600;
  }

  DateTime? _resolveDate(Map<String, dynamic> row) {
    final raw = row['strain_next_transfer'];
    if (raw is DateTime) { return raw; }
    if (raw is String && raw.trim().isNotEmpty) {
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) { return parsed; }
    }
    final lastRaw = row['strain_last_transfer'];
    final daysRaw = row['strain_periodicity'];
    DateTime? last;
    if (lastRaw is DateTime) { last = lastRaw; }
    else if (lastRaw is String) { last = DateTime.tryParse(lastRaw); }
    int? days;
    if (daysRaw is int) { days = daysRaw; }
    else if (daysRaw is double) { days = daysRaw.toInt(); }
    else if (daysRaw is String) { days = int.tryParse(daysRaw); }
    else if (daysRaw is num) { days = daysRaw.toInt(); }
    if (last != null && days != null && days > 0) {
      return last.add(Duration(days: days));
    }
    return null;
  }

  int? _resolvePeriodicity(Map<String, dynamic> row) {
    final v = row['strain_periodicity'];
    if (v is int) { return v; }
    if (v is double) { return v.toInt(); }
    if (v is num) { return v.toInt(); }
    if (v is String) { return int.tryParse(v); }
    return null;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await Supabase.instance.client
          .from('strains')
          .select('strain_periodicity, strain_next_transfer, strain_last_transfer')
          .neq('strain_status', 'DEAD');

      // For each periodicity, keep the earliest next-transfer date
      final Map<int, DateTime> earliest = {};
      for (final row in rows as List) {
        final period = _resolvePeriodicity(row);
        if (period == null || period <= 0) { continue; }
        final date = _resolveDate(row);
        if (date == null) { continue; }
        if (!earliest.containsKey(period) || date.isBefore(earliest[period]!)) {
          earliest[period] = date;
        }
      }

      final groups = earliest.entries
          .map((e) => _PeriodGroup(periodDays: e.key, nextDate: e.value))
          .toList()
        ..sort((a, b) => a.nextDate.compareTo(b.nextDate));

      if (mounted) { setState(() { _groups = groups; _loading = false; }); }
    } catch (e) {
      debugPrint('TransferTimelineWidget error: $e');
      if (mounted) { setState(() => _loading = false); }
    }
  }

  Color _color(int daysLeft) {
    if (daysLeft < 0) { return Colors.red; }
    if (daysLeft == 0) { return Colors.orange; }
    if (daysLeft <= 3) { return Colors.amber; }
    return AppDS.accent;
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
    if (_groups.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text('No transfer data available.',
            style: TextStyle(color: context.appTextSecondary, fontSize: 13)),
      );
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(_groups.length, (i) {
          final g = _groups[i];
          final date = DateTime(g.nextDate.year, g.nextDate.month, g.nextDate.day);
          final daysLeft = date.difference(today).inDays;
          final color = _color(daysLeft);
          final isLast = i == _groups.length - 1;
          final dateLabel =
              '${_weekday(date.weekday)} ${date.day} ${_month(date.month)}';

          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Timeline spine
                Column(children: [
                  Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  if (!isLast)
                    Expanded(child: Container(width: 2, color: context.appBorder)),
                ]),
                const SizedBox(width: 10),
                // Content
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Periodicity label
                        SizedBox(
                          width: 52,
                          child: Text('${g.periodDays}d',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: color)),
                        ),
                        // Date
                        Expanded(
                          child: Text(dateLabel,
                              style: TextStyle(
                                  fontSize: 12, color: context.appTextPrimary)),
                        ),
                        // Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
              const Icon(Icons.timeline_rounded, size: 20, color: AppDS.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Transfer Timeline',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14,
                        color: context.appTextPrimary)),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                onPressed: _load,
                tooltip: 'Refresh',
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

class _PeriodGroup {
  final int periodDays;
  final DateTime nextDate;
  const _PeriodGroup({required this.periodDays, required this.nextDate});
}
