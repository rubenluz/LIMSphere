import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../tanks_connection_model.dart';
import '/theme/theme.dart';

class TanksWidgetActiveStocks extends StatelessWidget {
  final List<ZebrafishTank> rackTanks;
  const TanksWidgetActiveStocks({super.key, required this.rackTanks});

  static bool _hasFish(ZebrafishTank t) =>
      ((t.zebraMales ?? 0) + (t.zebraFemales ?? 0) + (t.zebraJuveniles ?? 0)) > 0;

  static int _compareTankId(String a, String b) {
    final re = RegExp(r'^([^-]+)-([A-Za-z]+)(\d+)$');
    final ma = re.firstMatch(a);
    final mb = re.firstMatch(b);
    if (ma == null || mb == null) return _naturalStr(a, b);
    final rack = _naturalStr(ma.group(1)!, mb.group(1)!);
    if (rack != 0) return rack;
    final row = ma.group(2)!.compareTo(mb.group(2)!);
    if (row != 0) return row;
    return int.parse(ma.group(3)!).compareTo(int.parse(mb.group(3)!));
  }

  static int _naturalStr(String a, String b) {
    final re = RegExp(r'(\d+)|(\D+)');
    final ta = re.allMatches(a).toList();
    final tb = re.allMatches(b).toList();
    for (var i = 0; i < ta.length && i < tb.length; i++) {
      final sa = ta[i].group(0)!;
      final sb = tb[i].group(0)!;
      final na = int.tryParse(sa);
      final nb = int.tryParse(sb);
      final c = (na != null && nb != null) ? na.compareTo(nb) : sa.compareTo(sb);
      if (c != 0) return c;
    }
    return a.length.compareTo(b.length);
  }

  @override
  Widget build(BuildContext context) {
    final stockTanks = rackTanks.where(_hasFish).toList()
      ..sort((a, b) => _compareTankId(a.zebraTankId, b.zebraTankId));

    final header = Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        SizedBox(width: 56, child: Text('Tank', style: GoogleFonts.spaceGrotesk(
          fontSize: 10, fontWeight: FontWeight.w700, color: context.appTextMuted))),
        Expanded(child: Text('Line', style: GoogleFonts.spaceGrotesk(
          fontSize: 10, fontWeight: FontWeight.w700, color: context.appTextMuted))),
        SizedBox(width: 28, child: Text('♂', textAlign: TextAlign.center,
          style: GoogleFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.w700, color: context.appTextMuted))),
        SizedBox(width: 28, child: Text('♀', textAlign: TextAlign.center,
          style: GoogleFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.w700, color: context.appTextMuted))),
        SizedBox(width: 32, child: Text('Juv', textAlign: TextAlign.center,
          style: GoogleFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.w700, color: context.appTextMuted))),
        SizedBox(width: 36, child: Text('Total', textAlign: TextAlign.right,
          style: GoogleFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.w700, color: context.appTextMuted))),
      ]),
    );

    final dataRows = stockTanks.isEmpty
        ? <Widget>[Text('No active stocks in this rack.',
            style: GoogleFonts.spaceGrotesk(fontSize: 12, color: context.appTextMuted))]
        : stockTanks.map<Widget>((t) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              SizedBox(width: 56, child: Text(t.zebraTankId.split('-').last,
                style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppDS.accent))),
              Expanded(child: Text(t.zebraLine ?? '—',
                style: GoogleFonts.spaceGrotesk(fontSize: 11, color: context.appTextPrimary),
                overflow: TextOverflow.ellipsis)),
              SizedBox(width: 28, child: Text('${t.zebraMales ?? 0}', textAlign: TextAlign.center,
                style: GoogleFonts.jetBrainsMono(fontSize: 11, color: context.appTextSecondary))),
              SizedBox(width: 28, child: Text('${t.zebraFemales ?? 0}', textAlign: TextAlign.center,
                style: GoogleFonts.jetBrainsMono(fontSize: 11, color: context.appTextSecondary))),
              SizedBox(width: 32, child: Text('${t.zebraJuveniles ?? 0}', textAlign: TextAlign.center,
                style: GoogleFonts.jetBrainsMono(fontSize: 11, color: context.appTextSecondary))),
              SizedBox(width: 36, child: Text('${t.totalFish}', textAlign: TextAlign.right,
                style: GoogleFonts.jetBrainsMono(fontSize: 11,
                  fontWeight: FontWeight.w700, color: AppDS.green))),
            ]),
          )).toList();

    return _infoCard(context, 'Active Stocks', Icons.water, [header, ...dataRows]);
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
