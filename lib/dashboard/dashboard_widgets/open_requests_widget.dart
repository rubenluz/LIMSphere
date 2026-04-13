// open_requests_widget.dart – Dashboard widget showing pending requests
// grouped by type and color-coded by priority.

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io' show Platform;
import '/theme/theme.dart';

class OpenRequestsWidget extends StatefulWidget {
  const OpenRequestsWidget({super.key});

  @override
  State<OpenRequestsWidget> createState() => _OpenRequestsWidgetState();
}

class _OpenRequestsWidgetState extends State<OpenRequestsWidget> {
  List<_ReqGroup> _groups = [];
  int _total = 0;
  bool _loading = true;

  static const _priorityOrder = ['urgent', 'high', 'normal', 'low'];

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
          .from('requests')
          .select('request_type, request_priority, request_title')
          .eq('request_status', 'pending')
          .order('request_created_at', ascending: false);

      // Group by type.
      final Map<String, List<_Req>> byType = {};
      for (final r in rows as List) {
        final type = r['request_type'] as String? ?? 'other';
        final priority = r['request_priority'] as String? ?? 'normal';
        final title = r['request_title'] as String? ?? '';
        byType.putIfAbsent(type, () => []).add(
            _Req(title: title, priority: priority));
      }

      // Sort items within each group: urgent first.
      final groups = byType.entries.map((e) {
        e.value.sort((a, b) {
          final ai = _priorityOrder.indexOf(a.priority);
          final bi = _priorityOrder.indexOf(b.priority);
          return (ai == -1 ? 99 : ai).compareTo(bi == -1 ? 99 : bi);
        });
        return _ReqGroup(type: e.key, items: e.value);
      }).toList();

      // Sort groups: those with highest-priority items first, then by count.
      groups.sort((a, b) {
        final ap = _priorityOrder.indexOf(a.items.first.priority);
        final bp = _priorityOrder.indexOf(b.items.first.priority);
        final cmp = (ap == -1 ? 99 : ap).compareTo(bp == -1 ? 99 : bp);
        if (cmp != 0) return cmp;
        return b.items.length.compareTo(a.items.length);
      });

      if (!mounted) return;
      setState(() {
        _groups = groups;
        _total = rows.length;
        _loading = false;
      });
    } catch (e) {
      debugPrint('OpenRequestsWidget error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  static Color _prioColor(String p) => switch (p) {
    'urgent' => AppDS.red,
    'high'   => AppDS.orange,
    'normal' => AppDS.accent,
    _        => AppDS.textMuted,
  };

  static IconData _prioIcon(String p) => switch (p) {
    'urgent' => Icons.error,
    'high'   => Icons.priority_high,
    'normal' => Icons.circle_outlined,
    _        => Icons.arrow_downward,
  };

  String _pretty(String raw) =>
      raw.replaceAll('_', ' ').replaceFirstMapped(
          RegExp(r'^[a-z]'), (m) => m[0]!.toUpperCase());

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
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.check_circle_outline,
                size: 32, color: AppDS.green.withAlpha(180)),
            const SizedBox(height: 8),
            Text('No pending requests',
                style: TextStyle(
                    fontSize: 12, color: context.appTextSecondary)),
          ]),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(10),
      itemCount: _groups.length,
      itemBuilder: (_, i) {
        final g = _groups[i];
        // Highest priority in the group determines the card tint.
        final topColor = _prioColor(g.items.first.priority);
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: topColor.withAlpha(25),
              border: Border.all(color: topColor.withAlpha(100)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(_pretty(g.type),
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: context.appTextPrimary)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: topColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('${g.items.length}',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                  ),
                ]),
                const SizedBox(height: 6),
                for (final req in g.items.take(5))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Row(children: [
                      Icon(_prioIcon(req.priority),
                          size: 12, color: _prioColor(req.priority)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          req.title.isNotEmpty ? req.title : '(no title)',
                          style: TextStyle(
                              fontSize: 11,
                              color: context.appTextSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ]),
                  ),
                if (g.items.length > 5)
                  Text('  +${g.items.length - 5} more',
                      style: TextStyle(
                          fontSize: 10, color: context.appTextMuted)),
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
        border: Border.all(color: AppDS.yellow, width: 2),
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
              const Icon(Icons.assignment_outlined,
                  size: 20, color: AppDS.yellow),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(TextSpan(children: [
                  TextSpan(
                    text: 'Open Requests',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: context.appTextPrimary),
                  ),
                  if (_total > 0)
                    TextSpan(
                      text: '  $_total',
                      style: TextStyle(
                          fontSize: 12, color: context.appTextMuted),
                    ),
                ])),
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

class _Req {
  final String title;
  final String priority;
  const _Req({required this.title, required this.priority});
}

class _ReqGroup {
  final String type;
  final List<_Req> items;
  const _ReqGroup({required this.type, required this.items});
}
