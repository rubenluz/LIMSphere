// add_stock_dialog.dart - Dialog for adding a new fish stock to a tank:
// line selector, rack/row/column position picker, male/female/juvenile counts.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'stocks/stocks_connection_model.dart';
import '/theme/theme.dart';
import '/supabase/supabase_manager.dart';
import '/camera/qr_scanner/qr_code_rules.dart';

// ZebTec rack constants (mirrors tanks_page / stocks_page)
const _rowLabels  = ['A', 'B', 'C', 'D', 'E'];
const _rowACount  = 15;  // 1.1 L
const _rowBECount = 10;  // 3.5 L

// ─── Prefill data for duplication ─────────────────────────────────────────────
// Columns that must never be copied from a source row (position + identity + timestamps).
const _stripCols = {
  'fish_stocks_id',
  'fish_stocks_tank_id',
  'fish_stocks_rack',
  'fish_stocks_row',
  'fish_stocks_column',
  'fish_stocks_created_at',
  'fish_stocks_updated_at',
  'fish_lines', // joined object, not a real column
};

class FishStockPrefill {
  /// UI-visible fields shown / editable in the dialog.
  final String?  line;
  final String?  responsible;
  final String?  experiment;
  final String?  notes;
  final String?  status;
  final String?  health;
  final int      males;
  final int      females;
  final int      juveniles;
  // Tank position
  final String?  rack;
  final String?  row;
  final int?     col;
  // Feeding
  final String?  foodType;
  final String?  foodSource;
  final double?  foodAmount;
  final String?  feedingSchedule;

  /// Full DB row from the source stock. All non-stripped columns are
  /// written verbatim on insert so every field is duplicated automatically.
  final Map<String, dynamic>? rawRow;

  const FishStockPrefill({
    this.line,
    this.responsible,
    this.experiment,
    this.notes,
    this.status,
    this.health,
    this.males     = 0,
    this.females   = 0,
    this.juveniles = 0,
    this.rack,
    this.row,
    this.col,
    this.foodType,
    this.foodSource,
    this.foodAmount,
    this.feedingSchedule,
    this.rawRow,
  });
}

// ─── Shared Add / Duplicate Stock Dialog ─────────────────────────────────────
class AddStockDialog extends StatefulWidget {
  final Set<String>             occupiedTankIds;
  final List<String>            availableRacks;
  final ValueChanged<FishStock> onAdd;
  /// When set, the dialog is in "Duplicate" mode and fields are pre-filled.
  final FishStockPrefill?       prefill;

  const AddStockDialog({
    super.key,
    required this.occupiedTankIds,
    required this.availableRacks,
    required this.onAdd,
    this.prefill,
  });

  @override
  State<AddStockDialog> createState() => _AddStockDialogState();
}

class _AddStockDialogState extends State<AddStockDialog> {
  String? _selectedLine;
  List<String> _activeLineNames = [];
  Map<String, int> _lineIdByName = {};
  Map<String, DateTime?> _lineDobByName = {};
  bool _loadingLines = true;

  late final TextEditingController _respCtrl;
  late final TextEditingController _expCtrl;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _malesCtrl;
  late final TextEditingController _femalesCtrl;
  late final TextEditingController _juvsCtrl;
  late final TextEditingController _foodAmountCtrl;

  String? _foodType;
  String? _foodSource;
  String? _feedingSchedule;

  static const _foodTypes   = ['GEMMA 75', 'GEMMA 150', 'GEMMA 300', 'SPAROS 400-600'];
  static const _foodSources = ['dry', 'live', 'mixed'];
  static const _frequencies = ['1x', '2x', '3x', '4x', '5x', '6x', '7x', '8x', '9x'];

  String _selectedRack = 'R1';
  String _selectedRow  = 'A';
  int    _selectedCol  = 1;
  late String _status;
  late String _health;
  bool   _saving = false;
  String? _error;

  bool get _isDuplicate => widget.prefill != null;

  String get _tankId => '$_selectedRack-$_selectedRow$_selectedCol';
  int get _maxCol => _selectedRow == 'A' ? _rowACount : _rowBECount;

  bool _isOccupied(int col) =>
      widget.occupiedTankIds.contains('$_selectedRack-$_selectedRow$col');

  void _selectFirstAvailable() {
    for (int col = 1; col <= _maxCol; col++) {
      if (!_isOccupied(col)) { _selectedCol = col; return; }
    }
  }

  @override
  void initState() {
    super.initState();
    final p = widget.prefill;
    _respCtrl       = TextEditingController(text: p?.responsible ?? '');
    _expCtrl        = TextEditingController(text: p?.experiment  ?? '');
    _notesCtrl      = TextEditingController(text: p?.notes       ?? '');
    _malesCtrl      = TextEditingController(text: '${p?.males    ?? 0}');
    _femalesCtrl    = TextEditingController(text: '${p?.females  ?? 0}');
    _juvsCtrl       = TextEditingController(text: '${p?.juveniles ?? 0}');
    _foodAmountCtrl = TextEditingController(
        text: p?.foodAmount != null ? '${p!.foodAmount}' : '');
    _status          = p?.status ?? 'active';
    _health          = p?.health ?? 'healthy';
    _foodType        = p?.foodType;
    _foodSource      = p?.foodSource;
    _feedingSchedule = p?.feedingSchedule;
    final racks = widget.availableRacks;
    if (p?.rack != null && racks.contains(p!.rack)) {
      _selectedRack = p.rack!;
    } else if (racks.isNotEmpty) {
      _selectedRack = racks.first;
    }
    if (p?.row  != null) _selectedRow  = p!.row!;
    if (p?.col  != null) _selectedCol  = p!.col!;
    if (_isOccupied(_selectedCol)) _selectFirstAvailable();
    _loadActiveLines();
  }

  @override
  void dispose() {
    _respCtrl.dispose();
    _expCtrl.dispose();
    _notesCtrl.dispose();
    _malesCtrl.dispose();
    _femalesCtrl.dispose();
    _juvsCtrl.dispose();
    _foodAmountCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadActiveLines() async {
    try {
      final rows = (await Supabase.instance.client
          .from('fish_lines')
          .select('fish_line_id, fish_line_name, fish_line_date_birth')
          .eq('fish_line_status', 'active')
          .order('fish_line_name') as List<dynamic>)
          .cast<Map<String, dynamic>>();
      if (mounted) {
        setState(() {
          _activeLineNames = rows.map((r) => r['fish_line_name'] as String).toList();
          _lineIdByName = { for (final r in rows) r['fish_line_name'] as String: r['fish_line_id'] as int };
          _lineDobByName = {
            for (final r in rows)
              r['fish_line_name'] as String: r['fish_line_date_birth'] != null
                  ? DateTime.tryParse(r['fish_line_date_birth'].toString())
                  : null,
          };
          _loadingLines = false;
          final prefillLine = widget.prefill?.line;
          if (prefillLine != null && _activeLineNames.contains(prefillLine)) {
            _selectedLine = prefillLine;
          } else if (_activeLineNames.isNotEmpty) {
            _selectedLine = _activeLineNames.first;
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingLines = false);
    }
  }

  Future<void> _submit() async {
    if (_selectedLine == null) {
      setState(() => _error = 'Please select a fish line.');
      return;
    }
    if (widget.occupiedTankIds.contains(_tankId)) {
      setState(() => _error = 'Tank $_tankId is already occupied.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      // Start from the full source row when duplicating, then strip
      // position/identity/timestamp columns and let user-chosen values win.
      final payload = <String, dynamic>{};
      final raw = widget.prefill?.rawRow;
      if (raw != null) {
        for (final e in raw.entries) {
          if (!_stripCols.contains(e.key)) payload[e.key] = e.value;
        }
      }
      // User-selected / dialog-controlled fields always override.
      payload['fish_stocks_line']          = _selectedLine;
      payload['fish_stocks_line_id']       = _lineIdByName[_selectedLine];
      payload['fish_stocks_tank_id']       = _tankId;
      payload['fish_stocks_rack']          = _selectedRack;
      payload['fish_stocks_row']           = _selectedRow;
      payload['fish_stocks_column']        = _selectedCol.toString();
      payload['fish_stocks_responsible']   = _respCtrl.text.trim();
      payload['fish_stocks_status']        = _status;
      payload['fish_stocks_health_status'] = _health;
      payload['fish_stocks_males']         = int.tryParse(_malesCtrl.text.trim())   ?? 0;
      payload['fish_stocks_females']       = int.tryParse(_femalesCtrl.text.trim()) ?? 0;
      payload['fish_stocks_juveniles']     = int.tryParse(_juvsCtrl.text.trim())    ?? 0;
      if (_foodType     != null) payload['fish_stocks_food_type']         = _foodType;
      if (_foodSource   != null) payload['fish_stocks_food_source']       = _foodSource;
      if (_feedingSchedule != null) payload['fish_stocks_feeding_schedule'] = _feedingSchedule;
      final fa = double.tryParse(_foodAmountCtrl.text.trim());
      if (fa != null) payload['fish_stocks_food_amount'] = fa;
      if (_expCtrl.text.isNotEmpty) {
        payload['fish_stocks_experiment_id'] = _expCtrl.text.trim();
      }
      if (_notesCtrl.text.isNotEmpty) {
        payload['fish_stocks_notes'] = _notesCtrl.text.trim();
      }
      final lineDob = _lineDobByName[_selectedLine];
      if (lineDob != null) {
        payload['fish_stocks_dob'] = lineDob.toIso8601String().substring(0, 10);
      }

      final resp = await Supabase.instance.client
          .from('fish_stocks')
          .insert(payload)
          .select()
          .single();

      final stockId = resp['fish_stocks_id'] as int;
      final qrcode = QrRules.build(
          SupabaseManager.projectRef ?? 'local', 'fish_stocks', stockId);
      await Supabase.instance.client
          .from('fish_stocks')
          .update({'fish_stocks_qrcode': qrcode})
          .eq('fish_stocks_id', stockId);

      widget.onAdd(FishStock(
        stockId:     resp['fish_stocks_id'].toString(),
        line:        _selectedLine!,
        males:       int.tryParse(_malesCtrl.text.trim())   ?? 0,
        females:     int.tryParse(_femalesCtrl.text.trim()) ?? 0,
        juveniles:   int.tryParse(_juvsCtrl.text.trim())    ?? 0,
        tankId:      _tankId,
        responsible: _respCtrl.text.trim(),
        status:      _status,
        health:      _health,
        experiment:  _expCtrl.text.isEmpty  ? null : _expCtrl.text.trim(),
        notes:       _notesCtrl.text.isEmpty ? null : _notesCtrl.text.trim(),
        created:     DateTime.now(),
      ));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() { _saving = false; _error = 'Failed to save: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.appSurface2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: context.appBorder2)),
      title: Text(
        _isDuplicate
            ? 'Duplicate Stock — ${widget.prefill!.line ?? ''}'
            : 'New Fish Stock',
        style: GoogleFonts.spaceGrotesk(
          color: context.appTextPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppDS.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppDS.red.withValues(alpha: 0.4)),
                  ),
                  child: Text(_error!,
                    style: GoogleFonts.spaceGrotesk(color: AppDS.red, fontSize: 12)),
                ),
                const SizedBox(height: 12),
              ],
              _lineDropdown(),
              const SizedBox(height: 10),
              _f('Responsible', _respCtrl),
              const SizedBox(height: 12),
              Text('Tank Position *',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 11, color: context.appTextMuted, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              _buildTankPicker(),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _dd('Status', _status,
                  ['active', 'empty', 'quarantine', 'retired'],
                  (v) => setState(() => _status = v ?? _status))),
                const SizedBox(width: 10),
                Expanded(child: _dd('Health', _health,
                  ['healthy', 'observation', 'treatment', 'sick'],
                  (v) => setState(() => _health = v ?? _health))),
              ]),
              const SizedBox(height: 12),
              Text('Fish Counts', style: GoogleFonts.spaceGrotesk(
                fontSize: 11, color: context.appTextMuted, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(child: _fMono('Males ♂', _malesCtrl)),
                const SizedBox(width: 8),
                Expanded(child: _fMono('Females ♀', _femalesCtrl)),
                const SizedBox(width: 8),
                Expanded(child: _fMono('Juveniles', _juvsCtrl)),
              ]),
              const SizedBox(height: 12),
              Text('Feeding (optional)', style: GoogleFonts.spaceGrotesk(
                fontSize: 11, color: context.appTextMuted, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(child: _ddOpt('Food Type', _foodType, _foodTypes,
                  (v) => setState(() => _foodType = v))),
                const SizedBox(width: 8),
                Expanded(child: _ddOpt('Source', _foodSource, _foodSources,
                  (v) => setState(() => _foodSource = v))),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _ddOpt('Frequency', _feedingSchedule, _frequencies,
                  (v) => setState(() => _feedingSchedule = v))),
                const SizedBox(width: 8),
                Expanded(child: _fMono('Amount (g)', _foodAmountCtrl)),
              ]),
              const SizedBox(height: 10),
              _f('Experiment ID (optional)', _expCtrl),
              const SizedBox(height: 10),
              _f('Notes (optional)', _notesCtrl),
            ],
          ),
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _saving ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: _isDuplicate ? AppDS.purple : AppDS.accent,
            foregroundColor: AppDS.bg),
          child: _saving
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(_isDuplicate ? 'Duplicate' : 'Add Stock'),
        ),
      ],
    );
  }

  // ─── Tank picker ────────────────────────────────────────────────────────────
  Widget _buildTankPicker() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.appSurface3,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.appBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('Rack:', style: GoogleFonts.spaceGrotesk(
              fontSize: 11, color: context.appTextMuted, fontWeight: FontWeight.w700)),
            const SizedBox(width: 10),
            ...widget.availableRacks.map((rack) => Padding(
              padding: const EdgeInsets.only(right: 6),
              child: InkWell(
                onTap: () => setState(() {
                  _selectedRack = rack;
                  if (_isOccupied(_selectedCol)) _selectFirstAvailable();
                }),
                borderRadius: BorderRadius.circular(6),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: 38, height: 32,
                  decoration: BoxDecoration(
                    color: _selectedRack == rack
                        ? AppDS.accent.withValues(alpha: 0.2) : context.appSurface2,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _selectedRack == rack ? AppDS.accent : context.appBorder,
                      width: _selectedRack == rack ? 1.5 : 1),
                  ),
                  child: Center(child: Text(rack, style: GoogleFonts.jetBrainsMono(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: _selectedRack == rack ? AppDS.accent : context.appTextSecondary))),
                ),
              ),
            )),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Text('Row:', style: GoogleFonts.spaceGrotesk(
              fontSize: 11, color: context.appTextMuted, fontWeight: FontWeight.w700)),
            const SizedBox(width: 10),
            ..._rowLabels.map((r) => Padding(
              padding: const EdgeInsets.only(right: 6),
              child: InkWell(
                onTap: () => setState(() {
                  _selectedRow = r;
                  if (_selectedCol > _maxCol) _selectedCol = 1;
                  if (_isOccupied(_selectedCol)) _selectFirstAvailable();
                }),
                borderRadius: BorderRadius.circular(6),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: 38, height: 44,
                  decoration: BoxDecoration(
                    color: _selectedRow == r
                        ? AppDS.accent.withValues(alpha: 0.2) : context.appSurface2,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _selectedRow == r ? AppDS.accent : context.appBorder,
                      width: _selectedRow == r ? 1.5 : 1),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(r, style: GoogleFonts.jetBrainsMono(
                      fontSize: 12, fontWeight: FontWeight.w700,
                      color: _selectedRow == r ? AppDS.accent : context.appTextSecondary)),
                    Text(r == 'A' ? '1.1 L' : '3.5 L',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 8,
                        color: _selectedRow == r
                            ? AppDS.accent.withValues(alpha: 0.8)
                            : context.appTextMuted)),
                  ]),
                ),
              ),
            )),
            const SizedBox(width: 8),
            Text(
              _selectedRow == 'A' ? '(15 × 1.1 L)' : '(10 × 3.5 L)',
              style: GoogleFonts.jetBrainsMono(fontSize: 10, color: context.appTextMuted)),
          ]),
          const SizedBox(height: 10),
          Text('Column:', style: GoogleFonts.spaceGrotesk(
            fontSize: 11, color: context.appTextMuted, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 5, runSpacing: 5,
            children: List.generate(_maxCol, (i) {
              final col = i + 1;
              final sel      = _selectedCol == col;
              final occupied = _isOccupied(col);
              return InkWell(
                onTap: occupied ? null : () => setState(() => _selectedCol = col),
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
                      width: sel ? 1.5 : 1),
                  ),
                  child: Center(child: Text('$col', style: GoogleFonts.jetBrainsMono(
                    fontSize: 11, fontWeight: FontWeight.w600,
                    color: occupied
                        ? AppDS.red
                        : (sel ? AppDS.accent : context.appTextSecondary)))),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Text('Red positions are already occupied.',
            style: GoogleFonts.jetBrainsMono(fontSize: 10, color: context.appTextMuted)),
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.location_on_outlined, size: 13, color: AppDS.accent),
            const SizedBox(width: 4),
            Text('Selected: $_tankId',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12, fontWeight: FontWeight.w700, color: AppDS.accent)),
          ]),
        ],
      ),
    );
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────
  Widget _lineDropdown() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Fish Line *', style: GoogleFonts.spaceGrotesk(
        fontSize: 11, color: context.appTextMuted, fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      _loadingLines
          ? const SizedBox(height: 40, child: Center(
              child: CircularProgressIndicator(strokeWidth: 2)))
          : DropdownButtonFormField<String>(
              initialValue: _selectedLine,
              dropdownColor: context.appSurface2,
              style: GoogleFonts.spaceGrotesk(color: context.appTextPrimary, fontSize: 13),
              hint: Text('Select a line', style: GoogleFonts.spaceGrotesk(
                color: context.appTextMuted, fontSize: 13)),
              items: _activeLineNames
                  .map((n) => DropdownMenuItem(value: n, child: Text(n)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedLine = v),
              decoration: _inputDec()),
    ],
  );

  Widget _fMono(String label, TextEditingController ctrl) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: GoogleFonts.spaceGrotesk(
        fontSize: 11, color: context.appTextMuted, fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      TextField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: GoogleFonts.jetBrainsMono(color: context.appTextPrimary, fontSize: 13),
        decoration: _inputDec()),
    ],
  );

  Widget _ddOpt(String label, String? value, List<String> opts, ValueChanged<String?> cb) =>
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.spaceGrotesk(
          fontSize: 11, color: context.appTextMuted, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          initialValue: value,
          dropdownColor: context.appSurface2,
          style: GoogleFonts.spaceGrotesk(color: context.appTextPrimary, fontSize: 13),
          hint: Text('—', style: GoogleFonts.spaceGrotesk(
            color: context.appTextMuted, fontSize: 13)),
          items: opts.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
          onChanged: cb,
          decoration: _inputDec()),
      ],
    );

  Widget _f(String label, TextEditingController ctrl) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: GoogleFonts.spaceGrotesk(
        fontSize: 11, color: context.appTextMuted, fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      TextField(
        controller: ctrl,
        style: GoogleFonts.spaceGrotesk(color: context.appTextPrimary, fontSize: 13),
        decoration: _inputDec()),
    ],
  );

  Widget _dd(String label, String value, List<String> opts, ValueChanged<String?> cb) =>
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.spaceGrotesk(
          fontSize: 11, color: context.appTextMuted, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          initialValue: value,
          dropdownColor: context.appSurface2,
          style: GoogleFonts.spaceGrotesk(color: context.appTextPrimary, fontSize: 13),
          items: opts.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
          onChanged: cb,
          decoration: _inputDec()),
      ],
    );

  InputDecoration _inputDec() => InputDecoration(
    isDense: true,
    filled: true, fillColor: context.appSurface3,
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: BorderSide(color: context.appBorder)),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: const BorderSide(color: AppDS.accent, width: 1.5)),
  );
}
