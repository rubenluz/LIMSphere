import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io' show Platform;

class NextTransferWidget extends StatefulWidget {
  const NextTransferWidget({super.key});

  @override
  State<NextTransferWidget> createState() => _NextTransferWidgetState();
}

class _NextTransferWidgetState extends State<NextTransferWidget> {
  List<Map<String, dynamic>> _nextTransfers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadNextTransfers();
  }

  bool _isDesktop(BuildContext context) {
    if (kIsWeb) return true;
    try {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) return true;
    } catch (_) {}
    return MediaQuery.of(context).size.width >= 600;
  }

  DateTime? _resolveNextTransfer(Map<String, dynamic> row) {
    final raw = row['next_transfer'];
    if (raw is DateTime) return raw;
    if (raw is String && raw.trim().isNotEmpty) {
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) return parsed;
    }

    final lastRaw = row['last_transfer'];
    final daysRaw = row['time_days'];

    DateTime? last;
    if (lastRaw is DateTime) {
      last = lastRaw;
    } else if (lastRaw is String && lastRaw.trim().isNotEmpty) {
      last = DateTime.tryParse(lastRaw);
    }

    int? days;
    if (daysRaw is int) {
      days = daysRaw;
    } else if (daysRaw is double) {
      days = daysRaw.toInt();
    } else if (daysRaw is String) {
      days = int.tryParse(daysRaw);
    } else if (daysRaw is num) {
      days = daysRaw.toInt();
    }

    if (last != null && days != null && days > 0) {
      return last.add(Duration(days: days));
    }

    return null;
  }

  Future<void> _loadNextTransfers() async {
    setState(() => _loading = true);

    try {
      final data = await Supabase.instance.client
          .from('strains')
          .select('time_days, next_transfer, last_transfer')
          .neq('status', 'DEAD');

      final Map<int, DateTime> byTimeDays = {};

      for (final row in data) {
        final daysRaw = row['time_days'];

        int? timeDays;
        if (daysRaw is int) {
          timeDays = daysRaw;
        } else if (daysRaw is double) timeDays = daysRaw.toInt();
        else if (daysRaw is String) timeDays = int.tryParse(daysRaw);
        else if (daysRaw is num)    timeDays = daysRaw.toInt();

        if (timeDays == null || timeDays <= 0) continue;

        final date = _resolveNextTransfer(row);
        if (date == null) continue;

        if (!byTimeDays.containsKey(timeDays) ||
            date.isBefore(byTimeDays[timeDays]!)) {
          byTimeDays[timeDays] = date;
        }
      }

      final sortedEntries = byTimeDays.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));

      if (!mounted) return;

      setState(() {
        _nextTransfers = sortedEntries
            .map((e) => {'time_days': e.key, 'next_transfer': e.value})
            .toList();
        _loading = false;
      });
    } catch (e, stack) {
      debugPrint('NextTransferWidget ERROR: $e');
      debugPrint(stack.toString());
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildList() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_nextTransfers.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text('No transfer data',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _nextTransfers.length,
      itemBuilder: (context, index) {
        final item     = _nextTransfers[index];
        final timeDays = item['time_days'] as int;
        final nextDate = item['next_transfer'] as DateTime;
        final now      = DateTime.now();
        final daysLeft = nextDate.difference(now).inDays;

        final dateStr =
            '${nextDate.year}-${nextDate.month.toString().padLeft(2, '0')}-${nextDate.day.toString().padLeft(2, '0')}';

        final Color color = daysLeft < 0
            ? Colors.red
            : daysLeft <= 7
                ? Colors.orange
                : Colors.green;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: color.withAlpha(30),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color.withAlpha(120)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$timeDays days',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  daysLeft < 0
                      ? '${daysLeft.abs()}d overdue'
                      : daysLeft == 0
                          ? 'today'
                          : 'in ${daysLeft}d',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                Text(
                  dateStr,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
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
        border: Border.all(color: Colors.orange, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      height: desktop ? 400 : null,
      child: Column(
        mainAxisSize: desktop ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                const Icon(Icons.schedule, size: 20, color: Colors.orange),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Next Transfers',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  onPressed: _loadNextTransfers,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (desktop)
            Expanded(child: SingleChildScrollView(child: _buildList()))
          else
            _buildList(),
        ],
      ),
    );
  }
}