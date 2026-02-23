import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io' show Platform;
import '../strains/strain_detail_page.dart'; // adjust import path as needed

class InCareWidget extends StatefulWidget {
  const InCareWidget({super.key});

  @override
  State<InCareWidget> createState() => _InCareWidgetState();
}

class _InCareWidgetState extends State<InCareWidget> {
  List<Map<String, dynamic>> _strains = [];
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
          .from('strains')
          .select('id, code, scientific_name, medium, next_transfer, last_transfer, time_days')
          .eq('status', 'INCARE')
          .order('code', ascending: true);

      if (!mounted) return;
      setState(() {
        _strains = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e, stack) {
      debugPrint('InCareWidget ERROR: $e');
      debugPrint(stack.toString());
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Returns true when running on a desktop-class platform or wide screen.
  bool _isDesktop(BuildContext context) {
    if (kIsWeb) return true;
    try {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) return true;
    } catch (_) {}
    // Fallback: treat wide screens as desktop even if platform check fails.
    return MediaQuery.of(context).size.width >= 600;
  }

  /// Same fallback logic as the other widgets
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
    } else if (lastRaw is String && lastRaw.isNotEmpty) last = DateTime.tryParse(lastRaw);
    int? days;
    if (daysRaw is int) {
      days = daysRaw;
    } else if (daysRaw is double) days = daysRaw.toInt();
    else if (daysRaw is String) days = int.tryParse(daysRaw);
    else if (daysRaw is num)    days = daysRaw.toInt();
    if (last != null && days != null && days > 0) return last.add(Duration(days: days));
    return null;
  }

  void _openDetail(dynamic strainId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StrainDetailPage(strainId: strainId, onSaved: _load),
      ),
    ).then((_) => _load());
  }

  // ── List body (shared between both layout modes) ──────────────────────────
  Widget _buildList() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_strains.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text('No strains in care',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
      );
    }
    return ListView.separated(
      // On desktop the parent SizedBox constrains the height, so we let the
      // ListView scroll freely. On mobile shrinkWrap + NeverScrollable is kept.
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: _strains.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, indent: 12, endIndent: 12),
      itemBuilder: (context, i) {
        final strain  = _strains[i];
        final code    = strain['code']?.toString() ?? '—';
        final name    = strain['scientific_name']?.toString() ?? '';
        final medium  = strain['medium']?.toString() ?? '';
        final next    = _resolveNextTransfer(strain);
        final now     = DateTime.now();

        Color? dateColor;
        String? dateLabel;
        if (next != null) {
          final days = next.difference(now).inDays;
          if (days < 0) {
            dateColor = Colors.red;
            dateLabel = '${days.abs()}d overdue';
          } else if (days <= 7) {
            dateColor = Colors.orange;
            dateLabel = days == 0 ? 'today' : 'in ${days}d';
          } else {
            dateColor = Colors.green;
            dateLabel = 'in ${days}d';
          }
        }

        return ListTile(
          dense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          leading: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.withAlpha(40),
              border: Border.all(color: Colors.orange.withAlpha(160)),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              code,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
          ),
          title: Text(
            name.isNotEmpty ? name : code,
            style: TextStyle(
              fontSize: 12,
              fontStyle: name.isNotEmpty ? FontStyle.italic : FontStyle.normal,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: medium.isNotEmpty
              ? Text(medium,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                  overflow: TextOverflow.ellipsis)
              : null,
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            if (dateLabel != null) ...[
              Text(
                dateLabel,
                style: TextStyle(
                    fontSize: 10,
                    color: dateColor,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 4),
            ],
            IconButton(
              icon: const Icon(Icons.open_in_new, size: 15),
              tooltip: 'Open strain',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              onPressed: () => _openDetail(strain['id']),
            ),
          ]),
          onTap: () => _openDetail(strain['id']),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final desktop = _isDesktop(context);

    // ── Shared chrome (border + header + divider) ─────────────────────────
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.orange, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      // On desktop we give the whole widget a fixed height so the list scrolls
      // internally. On mobile we let it shrink-wrap as before.
      height: desktop ? 400 : null,
      child: Column(
        mainAxisSize: desktop ? MainAxisSize.max : MainAxisSize.min,
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
            child: Row(children: [
              const Icon(Icons.medical_services, size: 18, color: Colors.orange),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('In Care',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              if (!_loading)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_strains.length}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.refresh, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                onPressed: _load,
                tooltip: 'Refresh',
              ),
            ]),
          ),
          const Divider(height: 1),

          // ── List ──────────────────────────────────────────────────────────
          // On desktop: Expanded + SingleChildScrollView so the list scrolls
          // within the fixed-height container.
          // On mobile:  plain _buildList() which shrink-wraps as before.
          if (desktop)
            Expanded(
              child: SingleChildScrollView(
                child: _buildList(),
              ),
            )
          else
            _buildList(),
        ],
      ),
    );
  }
}