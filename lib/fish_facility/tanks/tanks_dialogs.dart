// ── tanks_dialogs.dart ────────────────────────────────────────────────────────
// Part of tanks_page.dart.
// _EditTankDialog  — full tank editor (fish counts, line, feeding, position).
// _RackSettingsDialog — toggle individual slots between standard and 8 L size.
// ─────────────────────────────────────────────────────────────────────────────
part of 'tanks_page.dart';

// ─── EDIT TANK DIALOG ─────────────────────────────────────────────────────────
class _EditTankDialog extends StatefulWidget {
  final ZebrafishTank tank;
  final Set<String>   occupiedTankIds;
  final List<String>  availableRacks;
  final ValueChanged<ZebrafishTank> onSave;
  const _EditTankDialog({
    required this.tank,
    required this.occupiedTankIds,
    required this.availableRacks,
    required this.onSave,
  });

  @override
  State<_EditTankDialog> createState() => _EditTankDialogState();
}

class _EditTankDialogState extends State<_EditTankDialog> {
  late TextEditingController _males, _females, _juvs, _resp, _exp, _notes, _foodAmount;
  late String _status, _health, _type;
  String? _selectedLine;
  int?    _selectedLineId;
  String? _foodType;
  String? _foodFrequency;
  String? _foodSource;
  DateTime? _lastCleaning;
  List<String> _lines = [];
  Map<String, int> _lineIdByName = {};
  bool _loadingLines = true;

  static const _foodTypes   = ['GEMMA 75', 'GEMMA 150', 'GEMMA 300', 'SPAROS 400-600'];
  static const _frequencies = ['1x', '2x', '3x', '4x', '5x', '6x', '7x', '8x', '9x'];
  static const _sources     = ['dry', 'live', 'mixed'];

  // Position picker state
  late String _rack;
  late String _row;
  late int    _col;
  String? _posError;

  bool _isOccupied(int col) =>
      widget.occupiedTankIds.contains('$_rack-$_row$col');
  int get _maxCol => _row == 'A' ? _rowACount : _rowBECount;
  String get _newTankId => '$_rack-$_row$_col';

  @override
  void initState() {
    super.initState();
    final t = widget.tank;
    _males      = TextEditingController(text: '${t.zebraMales ?? 0}');
    _females    = TextEditingController(text: '${t.zebraFemales ?? 0}');
    _juvs       = TextEditingController(text: '${t.zebraJuveniles ?? 0}');
    _resp       = TextEditingController(text: t.zebraResponsible ?? '');
    _exp        = TextEditingController(text: t.zebraExperimentId ?? '');
    _notes      = TextEditingController(text: t.zebraNotes ?? '');
    _foodAmount = TextEditingController(
      text: t.zebraFoodAmount != null ? '${t.zebraFoodAmount}' : '');
    _status       = t.zebraStatus ?? 'active';
    _health       = t.zebraHealthStatus ?? 'healthy';
    _type         = t.zebraTankType ?? 'holding';
    _selectedLine   = t.zebraLine;
    _selectedLineId = t.zebraLineId;
    _foodType     = _foodTypes.contains(t.zebraFoodType) ? t.zebraFoodType : null;
    _foodFrequency = _frequencies.contains(t.zebraFeedingSchedule) ? t.zebraFeedingSchedule : null;
    _foodSource   = _sources.contains(t.zebraFoodSource) ? t.zebraFoodSource : null;
    _lastCleaning = t.zebraLastTankCleaning;
    _rack = t.zebraRack   ?? 'R1';
    _row  = t.zebraRow    ?? 'B';
    _col  = int.tryParse(t.zebraColumn ?? '1') ?? 1;
    _fetchLines();
  }

  Future<void> _fetchLines() async {
    try {
      final rows = (await Supabase.instance.client
          .from('fish_lines')
          .select('fish_line_id, fish_line_name')
          .eq('fish_line_status', 'active')
          .order('fish_line_name') as List<dynamic>)
          .cast<Map<String, dynamic>>();
      if (mounted) setState(() {
        _lineIdByName = { for (final r in rows) r['fish_line_name'] as String: r['fish_line_id'] as int };
        _lines = rows.map((r) => r['fish_line_name'] as String).toList();
        // keep current line even if inactive
        if (_selectedLine != null && !_lines.contains(_selectedLine)) {
          _lines.insert(0, _selectedLine!);
        }
        // resolve line ID from name if not already set
        if (_selectedLineId == null && _selectedLine != null) {
          _selectedLineId = _lineIdByName[_selectedLine];
        }
        _loadingLines = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingLines = false);
    }
  }

  @override
  void dispose() {
    _males.dispose(); _females.dispose(); _juvs.dispose();
    _resp.dispose();  _exp.dispose();    _notes.dispose();
    _foodAmount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.appSurface2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: context.appBorder2)),
      title: Row(children: [
        Text('Edit ${widget.tank.zebraTankId}',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 16, fontWeight: FontWeight.w700, color: context.appTextPrimary)),
        const SizedBox(width: 8),
        StatusBadge(label: _status),
        const SizedBox(width: 6),
        Text(widget.tank.volumeLabel,
          style: GoogleFonts.jetBrainsMono(fontSize: 10, color: context.appTextMuted)),
      ]),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Tank Position ──────────────────────────────────────────
            _label('Tank Position'),
            const SizedBox(height: 6),
            _buildPositionPicker(),
            if (_posError != null) ...[
              const SizedBox(height: 4),
              Text(_posError!, style: GoogleFonts.spaceGrotesk(
                fontSize: 11, color: AppDS.red)),
            ],
            const SizedBox(height: 12),
            // ── Fish line ──────────────────────────────────────────────
            _label('Fish Line'),
            const SizedBox(height: 3),
            _loadingLines
                ? const LinearProgressIndicator()
                : DropdownButtonFormField<String>(
                    initialValue: (_selectedLine != null && _lines.contains(_selectedLine))
                        ? _selectedLine : null,
                    dropdownColor: context.appSurface2,
                    style: GoogleFonts.spaceGrotesk(color: context.appTextPrimary, fontSize: 13),
                    hint: Text('Select line', style: GoogleFonts.spaceGrotesk(
                      color: context.appTextMuted, fontSize: 13)),
                    items: _lines.map((l) =>
                      DropdownMenuItem(value: l, child: Text(l))).toList(),
                    onChanged: (v) => setState(() {
                      _selectedLine   = v;
                      _selectedLineId = v != null ? _lineIdByName[v] : null;
                    }),
                    decoration: _inputDec()),
            const SizedBox(height: 8),
            // ── Fish counts ────────────────────────────────────────────
            Row(children: [
              Expanded(child: _f('Males ♂', _males)),
              const SizedBox(width: 8),
              Expanded(child: _f('Females ♀', _females)),
              const SizedBox(width: 8),
              Expanded(child: _f('Juveniles', _juvs)),
            ]),
            const SizedBox(height: 8),
            // ── Status / health / type ─────────────────────────────────
            Row(children: [
              Expanded(child: _dd('Status', _status,
                ['active', 'empty', 'quarantine', 'retired'],
                (v) => setState(() => _status = v ?? _status))),
              const SizedBox(width: 8),
              Expanded(child: _dd('Health', _health,
                ['healthy', 'observation', 'treatment', 'sick'],
                (v) => setState(() => _health = v ?? _health))),
              const SizedBox(width: 8),
              Expanded(child: _dd('Type', _type,
                ['holding', 'breeding', 'quarantine', 'experimental', 'sentinel'],
                (v) => setState(() => _type = v ?? _type))),
            ]),
            const SizedBox(height: 12),
            // ── Food ───────────────────────────────────────────────────
            Text('Feeding', style: GoogleFonts.spaceGrotesk(
              fontSize: 12, fontWeight: FontWeight.w700, color: AppDS.accent)),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: _ddOpt('Food Type', _foodType, _foodTypes,
                (v) => setState(() => _foodType = v))),
              const SizedBox(width: 8),
              Expanded(child: _ddOpt('Frequency', _foodFrequency, _frequencies,
                (v) => setState(() => _foodFrequency = v))),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _ddOpt('Food Source', _foodSource, _sources,
                (v) => setState(() => _foodSource = v))),
              const SizedBox(width: 8),
              Expanded(child: _f('Amount (g)', _foodAmount, mono: true)),
            ]),
            const SizedBox(height: 12),
            // ── Other ──────────────────────────────────────────────────
            // ── Last cleaning ──────────────────────────────────────────
            _label('Last Cleaning'),
            const SizedBox(height: 4),
            _buildCleaningRow(),
            const SizedBox(height: 12),
            _f('Responsible', _resp),
            const SizedBox(height: 8),
            _f('Experiment ID', _exp, mono: true),
            const SizedBox(height: 8),
            _f('Notes', _notes),
          ],
        )),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            foregroundColor: context.appTextSecondary,
            side: BorderSide(color: context.appBorder)),
          child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppDS.accent, foregroundColor: AppDS.bg),
          onPressed: () {
            if (_isOccupied(_col) && _newTankId != widget.tank.zebraTankId) {
              setState(() => _posError = 'Tank $_newTankId is already occupied.');
              return;
            }
            final t = widget.tank;
            final isTop = _row == 'A';
            widget.onSave(ZebrafishTank(
              zebraId:           t.zebraId,
              zebraTankId:       _newTankId,
              zebraRack:         _rack,
              zebraRow:          _row,
              zebraColumn:       '$_col',
              zebraVolumeL:      t.zebraVolumeL,
              isEightLiter:      t.isEightLiter,
              isTopRow:          isTop,
              rackRowIndex:      _rowLabels.indexOf(_row),
              rackColIndex:      _col - 1,
              zebraLine:         _selectedLine,
              zebraLineId:       _selectedLineId,
              zebraMales:        int.tryParse(_males.text) ?? 0,
              zebraFemales:      int.tryParse(_females.text) ?? 0,
              zebraJuveniles:    int.tryParse(_juvs.text) ?? 0,
              zebraResponsible:  _resp.text.trim().isEmpty ? null : _resp.text.trim(),
              zebraStatus:       _status,
              zebraHealthStatus: _health,
              zebraTankType:     _type,
              zebraFoodType:     _foodType,
              zebraFoodSource:   _foodSource,
              zebraFoodAmount:   _foodAmount.text.trim().isEmpty
                  ? null : double.tryParse(_foodAmount.text.trim()),
              zebraFeedingSchedule: _foodFrequency,
              zebraExperimentId:     _exp.text.trim().isEmpty ? null : _exp.text.trim(),
              zebraNotes:            _notes.text.trim().isEmpty ? null : _notes.text.trim(),
              zebraLastTankCleaning: _lastCleaning,
            ));
            Navigator.pop(context);
          },
          child: const Text('Save')),
      ],
    );
  }

  Widget _buildCleaningRow() {
    final label = _lastCleaning != null
        ? '${_lastCleaning!.day.toString().padLeft(2, '0')}/'
          '${_lastCleaning!.month.toString().padLeft(2, '0')}/'
          '${_lastCleaning!.year}'
        : '—';
    return Row(children: [
      Expanded(
        child: InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _lastCleaning ?? DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime.now(),
              builder: (ctx, child) => Theme(
                data: Theme.of(ctx).copyWith(
                  colorScheme: ColorScheme.dark(
                    primary: AppDS.accent,
                    surface: AppDS.surface2,
                  ),
                ),
                child: child!,
              ),
            );
            if (picked != null) setState(() => _lastCleaning = picked);
          },
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: context.appSurface3,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: context.appBorder)),
            child: Row(children: [
              Icon(Icons.calendar_today_outlined, size: 13,
                color: _lastCleaning != null ? AppDS.accent : context.appTextMuted),
              const SizedBox(width: 8),
              Text(label, style: GoogleFonts.jetBrainsMono(
                fontSize: 13,
                color: _lastCleaning != null ? context.appTextPrimary : context.appTextMuted)),
            ]),
          ),
        ),
      ),
      const SizedBox(width: 8),
      OutlinedButton(
        onPressed: () => setState(() => _lastCleaning = DateTime.now()),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppDS.green,
          side: BorderSide(color: AppDS.green.withValues(alpha: 0.5)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        ),
        child: Text('Today', style: GoogleFonts.spaceGrotesk(
          fontSize: 12, fontWeight: FontWeight.w600)),
      ),
      if (_lastCleaning != null) ...[
        const SizedBox(width: 6),
        InkWell(
          onTap: () => setState(() => _lastCleaning = null),
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(Icons.close, size: 14, color: context.appTextMuted)),
        ),
      ],
    ]);
  }

  Widget _label(String t) => Text(t, style: GoogleFonts.spaceGrotesk(
    fontSize: 11, color: context.appTextMuted, fontWeight: FontWeight.w700));

  Widget _f(String l, TextEditingController c, {bool mono = false}) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label(l),
      const SizedBox(height: 3),
      TextField(controller: c,
        style: (mono ? GoogleFonts.jetBrainsMono(fontSize: 13)
            : GoogleFonts.spaceGrotesk(fontSize: 13))
            .copyWith(color: context.appTextPrimary),
        decoration: _inputDec()),
    ]);

  // Dropdown with a nullable value (shows placeholder when unset)
  Widget _ddOpt(String l, String? val, List<String> opts, ValueChanged<String?> cb) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label(l),
      const SizedBox(height: 3),
      DropdownButtonFormField<String>(
        initialValue: opts.contains(val) ? val : null,
        dropdownColor: context.appSurface2,
        style: GoogleFonts.spaceGrotesk(color: context.appTextPrimary, fontSize: 13),
        hint: Text('—', style: GoogleFonts.spaceGrotesk(
          color: context.appTextMuted, fontSize: 13)),
        items: opts.map((v) =>
          DropdownMenuItem(value: v, child: Text(v))).toList(),
        onChanged: cb,
        decoration: _inputDec()),
    ]);

  Widget _dd(String l, String val, List<String> opts, ValueChanged<String?> cb) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label(l),
      const SizedBox(height: 3),
      DropdownButtonFormField<String>(
        initialValue: opts.contains(val) ? val : opts.first,
        dropdownColor: context.appSurface2,
        style: GoogleFonts.spaceGrotesk(color: context.appTextPrimary, fontSize: 13),
        items: opts.map((v) =>
          DropdownMenuItem(value: v, child: Text(v))).toList(),
        onChanged: cb,
        decoration: _inputDec()),
    ]);

  InputDecoration _inputDec() => InputDecoration(
    isDense: true, filled: true, fillColor: context.appSurface3,
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: BorderSide(color: context.appBorder)),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: const BorderSide(color: AppDS.accent, width: 1.5)));

  Widget _buildPositionPicker() {
    final rackList = widget.availableRacks;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.appSurface3,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.appBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Rack
        Row(children: [
          Text('Rack:', style: GoogleFonts.spaceGrotesk(
            fontSize: 11, color: context.appTextMuted, fontWeight: FontWeight.w700)),
          const SizedBox(width: 10),
          ...rackList.map((r) => Padding(
            padding: const EdgeInsets.only(right: 6),
            child: InkWell(
              onTap: () => setState(() {
                _rack = r;
                _posError = null;
              }),
              borderRadius: BorderRadius.circular(6),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: 38, height: 32,
                decoration: BoxDecoration(
                  color: _rack == r
                      ? AppDS.accent.withValues(alpha: 0.2) : context.appSurface2,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _rack == r ? AppDS.accent : context.appBorder,
                    width: _rack == r ? 1.5 : 1)),
                child: Center(child: Text(r, style: GoogleFonts.jetBrainsMono(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: _rack == r ? AppDS.accent : context.appTextSecondary))),
              ),
            ),
          )),
        ]),
        const SizedBox(height: 10),
        // Row
        Row(children: [
          Text('Row:', style: GoogleFonts.spaceGrotesk(
            fontSize: 11, color: context.appTextMuted, fontWeight: FontWeight.w700)),
          const SizedBox(width: 10),
          ..._rowLabels.map((r) => Padding(
            padding: const EdgeInsets.only(right: 6),
            child: InkWell(
              onTap: () => setState(() {
                _row = r;
                if (_col > _maxCol) _col = 1;
                _posError = null;
              }),
              borderRadius: BorderRadius.circular(6),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: 38, height: 44,
                decoration: BoxDecoration(
                  color: _row == r
                      ? AppDS.accent.withValues(alpha: 0.2) : context.appSurface2,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _row == r ? AppDS.accent : context.appBorder,
                    width: _row == r ? 1.5 : 1)),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(r, style: GoogleFonts.jetBrainsMono(
                    fontSize: 12, fontWeight: FontWeight.w700,
                    color: _row == r ? AppDS.accent : context.appTextSecondary)),
                  Text(r == 'A' ? '1.1 L' : '3.5 L',
                    style: GoogleFonts.jetBrainsMono(fontSize: 8,
                      color: _row == r
                          ? AppDS.accent.withValues(alpha: 0.8)
                          : context.appTextMuted)),
                ]),
              ),
            ),
          )),
        ]),
        const SizedBox(height: 10),
        // Column
        Text('Column:', style: GoogleFonts.spaceGrotesk(
          fontSize: 11, color: context.appTextMuted, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 5, runSpacing: 5,
          children: List.generate(_maxCol, (i) {
            final c = i + 1;
            final sel      = _col == c;
            final occupied = _isOccupied(c);
            return InkWell(
              onTap: () => setState(() { _col = c; _posError = null; }),
              borderRadius: BorderRadius.circular(5),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: 34, height: 30,
                decoration: BoxDecoration(
                  color: occupied
                      ? AppDS.red.withValues(alpha: 0.12)
                      : (sel ? AppDS.accent.withValues(alpha: 0.18) : context.appSurface2),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: occupied
                        ? AppDS.red.withValues(alpha: 0.5)
                        : (sel ? AppDS.accent : context.appBorder),
                    width: sel ? 1.5 : 1)),
                child: Center(child: Text('$c', style: GoogleFonts.jetBrainsMono(
                  fontSize: 11, fontWeight: FontWeight.w600,
                  color: occupied
                      ? AppDS.red
                      : (sel ? AppDS.accent : context.appTextSecondary)))),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Text('Red = already occupied by another stock.',
          style: GoogleFonts.jetBrainsMono(fontSize: 10, color: context.appTextMuted)),
        const SizedBox(height: 4),
        Row(children: [
          const Icon(Icons.location_on_outlined, size: 13, color: AppDS.accent),
          const SizedBox(width: 4),
          Text('Selected: $_newTankId',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12, fontWeight: FontWeight.w700, color: AppDS.accent)),
        ]),
      ]),
    );
  }
}

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
    for (final t in _tanks) byRow.putIfAbsent(t.zebraRow ?? '?', () => []).add(t);
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
