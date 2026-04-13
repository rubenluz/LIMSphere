// reagents_by_type_widget.dart – Dashboard donut chart showing reagent
// distribution by type (chemicals, biologicals, consumables, etc.).

import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io' show Platform;
import '/theme/theme.dart';

class ReagentsByTypeWidget extends StatefulWidget {
  const ReagentsByTypeWidget({super.key});

  @override
  State<ReagentsByTypeWidget> createState() => _ReagentsByTypeWidgetState();
}

class _ReagentsByTypeWidgetState extends State<ReagentsByTypeWidget> {
  Map<String, int> _counts = {};
  bool _loading = true;

  static const _palette = [
    AppDS.accent,   // sky
    AppDS.green,
    AppDS.purple,
    AppDS.orange,
    AppDS.pink,
    AppDS.yellow,
    AppDS.red,
    Color(0xFF06B6D4), // cyan
    Color(0xFF8B5CF6), // violet
  ];

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
          .from('reagents')
          .select('reagent_type');

      final Map<String, int> counts = {};
      for (final r in rows as List) {
        final t = (r['reagent_type'] as String?)?.trim() ?? '';
        if (t.isEmpty) continue;
        counts[t] = (counts[t] ?? 0) + 1;
      }

      final sorted = Map.fromEntries(
          counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));

      if (!mounted) return;
      setState(() {
        _counts = sorted;
        _loading = false;
      });
    } catch (e) {
      debugPrint('ReagentsByTypeWidget error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

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
    if (_counts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text('No reagent data',
              style: TextStyle(fontSize: 12, color: context.appTextSecondary)),
        ),
      );
    }

    final total = _counts.values.fold(0, (a, b) => a + b);
    final entries = _counts.entries.toList();

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          height: 140,
          child: Center(
            child: CustomPaint(
              size: const Size(130, 130),
              painter: _DonutPainter(entries, _palette, total),
              child: SizedBox(
                width: 130,
                height: 130,
                child: Center(
                  child: Text('$total',
                      style: AppDS.mono(
                          size: 18,
                          color: context.appTextPrimary,
                          weight: FontWeight.bold)),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: List.generate(entries.length, (i) {
            final e = entries[i];
            final color = _palette[i % _palette.length];
            final pct = (e.value / total * 100).toStringAsFixed(0);
            return Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 10, height: 10,
                  decoration: BoxDecoration(
                      color: color, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 4),
              Text('${_pretty(e.key)} ($pct%)',
                  style: TextStyle(
                      fontSize: 11, color: context.appTextSecondary)),
            ]);
          }),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final desktop = _isDesktop(context);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppDS.purple, width: 2),
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
              const Icon(Icons.donut_small_outlined,
                  size: 20, color: AppDS.purple),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Reagents by Type',
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

class _DonutPainter extends CustomPainter {
  final List<MapEntry<String, int>> entries;
  final List<Color> palette;
  final int total;

  _DonutPainter(this.entries, this.palette, this.total);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 22.0;
    final rect = Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);

    double startAngle = -math.pi / 2;
    for (int i = 0; i < entries.length; i++) {
      final sweep = (entries[i].value / total) * 2 * math.pi;
      final paint = Paint()
        ..color = palette[i % palette.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, startAngle, sweep, false, paint);
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.total != total || old.entries.length != entries.length;
}
