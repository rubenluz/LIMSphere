// breeding_activity_widget.dart – Dashboard widget showing the last breeding
// date per active stock, sorted most-recent first.

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io' show Platform;
import '/theme/theme.dart';

class BreedingActivityWidget extends StatefulWidget {
  const BreedingActivityWidget({super.key});

  @override
  State<BreedingActivityWidget> createState() => _BreedingActivityWidgetState();
}

class _BreedingActivityWidgetState extends State<BreedingActivityWidget> {
  List<_StockBreed> _stocks = [];
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
          .select('fish_stocks_line, fish_stocks_last_breeding, fish_stocks_tank_id')
          .eq('fish_stocks_status', 'active')
          .not('fish_stocks_last_breeding', 'is', null)
          .order('fish_stocks_last_breeding', ascending: false);

      final List<_StockBreed> stocks = [];
      for (final r in rows as List) {
        final raw = r['fish_stocks_last_breeding'];
        if (raw == null) continue;
        final date = DateTime.tryParse(raw.toString());
        if (date == null) continue;

        stocks.add(_StockBreed(
          tankId: r['fish_stocks_tank_id']?.toString() ?? '—',
          line: (r['fish_stocks_line'] as String?)?.trim() ?? '',
          lastBreed: date,
        ));
      }

      if (!mounted) return;
      setState(() {
        _stocks = stocks;
        _loading = false;
      });
    } catch (e) {
      debugPrint('BreedingActivityWidget error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _ago(DateTime d) {
    final days = DateTime.now().difference(d).inDays;
    if (days == 0) return 'today';
    if (days == 1) return '1 day ago';
    return '$days days ago';
  }

  // Recent = grey (routine), older = escalating colors.
  Color _recencyColor(DateTime d) {
    final days = DateTime.now().difference(d).inDays;
    if (days <= 7) return AppDS.textMuted;
    if (days <= 30) return AppDS.green;
    if (days <= 90) return AppDS.accent;
    return AppDS.yellow;
  }

  Widget _buildContent() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_stocks.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text('No breeding records',
              style: TextStyle(fontSize: 12, color: context.appTextSecondary)),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(10),
      itemCount: _stocks.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (_, i) {
        final s = _stocks[i];
        final color = _recencyColor(s.lastBreed);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: color.withAlpha(25),
            border: Border.all(color: color.withAlpha(100)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(children: [
            Icon(Icons.egg_outlined, size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.tankId,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: context.appTextPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if (s.line.isNotEmpty) ...[
                    const SizedBox(height: 1),
                    Text(s.line,
                        style: TextStyle(
                            fontSize: 10, color: context.appTextMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_fmtDate(s.lastBreed),
                    style: AppDS.mono(
                        size: 10, color: context.appTextSecondary)),
                const SizedBox(height: 1),
                Text(_ago(s.lastBreed),
                    style: TextStyle(
                        fontSize: 9, color: context.appTextMuted)),
              ],
            ),
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
        border: Border.all(color: AppDS.pink, width: 2),
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
              const Icon(Icons.egg_outlined, size: 20, color: AppDS.pink),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Breeding Activity',
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

class _StockBreed {
  final String tankId;
  final String line;
  final DateTime lastBreed;
  const _StockBreed({
    required this.tankId,
    required this.line,
    required this.lastBreed,
  });
}
