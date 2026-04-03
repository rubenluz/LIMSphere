import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../tanks_connection_model.dart';
import '/theme/theme.dart';


class TanksWidgetActiveFishLines extends StatelessWidget {
  final List<ZebrafishTank> rackTanks;
  const TanksWidgetActiveFishLines({super.key, required this.rackTanks});

  static bool _hasFish(ZebrafishTank t) =>
      ((t.zebraMales ?? 0) + (t.zebraFemales ?? 0) + (t.zebraJuveniles ?? 0)) > 0;

  @override
  Widget build(BuildContext context) {
    final byLine = <String, (int, int, int, int)>{};
    for (final t in rackTanks.where(_hasFish)) {
      final name = t.zebraLine?.trim().isNotEmpty == true ? t.zebraLine! : 'Unknown';
      final m = t.zebraMales     ?? 0;
      final f = t.zebraFemales   ?? 0;
      final j = t.zebraJuveniles ?? 0;
      final p = byLine[name] ?? (0, 0, 0, 0);
      byLine[name] = (p.$1 + m, p.$2 + f, p.$3 + j, p.$4 + m + f + j);
    }
    final sorted = byLine.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

    if (sorted.isEmpty) {
      return _infoCard(context, 'Active Fish Lines', Icons.biotech_outlined, [
        Text('No active fish lines in this rack.',
            style: GoogleFonts.spaceGrotesk(fontSize: 12, color: context.appTextMuted)),
      ]);
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
          fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );

    Widget cell(int v, double w, Color color, {bool bold = false}) => SizedBox(
      width: w,
      child: Text(v > 0 ? '$v' : '—',
        textAlign: TextAlign.center,
        style: GoogleFonts.jetBrainsMono(
          fontSize: 11,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          color: v > 0 ? color : context.appTextMuted)),
    );

    final header = Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(children: [
        const Expanded(child: SizedBox()),
        colHdr('♂',     AppDS.accent),
        colHdr('♀',     AppDS.pink),
        colHdr('Juv',   context.appTextMuted),
        colHdr('Total', context.appTextSecondary),
      ]),
    );

    final dataRows = sorted.map((e) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Expanded(child: Text(e.key,
          style: GoogleFonts.spaceGrotesk(fontSize: 12, color: context.appTextPrimary),
          overflow: TextOverflow.ellipsis)),
        cell(e.value.$1, colM, AppDS.accent),
        cell(e.value.$2, colF, AppDS.pink),
        cell(e.value.$3, colJ, context.appTextMuted),
        cell(e.value.$4, colT, context.appTextPrimary, bold: true),
      ]),
    )).toList();

    final totalM = sorted.fold(0, (s, e) => s + e.value.$1);
    final totalF = sorted.fold(0, (s, e) => s + e.value.$2);
    final totalJ = sorted.fold(0, (s, e) => s + e.value.$3);
    final totalT = sorted.fold(0, (s, e) => s + e.value.$4);

    final totalRow = Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(children: [
        Expanded(child: Text('Total',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 12, fontWeight: FontWeight.w700,
            color: context.appTextSecondary),
          overflow: TextOverflow.ellipsis)),
        cell(totalM, colM, AppDS.accent,           bold: true),
        cell(totalF, colF, AppDS.pink,             bold: true),
        cell(totalJ, colJ, context.appTextMuted,   bold: true),
        cell(totalT, colT, context.appTextPrimary, bold: true),
      ]),
    );

    return _infoCard(context, 'Active Fish Lines', Icons.biotech_outlined, [
      header, ...dataRows,
      const Divider(height: 10, thickness: 1),
      totalRow,
    ]);
  }
}

Widget _infoCard(BuildContext context, String title, IconData icon, List<Widget> rows) =>
    Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appSurface2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.appBorder2)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 14, color: AppDS.accent),
          const SizedBox(width: 6),
          Text(title, style: GoogleFonts.spaceGrotesk(
            fontSize: 13, fontWeight: FontWeight.w700, color: context.appTextPrimary)),
        ]),
        const SizedBox(height: 10),
        Divider(height: 1, color: context.appBorder),
        const SizedBox(height: 8),
        ...rows,
      ]),
    );
