// ── tanks_dialogs.dart ────────────────────────────────────────────────────────
// Part of tanks_page.dart.
// _RackSettingsDialog — toggle individual slots between standard and 8 L size.
// ─────────────────────────────────────────────────────────────────────────────
part of 'tanks_page.dart';

// ─── 8L CONFIG DIALOG ────────────────────────────────────────────────────────
class _RackSettingsDialog extends StatefulWidget {
  final List<ZebrafishTank> tanks;
  final ValueChanged<List<ZebrafishTank>> onUpdate;
  const _RackSettingsDialog({required this.tanks, required this.onUpdate});

  @override
  State<_RackSettingsDialog> createState() => _RackSettingsDialogState();
}

class _RackSettingsDialogState extends State<_RackSettingsDialog> {
  late List<ZebrafishTank> _tanks;

  @override
  void initState() {
    super.initState();
    _tanks = List.from(widget.tanks);
  }

  @override
  Widget build(BuildContext context) {
    final byRow = <String, List<ZebrafishTank>>{};
    for (final t in _tanks) {
      byRow.putIfAbsent(t.zebraRow ?? '?', () => []).add(t);
    }
    final sortedRows = byRow.keys.toList()
      ..sort()
      ..removeWhere((k) => k == 'A');

    return AlertDialog(
      backgroundColor: AppDS.surface2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppDS.border2)),
      title: Text('4.8 L Slot Configuration',
        style: GoogleFonts.spaceGrotesk(
          fontSize: 16, fontWeight: FontWeight.w700, color: AppDS.textPrimary)),
      content: SizedBox(width: 540, height: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tap any slot to toggle its size. '
              'Row A: 1.1 L → 2.4 L.  Rows B-E: 3.5 L → 8.0 L. '
              'A merged slot spans 2 adjacent positions.',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 12, color: AppDS.textSecondary)),
            const SizedBox(height: 14),
            Expanded(child: SingleChildScrollView(
              child: Column(
                children: sortedRows.map(
                  (r) => _rowCfg(r, byRow[r]!)).toList()))),
          ],
        ),
      ),
      actions: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppDS.accent, foregroundColor: AppDS.bg),
          onPressed: () {
            widget.onUpdate(_tanks);
            Navigator.pop(context);
          },
          child: const Text('Apply')),
      ],
    );
  }

  Widget _rowCfg(String row, List<ZebrafishTank> tanks) =>
    Padding(padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Row $row', style: GoogleFonts.spaceGrotesk(
          fontSize: 12, fontWeight: FontWeight.w700, color: AppDS.textSecondary)),
        const SizedBox(height: 6),
        Wrap(spacing: 5, runSpacing: 5, children: tanks.map((t) {
          final is8 = t.isEightLiter;
          return InkWell(
            onTap: () {
              setState(() {
                final idx = _tanks.indexWhere(
                  (x) => x.zebraTankId == t.zebraTankId);
                if (idx >= 0) {
                  final tgt = _tanks[idx];
                  final volL = !is8
                      ? (tgt.isTopRow ? 2.4 : 8.0)
                      : (tgt.isTopRow ? 1.1 : 3.5);
                  _tanks[idx] = tgt.copyWith(isEightLiter: !is8, zebraVolumeL: volL);
                }
              });
            },
            borderRadius: BorderRadius.circular(5),
            child: Container(
              width: 54, height: 36,
              decoration: BoxDecoration(
                color: is8 ? AppDS.accent.withValues(alpha:0.15) : AppDS.surface3,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: is8 ? AppDS.accent : AppDS.border)),
              child: Column(mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(t.zebraColumn ?? '', style: GoogleFonts.jetBrainsMono(
                    fontSize: 9, color: AppDS.textMuted)),
                  Text(is8
                      ? (t.isTopRow ? '2.4 L' : '8.0 L')
                      : (t.isTopRow ? '1.1 L' : '2.4 L'),
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9, fontWeight: FontWeight.w700,
                      color: is8 ? AppDS.accent : AppDS.textMuted)),
                ]),
            ),
          );
        }).toList()),
      ]),
    );
}
