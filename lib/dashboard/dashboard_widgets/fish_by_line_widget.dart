// fish_by_line_widget.dart - Dashboard widget aggregating total fish counts
// (males + females + juveniles) grouped by genetic line.

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io' show Platform;
import '/theme/theme.dart';

/// Fish by Line Widget — shows male/female/juvenile/total counts per fish line
/// across all active stocks, matching the tanks_page "Fish by Line" info card.
class FishByLineWidget extends StatefulWidget {
  const FishByLineWidget({super.key});

  @override
  State<FishByLineWidget> createState() => _FishByLineWidgetState();
}

class _FishByLineWidgetState extends State<FishByLineWidget> {
  // line name → (males, females, juveniles, total)
  List<MapEntry<String, (int, int, int, int)>> _rows = [];
  int _totalFish = 0;
  bool _loading = true;

  static const _accent  = Color(0xFF0EA5E9); // sky-blue, matches fish facility

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
      final data = await Supabase.instance.client
          .from('fish_stocks')
          .select(
            'fish_stocks_males, fish_stocks_females, fish_stocks_juveniles, '
            'fish_stocks_line, fish_lines!fish_stocks_line_id(fish_line_name)',
          )
          .eq('fish_stocks_status', 'active');

      final byLine = <String, (int, int, int, int)>{};
      for (final row in data as List) {
        final lineData = row['fish_lines'] as Map<String, dynamic>?;
        final name = (lineData?['fish_line_name']?.toString().trim().isNotEmpty == true
                ? lineData!['fish_line_name'].toString().trim()
                : row['fish_stocks_line']?.toString().trim())
            ?.isNotEmpty == true
            ? (lineData?['fish_line_name']?.toString().trim() ??
                row['fish_stocks_line']!.toString().trim())
            : 'Unknown';

        final m = (row['fish_stocks_males']   as num?)?.toInt() ?? 0;
        final f = (row['fish_stocks_females']  as num?)?.toInt() ?? 0;
        final j = (row['fish_stocks_juveniles'] as num?)?.toInt() ?? 0;
        final p = byLine[name] ?? (0, 0, 0, 0);
        byLine[name] = (p.$1 + m, p.$2 + f, p.$3 + j, p.$4 + m + f + j);
      }

      final sorted = byLine.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));

      if (!mounted) return;
      setState(() {
        _rows      = sorted;
        _totalFish = sorted.fold(0, (s, e) => s + e.value.$4);
        _loading   = false;
      });
    } catch (e) {
      debugPrint('FishByLineWidget error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildContent(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text('No active fish stocks.',
            style: GoogleFonts.spaceGrotesk(
                fontSize: 12, color: AppDS.textMuted)),
      );
    }

    const colM = 36.0;
    const colF = 36.0;
    const colJ = 36.0;
    const colT = 44.0;

    Widget colHdr(String label, Color color) => SizedBox(
          width: label == 'Total' ? colT : colM,
          child: Text(label,
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: color)),
        );

    Widget countCell(int v, double w, Color color, {bool bold = false}) =>
        SizedBox(
          width: w,
          child: Text(
            v > 0 ? '$v' : '—',
            textAlign: TextAlign.center,
            style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                color: v > 0 ? color : AppDS.textMuted),
          ),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Column headers
          Row(children: [
            const Expanded(child: SizedBox()),
            colHdr('♂',     AppDS.accent),
            colHdr('♀',     AppDS.pink),
            colHdr('Juv',   AppDS.textMuted),
            colHdr('Total', AppDS.textSecondary),
          ]),
          const SizedBox(height: 4),
          const Divider(height: 1, color: AppDS.border),
          const SizedBox(height: 4),

          // Data rows
          ..._rows.map((e) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Expanded(
                child: Text(e.key,
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 12, color: context.appTextPrimary),
                    overflow: TextOverflow.ellipsis),
              ),
              countCell(e.value.$1, colM, AppDS.accent),
              countCell(e.value.$2, colF, AppDS.pink),
              countCell(e.value.$3, colJ, AppDS.textMuted),
              countCell(e.value.$4, colT, context.appTextPrimary, bold: true),
            ]),
          )),

          // Total footer
          if (_rows.length > 1) ...[
            const SizedBox(height: 4),
            const Divider(height: 1, color: AppDS.border),
            const SizedBox(height: 4),
            Row(children: [
              Expanded(
                child: Text('Total',
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: context.appTextPrimary)),
              ),
              countCell(
                  _rows.fold(0, (s, e) => s + e.value.$1), colM, AppDS.accent,
                  bold: true),
              countCell(
                  _rows.fold(0, (s, e) => s + e.value.$2), colF, AppDS.pink,
                  bold: true),
              countCell(
                  _rows.fold(0, (s, e) => s + e.value.$3), colJ, AppDS.textMuted,
                  bold: true),
              countCell(_totalFish, colT, context.appTextPrimary, bold: true),
            ]),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final desktop = _isDesktop(context);
    final lineCount = _rows.length;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: _accent, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      height: desktop ? 320 : null,
      child: Column(
        mainAxisSize: desktop ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
            child: Row(children: [
              const Icon(Icons.biotech_outlined, size: 20, color: _accent),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Fish by Line',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              if (!_loading && lineCount > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _accent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('$_totalFish',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ),
              const SizedBox(width: 4),
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
          const Divider(height: 1),
          if (desktop)
            Expanded(child: SingleChildScrollView(child: _buildContent(context)))
          else
            _buildContent(context),
        ],
      ),
    );
  }
}
