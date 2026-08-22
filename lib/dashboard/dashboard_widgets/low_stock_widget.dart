// low_stock_widget.dart – Dashboard widget showing reagents whose current
// container count is at or below the reorder threshold (reagent_container_min).

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'dart:io' show Platform;

import '/theme/theme.dart';

class LowStockWidget extends StatefulWidget {
  const LowStockWidget({super.key});

  @override
  State<LowStockWidget> createState() => _LowStockWidgetState();
}

class _LowStockWidgetState extends State<LowStockWidget> {
  List<_LowItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool _isDesktop(BuildContext context) {
    if (kIsWeb) return true;
    try {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS)
        return true;
    } catch (_) {}
    return MediaQuery.of(context).size.width >= 600;
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      // Fetch reagents that have a container minimum threshold set.
      final rows = await Supabase.instance.client
          .from('reagents')
          .select(
            'reagent_name, reagent_container_count, reagent_container_min, reagent_package_size, reagent_unit',
          )
          .not('reagent_container_min', 'is', null)
          .order('reagent_name');

      final List<_LowItem> items = [];
      for (final r in rows as List) {
        final count = (r['reagent_container_count'] as num?)?.toInt() ?? 0;
        final min = (r['reagent_container_min'] as num?)?.toInt();
        if (min == null || min <= 0) continue;
        if (count > min) continue;
        items.add(
          _LowItem(
            name: r['reagent_name'] as String? ?? '—',
            count: count,
            min: min,
            packageSize: (r['reagent_package_size'] as num?)?.toDouble(),
            unit: r['reagent_unit'] as String? ?? '',
          ),
        );
      }

      // Sort: lowest ratio first (most critical on top).
      items.sort((a, b) => (a.count / a.min).compareTo(b.count / b.min));

      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      debugPrint('LowStockWidget error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _urgencyColor(int count, int min) {
    if (count <= 0) return AppDS.red;
    if (count <= min * 0.5) return AppDS.orange;
    return AppDS.yellow;
  }

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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 32,
                color: AppDS.green.withAlpha(180),
              ),
              const SizedBox(height: 8),
              Text(
                'All reagents above threshold',
                style: TextStyle(fontSize: 12, color: context.appTextSecondary),
              ),
            ],
          ),
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
        final it = _items[i];
        final color = _urgencyColor(it.count, it.min);
        final pct = (it.count / it.min).clamp(0.0, 1.0);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: color.withAlpha(30),
            border: Border.all(color: color.withAlpha(120)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                it.name,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.appTextPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 5,
                        backgroundColor: context.appBorder,
                        valueColor: AlwaysStoppedAnimation(color),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    it.packageSize != null
                        ? '${it.count} / ${it.min} × ${_fmt(it.packageSize!)} ${it.unit}'
                        : '${it.count} / ${it.min} containers',
                    style: AppDS.mono(size: 11, color: color),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final desktop = _isDesktop(context);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppDS.orange, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      height: desktop ? 360 : null,
      child: Column(
        mainAxisSize: desktop ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
            child: Row(
              children: [
                const Icon(
                  Icons.inventory_2_outlined,
                  size: 20,
                  color: AppDS.orange,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Low Stock Alerts',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: context.appTextPrimary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 24,
                  ),
                  onPressed: _load,
                  tooltip: 'Refresh',
                ),
              ],
            ),
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

class _LowItem {
  final String name;
  final int count;
  final int min;
  final double? packageSize;
  final String unit;
  const _LowItem({
    required this.name,
    required this.count,
    required this.min,
    required this.packageSize,
    required this.unit,
  });
}
