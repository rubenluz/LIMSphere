// today_reservations_widget.dart – Dashboard widget listing today's equipment
// reservations: who booked what and when.

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io' show Platform;
import '/theme/theme.dart';

class TodayReservationsWidget extends StatefulWidget {
  const TodayReservationsWidget({super.key});

  @override
  State<TodayReservationsWidget> createState() =>
      _TodayReservationsWidgetState();
}

class _TodayReservationsWidgetState extends State<TodayReservationsWidget> {
  List<_Res> _items = [];
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
      final now = DateTime.now();
      final todayStart =
          DateTime(now.year, now.month, now.day).toIso8601String();
      final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59)
          .toIso8601String();

      final rows = await Supabase.instance.client
          .from('reservations')
          .select(
              'reservation_resource_name, reservation_start, reservation_end, '
              'reservation_status, reservation_purpose, '
              'user:reservation_user_id(user_name)')
          .lte('reservation_start', todayEnd)
          .gte('reservation_end', todayStart)
          .order('reservation_start');

      final List<_Res> items = [];
      for (final r in rows as List) {
        final start = DateTime.tryParse(r['reservation_start'] as String? ?? '');
        final end = DateTime.tryParse(r['reservation_end'] as String? ?? '');
        if (start == null || end == null) continue;

        final userMap = r['user'] as Map<String, dynamic>?;
        items.add(_Res(
          resource: r['reservation_resource_name'] as String? ?? '—',
          userName: userMap?['user_name'] as String? ?? '—',
          start: start,
          end: end,
          status: r['reservation_status'] as String? ?? '',
          purpose: r['reservation_purpose'] as String? ?? '',
        ));
      }

      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      debugPrint('TodayReservationsWidget error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmtTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  Color _statusColor(String s) => switch (s) {
    'in_use'    => AppDS.green,
    'confirmed' => AppDS.accent,
    'pending'   => AppDS.yellow,
    'completed' => AppDS.textMuted,
    'cancelled' || 'no_show' => AppDS.red,
    _ => AppDS.textSecondary,
  };

  Widget _buildContent() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.event_available,
                size: 32, color: AppDS.textMuted.withAlpha(150)),
            const SizedBox(height: 8),
            Text('No reservations today',
                style: TextStyle(
                    fontSize: 12, color: context.appTextSecondary)),
          ]),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(10),
      itemCount: _items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (_, i) {
        final r = _items[i];
        final color = _statusColor(r.status);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: color.withAlpha(25),
            border: Border.all(color: color.withAlpha(100)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(children: [
            Container(
              width: 4,
              height: 36,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.resource,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: context.appTextPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    '${r.userName}${r.purpose.isNotEmpty ? '  ·  ${r.purpose}' : ''}',
                    style: TextStyle(
                        fontSize: 10, color: context.appTextMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text('${_fmtTime(r.start)} – ${_fmtTime(r.end)}',
                style: AppDS.mono(size: 10, color: context.appTextSecondary)),
          ]),
        );
      },
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
              const Icon(Icons.calendar_today_outlined,
                  size: 20, color: AppDS.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text("Today's Reservations",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
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
            Expanded(child: SingleChildScrollView(child: _buildContent()))
          else
            _buildContent(),
        ],
      ),
    );
  }
}

class _Res {
  final String resource;
  final String userName;
  final DateTime start;
  final DateTime end;
  final String status;
  final String purpose;
  const _Res({
    required this.resource,
    required this.userName,
    required this.start,
    required this.end,
    required this.status,
    required this.purpose,
  });
}
