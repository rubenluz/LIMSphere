// transfer_status_widget.dart - Dashboard widget displaying transfer task
// status breakdown: pending, completed, overdue counts.

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io' show Platform;

/// Transfer Status Widget — Shows transfer urgency summary.
class TransferStatusWidget extends StatefulWidget {
  const TransferStatusWidget({super.key});

  @override
  State<TransferStatusWidget> createState() => _TransferStatusWidgetState();
}

class _TransferStatusWidgetState extends State<TransferStatusWidget> {
  int _overdue = 0;
  int _soon    = 0;
  int _ok      = 0;
  int _unknown = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTransferStatus();
  }

  bool _isDesktop(BuildContext context) {
    if (kIsWeb) return true;
    try {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) return true;
    } catch (_) {}
    return MediaQuery.of(context).size.width >= 600;
  }

  DateTime? _resolveNextTransfer(Map<String, dynamic> row) {
    final raw = row['strain_next_transfer'];
    if (raw != null) {
      if (raw is DateTime) return raw;
      if (raw is String && raw.trim().isNotEmpty) {
        final parsed = DateTime.tryParse(raw);
        if (parsed != null) return parsed;
      }
    }

    final lastRaw = row['strain_last_transfer'];
    final daysRaw = row['strain_periodicity'];

    DateTime? last;
    if (lastRaw is DateTime) {
      last = lastRaw;
    } else if (lastRaw is String && lastRaw.trim().isNotEmpty) {
      last = DateTime.tryParse(lastRaw);
    }

    int? days;
    if (daysRaw is int) {
      days = daysRaw;
    } else if (daysRaw is String) {
      days = int.tryParse(daysRaw);
    } else if (daysRaw is num) {
      days = daysRaw.toInt();
    }

    if (last != null && days != null) {
      return last.add(Duration(days: days));
    }

    return null;
  }

  Future<void> _loadTransferStatus() async {
    setState(() => _loading = true);

    try {
      final data = await Supabase.instance.client
          .from('strains')
          .select('strain_next_transfer, strain_last_transfer, strain_periodicity')
          .neq('strain_status', 'DEAD');

      int overdue = 0, soon = 0, ok = 0, unknown = 0;
      final nowUtc = DateTime.now().toUtc();

      for (final row in data) {
        final date = _resolveNextTransfer(row);

        if (date == null) {
          unknown++;
          continue;
        }

        final daysLeft = date.toUtc().difference(nowUtc).inDays;

        if (daysLeft < 0) {
          overdue++;
        } else if (daysLeft <= 7) {
          soon++;
        } else {
          ok++;
        }
      }

      if (!mounted) return;
      setState(() {
        _overdue = overdue;
        _soon    = soon;
        _ok      = ok;
        _unknown = unknown;
        _loading = false;
      });
    } catch (e, stack) {
      debugPrint('TransferStatusWidget ERROR: $e');
      debugPrint(stack.toString());
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildStatusCard(String label, int count, Color color, IconData icon) {
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
        Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            count.toString(),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 13,
            ),
          ),
        ),
      ]),
    );
  }

  // TransferStatus has a fixed small number of rows (4 cards) so it never
  // really needs to scroll — but we still apply the same height/column pattern
  // for visual consistency with the other dashboard widgets.
  Widget _buildContent() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildStatusCard('OVERDUE',    _overdue, Colors.red,    Icons.error),
          const SizedBox(height: 6),
          _buildStatusCard('SOON (≤7d)', _soon,    Colors.orange, Icons.schedule),
          const SizedBox(height: 6),
          _buildStatusCard('OK',         _ok,      Colors.green,  Icons.check_circle),
          const SizedBox(height: 6),
          _buildStatusCard('Unknown',    _unknown, Colors.grey,   Icons.help_outline),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final desktop = _isDesktop(context);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.red, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      // TransferStatus has only 4 fixed cards so a smaller height is fine on desktop.
      height: desktop ? 260 : null,
      child: Column(
        mainAxisSize: desktop ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
            child: Row(
              children: [
                const Icon(Icons.warning_amber, size: 20, color: Colors.red),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Transfer Status',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  onPressed: _loadTransferStatus,
                  tooltip: 'Refresh',
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (desktop)
            Expanded(child: SingleChildScrollView(child: _buildContent()))
          else
            _buildContent(),
        ],
      ),
    );
  }
}