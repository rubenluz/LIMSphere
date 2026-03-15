import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'tanks_connection_model.dart';
import '../lines/fish_lines_connection_model.dart';
import '../lines/fish_lines_detail_page.dart';

// ─── Design tokens (mirrors strain_detail_page light theme) ──────────────────
class _DS {
  static const Color headerBg   = Color(0xFF1E293B);
  static const Color accent     = Color(0xFF3B82F6);
  static const Color sectionBg  = Color(0xFFF8FAFC);
  static const Color cardBorder = Color(0xFFE2E8F0);
  static const Color labelColor = Color(0xFF64748B);
  static const Color titleColor = Color(0xFF0F172A);
  static const Color scaffoldBg = Color(0xFFF1F5F9);
  static const Color green      = Color(0xFF16A34A);
  static const Color yellow     = Color(0xFFD97706);
  static const Color red        = Color(0xFFDC2626);
  static const Color orange     = Color(0xFFEA580C);
  static const Color pink       = Color(0xFFDB2777);

  static const TextStyle sectionTitle = TextStyle(
    fontSize: 12, fontWeight: FontWeight.w700,
    color: Color(0xFF64748B), letterSpacing: 0.8,
  );
}

// ─── Field & group definitions ────────────────────────────────────────────────
typedef _Field = ({String key, String label, int lines});

const _groups = <({String title, String icon, List<_Field> fields})>[
  (
    title: 'Identity',
    icon: 'identity',
    fields: [
      (key: 'fish_stocks_tank_id',         label: 'Tank Position',        lines: 1),
      (key: 'fish_stocks_tank_type',        label: 'Tank Type',            lines: 1),
      (key: 'fish_stocks_volume_l',         label: 'Volume (L)',           lines: 1),
      (key: 'fish_stocks_line',             label: 'Fish Line',            lines: 1),
      (key: 'fish_stocks_status',           label: 'Status',               lines: 1),
      (key: 'fish_stocks_sentinel_status',  label: 'Sentinel Status',      lines: 1),
    ],
  ),
  (
    title: 'Occupants',
    icon: 'occupants',
    fields: [
      (key: '_line_date_birth',             label: 'Line Date of Birth',   lines: 1),
      (key: '_age_days',                    label: 'Age (days)',            lines: 1),
      (key: '_age_months',                  label: 'Age (months)',          lines: 1),
      (key: '_maturity',                    label: 'Maturity',             lines: 1),
      (key: 'fish_stocks_males',            label: 'Males \u2642',         lines: 1),
      (key: 'fish_stocks_females',          label: 'Females \u2640',       lines: 1),
      (key: 'fish_stocks_juveniles',        label: 'Juveniles',            lines: 1),
      (key: 'fish_stocks_mortality',        label: 'Mortality',            lines: 1),
    ],
  ),
  (
    title: 'Status & Health',
    icon: 'health',
    fields: [
      (key: 'fish_stocks_health_status',    label: 'Health Status',        lines: 1),
      (key: 'fish_stocks_last_health_check',label: 'Last Health Check',    lines: 1),
      (key: 'fish_stocks_treatment',        label: 'Treatment',            lines: 2),
    ],
  ),
  (
    title: 'Feeding',
    icon: 'feeding',
    fields: [
      (key: 'fish_stocks_food_type',        label: 'Food Type',            lines: 1),
      (key: 'fish_stocks_food_source',      label: 'Food Source',          lines: 1),
      (key: 'fish_stocks_food_amount',      label: 'Amount (g or clicks)', lines: 1),
      (key: 'fish_stocks_feeding_schedule', label: 'Frequency',            lines: 1),
    ],
  ),
  (
    title: 'Water Quality',
    icon: 'water',
    fields: [
      (key: 'fish_stocks_temperature_c',    label: 'Temperature (\u00b0C)',    lines: 1),
      (key: 'fish_stocks_ph',               label: 'pH',                       lines: 1),
      (key: 'fish_stocks_conductivity',     label: 'Conductivity (\u00b5S/cm)', lines: 1),
      (key: 'fish_stocks_light_cycle',      label: 'Light Cycle',              lines: 1),
    ],
  ),
  (
    title: 'Maintenance',
    icon: 'maintenance',
    fields: [
      (key: 'fish_stocks_last_tank_cleaning',     label: 'Last Cleaning',            lines: 1),
      (key: 'fish_stocks_cleaning_interval_days', label: 'Cleaning Interval (days)', lines: 1),
    ],
  ),
  (
    title: 'Breeding',
    icon: 'breeding',
    fields: [
      (key: '_line_breeders',               label: 'Parent Lines',         lines: 1),
      (key: 'fish_stocks_last_breeding',    label: 'Last Breeding',        lines: 1),
      (key: 'fish_stocks_last_count_date',  label: 'Last Count Date',      lines: 1),
      (key: 'fish_stocks_cross_id',         label: 'Cross ID',             lines: 1),
      (key: 'fish_stocks_breeding_group',   label: 'Breeding Group',       lines: 1),
    ],
  ),
  (
    title: 'Research',
    icon: 'research',
    fields: [
      (key: 'fish_stocks_experiment_id',    label: 'Experiment ID',        lines: 1),
      (key: 'fish_stocks_ethics_approval',  label: 'Ethics Approval',      lines: 1),
    ],
  ),
  (
    title: 'Responsible',
    icon: 'responsible',
    fields: [
      (key: 'fish_stocks_responsible',      label: 'Responsible',          lines: 1),
    ],
  ),
  (
    title: 'Notes',
    icon: 'notes',
    fields: [
      (key: 'fish_stocks_notes',            label: 'Notes',                lines: 5),
    ],
  ),
];

// ─── Constrained dropdowns ────────────────────────────────────────────────────
const _dropdowns = <String, List<String>>{
  'fish_stocks_status':           ['active', 'empty', 'quarantine', 'retired'],
  'fish_stocks_tank_type':        ['holding', 'breeding', 'quarantine', 'experimental', 'sentinel'],
  'fish_stocks_sentinel_status':  ['none', 'sentinel', 'tested'],
  'fish_stocks_health_status':    ['healthy', 'observation', 'treatment', 'sick'],
  'fish_stocks_food_type':        ['GEMMA 75', 'GEMMA 150', 'GEMMA 300', 'SPAROS 400-600'],
  'fish_stocks_food_source':      ['dry', 'live', 'mixed'],
  'fish_stocks_feeding_schedule': ['1x', '2x', '3x', '4x', '5x', '6x', '7x', '8x', '9x'],
  'fish_stocks_breeding_group':   ['true', 'false'],
};

// ─── Date picker fields ───────────────────────────────────────────────────────
const _datePickers = <String>{
  'fish_stocks_last_health_check',
  'fish_stocks_last_breeding',
  'fish_stocks_last_count_date',
  'fish_stocks_last_tank_cleaning',
};

// ─── Pseudo-computed keys (never saved to DB) ─────────────────────────────────
const _computedKeys = <String>{
  '_line_date_birth', '_age_days', '_age_months', '_maturity',
};

// ─── ZebTec rack constants ────────────────────────────────────────────────────
const _detailRowLabels = ['A', 'B', 'C', 'D', 'E'];

// ─── Helpers ──────────────────────────────────────────────────────────────────
IconData _sectionIcon(String icon) => switch (icon) {
  'identity'    => Icons.tag_rounded,
  'occupants'   => Icons.water_rounded,
  'health'      => Icons.health_and_safety_outlined,
  'feeding'     => Icons.set_meal_outlined,
  'water'       => Icons.opacity_rounded,
  'maintenance' => Icons.build_outlined,
  'breeding'    => Icons.favorite_border_rounded,
  'research'    => Icons.science_outlined,
  'responsible' => Icons.person_outline_rounded,
  _             => Icons.notes_rounded,
};

Color _statusColor(String? s) => switch (s?.toLowerCase()) {
  'active'      => _DS.green,
  'healthy'     => _DS.green,
  'quarantine'  => _DS.yellow,
  'observation' => _DS.yellow,
  'retired'     => _DS.red,
  'sick'        => _DS.red,
  'treatment'   => _DS.orange,
  'sentinel'    => _DS.pink,
  _             => _DS.labelColor,
};

bool _isMobile(BuildContext context) => MediaQuery.of(context).size.width < 720;

String _fmtDate(String? s) {
  if (s == null || s.isEmpty) return '';
  return s.split('T').first;
}

// ─── Page ─────────────────────────────────────────────────────────────────────
class TankDetailPage extends StatefulWidget {
  final ZebrafishTank tank;
  final VoidCallback? onSaved;
  final List<String> availableRacks;
  const TankDetailPage({super.key, required this.tank, this.onSaved, this.availableRacks = const ['R1']});

  @override
  State<TankDetailPage> createState() => _TankDetailPageState();
}

class _TankDetailPageState extends State<TankDetailPage> {
  Map<String, dynamic> _data = {};
  bool _loading = true;
  bool _saving  = false;
  int  _mobileSection = 0;
  final Set<int> _expanded = {};
  final Map<String, TextEditingController> _ctrl = {};

  // Fish line dropdown
  List<String> _lines = [];
  Map<String, int> _lineIdByName = {};
  bool _loadingLines = true;
  int?    _selectedLineId;
  String? _selectedLineName;

  // Tank position selection
  String _selectedRack = 'R1';
  String _selectedRow  = 'A';
  int    _selectedCol  = 1;
  Set<String> _occupiedTankIds = {};
  bool _loadingPositions = true;

  String get _currentTankId => '$_selectedRack-$_selectedRow$_selectedCol';
  int get _maxCol => _selectedRow == 'A' ? 15 : 10;
  bool _isOccupied(int col) =>
      _occupiedTankIds.contains('$_selectedRack-$_selectedRow$col');
  void _selectFirstAvailable() {
    for (int col = 1; col <= _maxCol; col++) {
      if (!_isOccupied(col)) { setState(() => _selectedCol = col); return; }
    }
  }

  // Fish-line sourced data (read-only in this page)
  String? _lineDateBirth;
  List<String> _lineBreeders = [];

  // ── Quick stat accessors ──────────────────────────────────────────────────
  int get _males   => int.tryParse(_ctrl['fish_stocks_males']?.text   ?? '') ?? (widget.tank.zebraMales   ?? 0);
  int get _females => int.tryParse(_ctrl['fish_stocks_females']?.text ?? '') ?? (widget.tank.zebraFemales ?? 0);
  int get _juvs    => int.tryParse(_ctrl['fish_stocks_juveniles']?.text ?? '') ?? (widget.tank.zebraJuveniles ?? 0);
  int get _total   => _males + _females + _juvs;

  // ── Computed age from fish_line DOB ──────────────────────────────────────
  DateTime? get _dob => _lineDateBirth != null ? DateTime.tryParse(_lineDateBirth!) : null;
  int get _ageDays   => _dob != null ? DateTime.now().difference(_dob!).inDays : -1;
  int get _ageMonths => _ageDays >= 0 ? (_ageDays / 30.44).floor() : -1;
  String get _maturityLabel {
    if (_ageDays < 0) return '—';
    if (_ageDays < 30) return 'Larvae';
    if (_ageDays < 90) return 'Juveniles';
    return 'Adults';
  }

  @override
  void initState() {
    super.initState();
    final tid = widget.tank.zebraTankId;
    final parts = tid.split('-');
    _selectedRack = parts.isNotEmpty ? parts[0] : 'R1';
    final rowPart = parts.length > 1 ? parts[1] : 'A1';
    _selectedRow  = rowPart.isNotEmpty ? rowPart.substring(0, 1) : 'A';
    _selectedCol  = rowPart.length > 1 ? (int.tryParse(rowPart.substring(1)) ?? 1) : 1;
    _expanded.addAll(List.generate(_groups.length, (i) => i));
    _prefill();
    _load();
    _fetchLines();
    _fetchOccupiedPositions();
  }

  Future<void> _fetchLines() async {
    try {
      final rows = (await Supabase.instance.client
          .from('fish_lines')
          .select('fish_line_id, fish_line_name')
          .order('fish_line_name') as List<dynamic>)
          .cast<Map<String, dynamic>>();
      if (!mounted) return;
      final names = rows.map((r) => r['fish_line_name'] as String).toList();
      final idMap  = { for (final r in rows) r['fish_line_name'] as String: r['fish_line_id'] as int };
      final current = widget.tank.zebraLine;
      if (current != null && !names.contains(current)) names.insert(0, current);
      setState(() {
        _lines         = names;
        _lineIdByName  = idMap;
        _loadingLines  = false;
        // If _load() already finished and ctrl has the line name, sync it now
        final ctrlText = _ctrl['fish_stocks_line']?.text ?? '';
        if (_selectedLineName == null && names.contains(ctrlText)) {
          _selectedLineName = ctrlText;
          _selectedLineId   = idMap[ctrlText];
        }
      });
    } catch (_) {
      if (mounted) setState(() => _loadingLines = false);
    }
  }

  Future<void> _fetchLineDataByName(String name) async {
    try {
      final lineRow = await Supabase.instance.client
          .from('fish_lines')
          .select('fish_line_id, fish_line_date_birth, fish_line_breeders')
          .eq('fish_line_name', name)
          .maybeSingle();
      if (!mounted || lineRow == null) return;
      final breederStr = lineRow['fish_line_breeders'] as String? ?? '';
      setState(() {
        _selectedLineId = lineRow['fish_line_id'] as int?;
        _lineDateBirth  = lineRow['fish_line_date_birth'] as String?;
        _lineBreeders   = breederStr.isEmpty
            ? []
            : breederStr.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      });
    } catch (_) {}
  }

  Future<void> _fetchOccupiedPositions() async {
    try {
      final rows = await Supabase.instance.client
          .from('fish_stocks')
          .select('fish_stocks_tank_id') as List<dynamic>;
      if (!mounted) return;
      final ids = rows
          .map((r) => r['fish_stocks_tank_id'] as String)
          .where((id) => id != widget.tank.zebraTankId)
          .toSet();
      setState(() { _occupiedTankIds = ids; _loadingPositions = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingPositions = false);
    }
  }

  void _prefill() {
    final t = widget.tank;
    _data = {
      'fish_stocks_tank_id':          t.zebraTankId,
      'fish_stocks_rack':             t.zebraRack,
      'fish_stocks_row':              t.zebraRow,
      'fish_stocks_column':           t.zebraColumn,
      'fish_stocks_volume_l':         t.zebraVolumeL,
      'fish_stocks_capacity':         t.zebraCapacity,
      'fish_stocks_tank_type':        t.zebraTankType,
      'fish_stocks_sentinel_status':  t.zebraTankType == 'sentinel' ? 'sentinel' : null,
      'fish_stocks_line':             t.zebraLine,
      'fish_stocks_males':            t.zebraMales,
      'fish_stocks_females':          t.zebraFemales,
      'fish_stocks_juveniles':        t.zebraJuveniles,
      'fish_stocks_status':           t.zebraStatus,
      'fish_stocks_health_status':    t.zebraHealthStatus,
      'fish_stocks_treatment':        t.zebraTreatment,
      'fish_stocks_food_type':        t.zebraFoodType,
      'fish_stocks_food_source':      t.zebraFoodSource,
      'fish_stocks_food_amount':      t.zebraFoodAmount,
      'fish_stocks_feeding_schedule': t.zebraFeedingSchedule,
      'fish_stocks_temperature_c':    t.zebraTemperatureC,
      'fish_stocks_ph':               t.zebraPh,
      'fish_stocks_conductivity':     t.zebraConductivity,
      'fish_stocks_light_cycle':      t.zebraLightCycle,
      'fish_stocks_responsible':      t.zebraResponsible,
      'fish_stocks_experiment_id':    t.zebraExperimentId,
      'fish_stocks_notes':            t.zebraNotes,
    };
    _syncCtrls();
  }

  void _syncCtrls() {
    for (final g in _groups) {
      for (final f in g.fields) {
        if (_computedKeys.contains(f.key)) continue;
        if (f.key == 'fish_stocks_breeders') continue;
        final raw  = _data[f.key];
        final text = raw != null ? _fmtDate(raw.toString()) : '';
        if (_ctrl.containsKey(f.key)) {
          _ctrl[f.key]!.text = text;
        } else {
          _ctrl[f.key] = TextEditingController(text: text);
        }
      }
    }
  }

  @override
  void dispose() {
    for (final c in _ctrl.values) c.dispose();
    super.dispose();
  }

  // ── Supabase ──────────────────────────────────────────────────────────────
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await Supabase.instance.client
          .from('fish_stocks')
          .select()
          .eq('fish_stocks_tank_id', widget.tank.zebraTankId)
          .maybeSingle();
      if (res != null) {
        _data = Map<String, dynamic>.from(res);
        _syncCtrls();
        // Prefer FK lookup, fall back to name
        final lineId   = res['fish_stocks_line_id'] as int?;
        final lineName = res['fish_stocks_line'] as String?;
        Map<String, dynamic>? lineRow;
        if (lineId != null) {
          lineRow = await Supabase.instance.client
              .from('fish_lines')
              .select('fish_line_id, fish_line_name, fish_line_date_birth, fish_line_breeders')
              .eq('fish_line_id', lineId)
              .maybeSingle();
        } else if (lineName != null && lineName.isNotEmpty) {
          lineRow = await Supabase.instance.client
              .from('fish_lines')
              .select('fish_line_id, fish_line_name, fish_line_date_birth, fish_line_breeders')
              .eq('fish_line_name', lineName)
              .maybeSingle();
        }
        if (lineRow != null) {
          _selectedLineId   = lineRow['fish_line_id'] as int?;
          _selectedLineName = lineRow['fish_line_name'] as String?;
          _lineDateBirth    = lineRow['fish_line_date_birth'] as String?;
          final breederStr = lineRow['fish_line_breeders'] as String? ?? '';
          _lineBreeders = breederStr.isEmpty
              ? []
              : breederStr.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
        }
      }
    } catch (e) {
      _snack('Error loading: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final payload = <String, dynamic>{
        'fish_stocks_tank_id': _currentTankId,
      };
      for (final g in _groups) {
        for (final f in g.fields) {
          if (_computedKeys.contains(f.key)) continue;
          if (f.key == 'fish_stocks_tank_id') continue; // handled above
          if (f.key == '_line_breeders') continue; // fish_line field, not saved here
          final v = _ctrl[f.key]?.text.trim() ?? '';
          payload[f.key] = v.isEmpty ? null : v;
        }
      }
      // Sync derived position columns and line FK
      payload['fish_stocks_rack']    = _selectedRack;
      payload['fish_stocks_row']     = _selectedRow;
      payload['fish_stocks_column']  = '$_selectedCol';
      payload['fish_stocks_line_id'] = _selectedLineId;

      final client = Supabase.instance.client;
      if (_currentTankId != widget.tank.zebraTankId) {
        // Moving to a different position: UPDATE by original ID
        await client.from('fish_stocks').update(payload)
            .eq('fish_stocks_tank_id', widget.tank.zebraTankId);
      } else {
        await client.from('fish_stocks')
            .upsert(payload, onConflict: 'fish_stocks_tank_id');
      }
      widget.onSaved?.call();
      _snack('Saved successfully.');
    } catch (e) {
      _snack('Save error: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final tankId = widget.tank.zebraTankId;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.delete_forever_rounded,
            color: Color(0xFFDC2626), size: 40),
        title: Text('Delete $tankId?',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: const TextStyle(fontSize: 14, color: Color(0xFF475569), height: 1.5),
            children: [
              const TextSpan(text: 'This will permanently remove all data for\n'),
              TextSpan(text: tankId,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              const TextSpan(text: '.\n\nThis action cannot be undone.'),
            ],
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          const SizedBox(width: 8),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: _DS.red),
            icon: const Icon(Icons.delete_forever_rounded, size: 16),
            label: const Text('Delete'),
            onPressed: () => Navigator.pop(context, true)),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await Supabase.instance.client
          .from('fish_stocks')
          .delete()
          .eq('fish_stocks_tank_id', tankId);
      widget.onSaved?.call();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _snack('Delete error: $e');
    }
  }

  // ── CalendarDatePicker dialog ─────────────────────────────────────────────
  Future<void> _pickDate(String key, String title) async {
    final cur = DateTime.tryParse(_ctrl[key]?.text ?? '') ?? DateTime.now();
    DateTime selected = cur;
    final result = await showDialog<DateTime>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          content: SizedBox(
            width: 300,
            child: CalendarDatePicker(
              initialDate: selected,
              firstDate: DateTime(2000),
              lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
              onDateChanged: (d) { set(() => selected = d); },
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: _DS.accent, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, selected),
              child: const Text('OK')),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;
    final s = '${result.year}-'
        '${result.month.toString().padLeft(2, '0')}-'
        '${result.day.toString().padLeft(2, '0')}';
    setState(() => _ctrl[key]?.text = s);
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) =>
      _isMobile(context) ? _buildMobile() : _buildDesktop();

  // ═══════════════════════════════════════════════════════════════════════════
  // MOBILE
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildMobile() => Scaffold(
    backgroundColor: _DS.scaffoldBg,
    appBar: _buildMobileAppBar(),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : Column(children: [
            _buildStatStrip(),
            _buildMobileSectionBar(),
            Expanded(child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 100),
              child: Column(
                children: _groups[_mobileSection].fields
                    .map((f) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildField(f)))
                    .toList()),
            )),
          ]),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _saving ? null : _save,
      backgroundColor: _DS.accent,
      foregroundColor: Colors.white,
      icon: _saving
          ? const SizedBox(width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.save_rounded, size: 20),
      label: Text(_saving ? 'Saving\u2026' : 'Save',
          style: const TextStyle(fontWeight: FontWeight.w600))),
  );

  PreferredSizeWidget _buildMobileAppBar() => AppBar(
    backgroundColor: _DS.headerBg,
    foregroundColor: Colors.white,
    elevation: 0,
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_currentTankId,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        if (widget.tank.zebraLine != null)
          Text(widget.tank.zebraLine!,
              style: const TextStyle(
                  fontSize: 11, color: Colors.white60,
                  fontStyle: FontStyle.italic)),
      ],
    ),
    actions: [
      PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, color: Colors.white70),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        onSelected: (v) { if (v == 'delete') _delete(); },
        itemBuilder: (_) => [
          const PopupMenuItem(
            value: 'delete',
            child: ListTile(
              dense: true,
              leading: Icon(Icons.delete_outline_rounded,
                  color: Color(0xFFDC2626), size: 18),
              title: Text('Delete tank',
                  style: TextStyle(color: Color(0xFFDC2626), fontSize: 13)),
            )),
        ]),
    ],
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // DESKTOP
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildDesktop() => Scaffold(
    backgroundColor: _DS.scaffoldBg,
    appBar: _buildDesktopAppBar(),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _buildDesktopBody(),
  );

  PreferredSizeWidget _buildDesktopAppBar() {
    final status = _ctrl['fish_stocks_status']?.text
        ?? widget.tank.zebraStatus ?? '';
    return AppBar(
      backgroundColor: _DS.headerBg,
      foregroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, size: 16, color: Colors.white70),
        onPressed: () => Navigator.pop(context)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Text(_currentTankId,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(width: 10),
            if (status.isNotEmpty) _statusPill(status),
            const SizedBox(width: 6),
            Text(widget.tank.volumeLabel,
                style: const TextStyle(fontSize: 10, color: Colors.white38)),
          ]),
          if (widget.tank.zebraLine != null)
            Text(widget.tank.zebraLine!,
                style: const TextStyle(
                    fontSize: 11, color: Colors.white60,
                    fontStyle: FontStyle.italic)),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded,
              color: Color(0xFFFC8181), size: 20),
          tooltip: 'Delete tank',
          onPressed: _delete),
        Padding(
          padding: const EdgeInsets.only(right: 12, left: 4),
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: _DS.accent,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
            icon: _saving
                ? const SizedBox(width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_rounded, size: 16),
            label: const Text('Save', style: TextStyle(fontSize: 13)))),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: Colors.white12)),
    );
  }

  Widget _buildDesktopBody() => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // ── Sidebar ──────────────────────────────────────────────────────────
      SizedBox(
        width: 240,
        child: Container(
          color: Colors.white,
          child: Column(children: [
            const Divider(height: 1),
            if (_selectedLineName != null) _buildLineLink(),
            _buildSidebarStats(),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _groups.length,
                itemBuilder: (ctx, i) {
                  final g     = _groups[i];
                  final isExp = _expanded.contains(i);
                  return ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                    leading: Icon(_sectionIcon(g.icon), size: 18,
                        color: isExp ? _DS.accent : const Color(0xFF94A3B8)),
                    title: Text(g.title,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isExp ? FontWeight.w600 : FontWeight.normal,
                          color: isExp ? _DS.accent : const Color(0xFF475569))),
                    trailing: Icon(
                        isExp
                            ? Icons.keyboard_arrow_down_rounded
                            : Icons.keyboard_arrow_right_rounded,
                        size: 16,
                        color: isExp ? _DS.accent : const Color(0xFF94A3B8)),
                    onTap: () => setState(() {
                      if (isExp) { _expanded.remove(i); } else { _expanded.add(i); }
                    }),
                    selected: isExp,
                    selectedTileColor: _DS.accent.withValues(alpha: 0.06),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  );
                },
              ),
            ),
          ]),
        ),
      ),
      // ── Main content ──────────────────────────────────────────────────────
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...List.generate(_groups.length, (i) {
                if (!_expanded.contains(i)) return const SizedBox.shrink();
                final g = _groups[i];
                return _buildSection(i, g.title, g.icon, g.fields);
              }),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    ],
  );

  // ── Sidebar stats ─────────────────────────────────────────────────────────
  Future<void> _openLinePage() async {
    if (_selectedLineId == null && _selectedLineName == null) return;
    try {
      final query = Supabase.instance.client.from('fish_lines').select();
      final row = _selectedLineId != null
          ? await query.eq('fish_line_id', _selectedLineId!).maybeSingle()
          : await query.eq('fish_line_name', _selectedLineName!).maybeSingle();
      if (row == null || !mounted) return;
      final line = FishLine.fromMap(row);
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => FishLineDetailPage(fishLine: line)));
    } catch (_) {}
  }

  Widget _buildLineLink() => InkWell(
    onTap: _openLinePage,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFFEFF6FF),
        border: Border(bottom: BorderSide(color: Color(0xFFBFDBFE)))),
      child: Row(children: [
        const Icon(Icons.biotech_outlined, size: 14, color: _DS.accent),
        const SizedBox(width: 8),
        Expanded(child: Text(
          _selectedLineName!,
          style: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600,
            color: _DS.accent),
          overflow: TextOverflow.ellipsis)),
        const Icon(Icons.open_in_new_rounded, size: 13, color: _DS.accent),
      ]),
    ),
  );

  Widget _buildSidebarStats() => Container(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
    color: _DS.sectionBg,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('OVERVIEW',
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
              color: _DS.labelColor, letterSpacing: 0.8)),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _sidebarStat('\u2642', '$_males', _DS.accent)),
        const SizedBox(width: 6),
        Expanded(child: _sidebarStat('\u2640', '$_females', _DS.accent)),
        const SizedBox(width: 6),
        Expanded(child: _sidebarStat('J', '$_juvs', _DS.yellow)),
      ]),
      const SizedBox(height: 6),
      Row(children: [
        Expanded(child: _sidebarStat('TOTAL', '$_total', _DS.green)),
        const SizedBox(width: 6),
        Expanded(child: _sidebarStat('VOL', widget.tank.volumeLabel, _DS.labelColor)),
      ]),
      if (_ageDays >= 0) ...[
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: _sidebarStat('AGE', '$_ageDays d', _DS.orange)),
          const SizedBox(width: 6),
          Expanded(child: _sidebarStat('STAGE', _maturityLabel, _DS.pink)),
        ]),
      ],
      if ((_ctrl['fish_stocks_temperature_c']?.text ?? '').isNotEmpty ||
          (_ctrl['fish_stocks_ph']?.text ?? '').isNotEmpty) ...[
        const SizedBox(height: 6),
        Row(children: [
          if ((_ctrl['fish_stocks_temperature_c']?.text ?? '').isNotEmpty)
            Expanded(child: _sidebarStat(
                'TEMP', '${_ctrl['fish_stocks_temperature_c']!.text}\u00b0C', _DS.orange)),
          if ((_ctrl['fish_stocks_temperature_c']?.text ?? '').isNotEmpty &&
              (_ctrl['fish_stocks_ph']?.text ?? '').isNotEmpty)
            const SizedBox(width: 6),
          if ((_ctrl['fish_stocks_ph']?.text ?? '').isNotEmpty)
            Expanded(child: _sidebarStat(
                'pH', _ctrl['fish_stocks_ph']!.text, const Color(0xFF6366F1))),
        ]),
      ],
    ]),
  );

  Widget _sidebarStat(String label, String value, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(7),
      border: Border.all(color: color.withValues(alpha: 0.18))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Text(label,
          style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700,
              color: color, letterSpacing: 0.5)),
      const SizedBox(height: 2),
      Text(value,
          style: GoogleFonts.jetBrainsMono(
              fontSize: 12, fontWeight: FontWeight.w700, color: _DS.titleColor)),
    ]),
  );

  // ── Stat strip (mobile only) ──────────────────────────────────────────────
  Widget _buildStatStrip() => Container(
    color: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    child: Wrap(spacing: 10, runSpacing: 8, children: [
      _statChip('MALES',     '$_males',   _DS.accent),
      _statChip('FEMALES',   '$_females', _DS.accent),
      _statChip('JUVENILES', '$_juvs',    _DS.yellow),
      _statChip('TOTAL',     '$_total',   _DS.green),
      _statChip('VOLUME',    widget.tank.volumeLabel, _DS.labelColor),
      if (_ageDays >= 0) _statChip('AGE', '$_ageDays d', _DS.orange),
      if ((_ctrl['fish_stocks_temperature_c']?.text ?? '').isNotEmpty)
        _statChip('TEMP',
            '${_ctrl['fish_stocks_temperature_c']!.text}\u00b0C', _DS.orange),
      if ((_ctrl['fish_stocks_ph']?.text ?? '').isNotEmpty)
        _statChip('pH', _ctrl['fish_stocks_ph']!.text, const Color(0xFF6366F1)),
    ]),
  );

  Widget _statChip(String label, String value, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.2))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(label,
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
              color: color, letterSpacing: 0.6)),
      const SizedBox(width: 6),
      Text(value,
          style: GoogleFonts.jetBrainsMono(
              fontSize: 13, fontWeight: FontWeight.w700, color: _DS.titleColor)),
    ]),
  );

  // ── Mobile section tab bar ────────────────────────────────────────────────
  Widget _buildMobileSectionBar() => Container(
    color: Colors.white,
    height: 48,
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      itemCount: _groups.length,
      itemBuilder: (ctx, i) {
        final isActive = _mobileSection == i;
        return GestureDetector(
          onTap: () => setState(() => _mobileSection = i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isActive ? _DS.accent : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: isActive ? _DS.accent : const Color(0xFFE2E8F0))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(_sectionIcon(_groups[i].icon), size: 13,
                  color: isActive ? Colors.white : const Color(0xFF64748B)),
              const SizedBox(width: 5),
              Text(_groups[i].title,
                  style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600,
                    color: isActive ? Colors.white : const Color(0xFF475569))),
            ]),
          ),
        );
      },
    ),
  );

  // ── Identity section: picker left, other fields right (fish_line first) ──
  Widget _buildIdentityLayout(List<_Field> fields) {
    final posField    = fields.where((f) => f.key == 'fish_stocks_tank_id').firstOrNull;
    // fish_stocks_line first, then the rest (excluding tank_id)
    final lineField   = fields.where((f) => f.key == 'fish_stocks_line').firstOrNull;
    final otherFields = fields.where((f) =>
        f.key != 'fish_stocks_tank_id' && f.key != 'fish_stocks_line').toList();
    final rightFields = [
      if (lineField != null) lineField,
      ...otherFields,
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (posField != null) SizedBox(width: 300, child: _buildField(posField)),
        if (posField != null) const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: rightFields.map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _buildField(f),
            )).toList(),
          ),
        ),
      ],
    );
  }

  // ── Desktop section card ──────────────────────────────────────────────────
  Widget _buildSection(int idx, String title, String iconKey, List<_Field> fields) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _DS.cardBorder),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6, offset: const Offset(0, 2)),
          ]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Section header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: _DS.sectionBg,
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12), topRight: Radius.circular(12)),
              border: const Border(bottom: BorderSide(color: _DS.cardBorder))),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _DS.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8)),
                child: Icon(_sectionIcon(iconKey), size: 16, color: _DS.accent)),
              const SizedBox(width: 10),
              Text(title.toUpperCase(), style: _DS.sectionTitle),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() {
                  if (_expanded.contains(idx)) { _expanded.remove(idx); }
                  else { _expanded.add(idx); }
                }),
                child: Icon(Icons.keyboard_arrow_up_rounded,
                    size: 20, color: const Color(0xFF94A3B8))),
            ]),
          ),
          // Fields
          Padding(
            padding: const EdgeInsets.all(20),
            child: idx == 0
                ? _buildIdentityLayout(fields)
                : LayoutBuilder(builder: (ctx, box) {
                    final cols = box.maxWidth > 800 ? 3 : box.maxWidth > 520 ? 2 : 1;
                    final fieldW = (box.maxWidth - (cols - 1) * 16) / cols;
                    return Wrap(
                      spacing: 16, runSpacing: 16,
                      children: fields.map((f) => SizedBox(
                        width: f.key == 'fish_stocks_breeders' || f.lines > 1
                            ? double.infinity
                            : fieldW,
                        child: _buildField(f))).toList(),
                    );
                  }),
          ),
        ]),
      ),
    );

  // ── Individual field dispatcher ───────────────────────────────────────────
  Widget _buildField(_Field f) {
    // Computed (read-only, derived from DOB)
    if (_computedKeys.contains(f.key)) return _buildComputedField(f);

    // Parent lines (read-only, from fish_line)
    if (f.key == '_line_breeders') return _buildLineBreedersDisplay();

    // Tank position dropdown
    if (f.key == 'fish_stocks_tank_id') return _buildTankIdField();

    final ctrl = _ctrl[f.key] ??= TextEditingController(
        text: _data[f.key]?.toString() ?? '');

    // Fish line dropdown
    if (f.key == 'fish_stocks_line') {
      if (_loadingLines) {
        return InputDecorator(
          decoration: _dec(f.label),
          child: const LinearProgressIndicator());
      }
      final currentVal = (_selectedLineName != null && _lines.contains(_selectedLineName))
          ? _selectedLineName : null;
      return InputDecorator(
        decoration: _dec(f.label),
        child: DropdownButton<String>(
          value: currentVal,
          isExpanded: true,
          underline: const SizedBox.shrink(),
          isDense: true,
          style: const TextStyle(fontSize: 13, color: _DS.titleColor),
          hint: const Text('\u2014 select line \u2014',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
          items: _lines.map((l) => DropdownMenuItem(
            value: l,
            child: Text(l, style: const TextStyle(fontSize: 13, color: _DS.titleColor)))).toList(),
          onChanged: (v) {
            setState(() {
              ctrl.text         = v ?? '';
              _selectedLineName = v;
              _selectedLineId   = v != null ? _lineIdByName[v] : null;
              if (v == null || v.isEmpty) {
                _lineDateBirth = null;
                _lineBreeders  = [];
              }
            });
            if (v != null && v.isNotEmpty) _fetchLineDataByName(v);
          },
        ),
      );
    }

    // Volume dropdown (normalise DB numeric to canonical string)
    if (f.key == 'fish_stocks_volume_l') {
      const opts = ['1.1', '2.4', '3.5', '8.0'];
      final curDbl = double.tryParse(ctrl.text);
      final val = opts.firstWhere(
        (o) => (double.tryParse(o) ?? -1) == curDbl,
        orElse: () => '',
      );
      return DropdownButtonFormField<String>(
        initialValue: val.isEmpty ? null : val,
        decoration: _dec(f.label),
        style: GoogleFonts.jetBrainsMono(fontSize: 13, color: _DS.titleColor),
        hint: const Text('— select —',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
        items: opts.map((v) => DropdownMenuItem(
          value: v,
          child: Text(v, style: GoogleFonts.jetBrainsMono(
              fontSize: 13, color: _DS.titleColor)))).toList(),
        onChanged: (v) => setState(() => ctrl.text = v ?? ''),
      );
    }

    // Constrained dropdown
    if (_dropdowns.containsKey(f.key)) {
      final opts = _dropdowns[f.key]!;
      final val  = opts.contains(ctrl.text) ? ctrl.text : null;
      return DropdownButtonFormField<String>(
        initialValue: val,
        decoration: _dec(f.label),
        style: const TextStyle(fontSize: 13, color: _DS.titleColor),
        items: [
          const DropdownMenuItem<String>(
            value: null,
            child: Text('\u2014 not set \u2014',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13))),
          ...opts.map((v) => DropdownMenuItem(
            value: v,
            child: Row(children: [
              if (_statusColor(v) != _DS.labelColor)
                Container(width: 8, height: 8,
                  margin: const EdgeInsets.only(right: 7),
                  decoration: BoxDecoration(color: _statusColor(v), shape: BoxShape.circle)),
              Text(v, style: const TextStyle(color: _DS.titleColor, fontSize: 13)),
            ]))),
        ],
        onChanged: (v) => setState(() => ctrl.text = v ?? ''),
      );
    }

    // Date picker
    if (_datePickers.contains(f.key)) {
      return TextFormField(
        controller: ctrl,
        readOnly: true,
        onTap: () => _pickDate(f.key, f.label),
        style: const TextStyle(fontSize: 13, color: _DS.titleColor),
        decoration: _dec(f.label).copyWith(
          suffixIcon: const Icon(Icons.calendar_today_outlined,
              size: 16, color: _DS.labelColor)),
      );
    }

    // Standard text / multiline
    return TextFormField(
      controller: ctrl,
      maxLines: f.lines,
      style: const TextStyle(fontSize: 13, color: _DS.titleColor),
      decoration: _dec(f.label).copyWith(
        contentPadding: f.lines > 1
            ? const EdgeInsets.all(12)
            : const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
    );
  }

  // ── Tank position visual picker ───────────────────────────────────────────
  Widget _buildTankIdField() {
    if (_loadingPositions) {
      return InputDecorator(
        decoration: _dec('Tank Position'),
        child: const LinearProgressIndicator());
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _DS.sectionBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _DS.cardBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Label
        const Text('Tank Position',
            style: TextStyle(fontSize: 11, color: _DS.labelColor, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        // Rack
        Row(children: [
          const Text('Rack:', style: TextStyle(fontSize: 11, color: _DS.labelColor, fontWeight: FontWeight.w700)),
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
                      ? _DS.accent.withValues(alpha: 0.1) : Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _selectedRack == rack ? _DS.accent : _DS.cardBorder,
                    width: _selectedRack == rack ? 1.5 : 1)),
                child: Center(child: Text(rack, style: GoogleFonts.jetBrainsMono(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: _selectedRack == rack ? _DS.accent : _DS.labelColor))),
              ),
            ),
          )),
        ]),
        const SizedBox(height: 10),
        // Row
        Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 0, children: [
          const Padding(
            padding: EdgeInsets.only(right: 10),
            child: Text('Row:', style: TextStyle(fontSize: 11, color: _DS.labelColor, fontWeight: FontWeight.w700))),
          ..._detailRowLabels.map((r) => Padding(
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
                      ? _DS.accent.withValues(alpha: 0.1) : Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _selectedRow == r ? _DS.accent : _DS.cardBorder,
                    width: _selectedRow == r ? 1.5 : 1)),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(r, style: GoogleFonts.jetBrainsMono(
                    fontSize: 12, fontWeight: FontWeight.w700,
                    color: _selectedRow == r ? _DS.accent : _DS.labelColor)),
                  Text(r == 'A' ? '1.1L' : '3.5L',
                    style: GoogleFonts.jetBrainsMono(fontSize: 8,
                      color: _selectedRow == r
                          ? _DS.accent.withValues(alpha: 0.7)
                          : _DS.labelColor.withValues(alpha: 0.6))),
                ]),
              ),
            ),
          )),
          const SizedBox(width: 8),
          Text(_selectedRow == 'A' ? '(15 × 1.1 L)' : '(10 × 3.5 L)',
              style: GoogleFonts.jetBrainsMono(fontSize: 10, color: _DS.labelColor)),
        ]),
        const SizedBox(height: 10),
        // Column
        const Text('Column:', style: TextStyle(fontSize: 11, color: _DS.labelColor, fontWeight: FontWeight.w700)),
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
                      ? _DS.red.withValues(alpha: 0.08)
                      : (sel ? _DS.accent.withValues(alpha: 0.12) : Colors.white),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: occupied ? _DS.red.withValues(alpha: 0.4)
                        : (sel ? _DS.accent : _DS.cardBorder),
                    width: sel ? 1.5 : 1)),
                child: Center(child: Text('$col', style: GoogleFonts.jetBrainsMono(
                  fontSize: 11, fontWeight: FontWeight.w600,
                  color: occupied ? _DS.red
                      : (sel ? _DS.accent : _DS.labelColor)))),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Row(children: [
          const Icon(Icons.tag_rounded, size: 12, color: _DS.labelColor),
          const SizedBox(width: 4),
          Text('Selected: $_currentTankId',
              style: GoogleFonts.jetBrainsMono(
                  fontSize: 12, fontWeight: FontWeight.w700, color: _DS.titleColor)),
        ]),
      ]),
    );
  }

  // ── Computed / fish_line-sourced read-only fields ────────────────────────
  Widget _buildComputedField(_Field f) {
    final hasAge = _ageDays >= 0;
    final value = switch (f.key) {
      '_line_date_birth' => _lineDateBirth ?? '—',
      '_age_days'        => hasAge ? '$_ageDays days' : '—',
      '_age_months'      => hasAge ? '$_ageMonths months' : '—',
      '_maturity'        => _maturityLabel,
      _                  => '—',
    };
    final hasValue = value != '—';
    final valueColor = switch (f.key) {
      '_line_date_birth'                             => _DS.accent,
      '_maturity' when _maturityLabel == 'Larvae'    => _DS.yellow,
      '_maturity' when _maturityLabel == 'Juveniles' => _DS.orange,
      '_maturity' when _maturityLabel == 'Adults'    => _DS.green,
      _                                              => _DS.accent,
    };
    return InputDecorator(
      decoration: _dec(f.label).copyWith(
        fillColor: const Color(0xFFF0F4F8),
        suffixIcon: const Icon(Icons.auto_awesome_outlined,
            size: 14, color: _DS.labelColor)),
      child: Text(value,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: hasValue ? valueColor : _DS.labelColor)),
    );
  }

  // ── Parent lines (read-only, sourced from fish_line record) ─────────────
  Widget _buildLineBreedersDisplay() {
    return InputDecorator(
      decoration: _dec('Parent Lines (from fish line)').copyWith(
        fillColor: const Color(0xFFF0F4F8),
        helperText: 'Edit in the Fish Lines record',
        helperStyle: const TextStyle(fontSize: 10, color: _DS.labelColor),
        suffixIcon: const Icon(Icons.link_rounded, size: 15, color: _DS.labelColor)),
      child: _lineBreeders.isEmpty
          ? const Text('—', style: TextStyle(color: _DS.labelColor, fontSize: 13))
          : Wrap(
              spacing: 6, runSpacing: 4,
              children: _lineBreeders.map((b) => Chip(
                label: Text(b,
                    style: const TextStyle(fontSize: 11, color: _DS.titleColor)),
                backgroundColor: _DS.accent.withValues(alpha: 0.08),
                side: BorderSide(color: _DS.accent.withValues(alpha: 0.3)),
                visualDensity: VisualDensity.compact,
              )).toList(),
            ),
    );
  }

  // ── Shared decoration ─────────────────────────────────────────────────────
  InputDecoration _dec(String label) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(fontSize: 12, color: _DS.labelColor),
    isDense: true,
    filled: true,
    fillColor: const Color(0xFFFAFAFC),
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _DS.cardBorder)),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _DS.cardBorder)),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _DS.accent, width: 1.5)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  );

  Widget _statusPill(String s) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: _statusColor(s).withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _statusColor(s).withValues(alpha: 0.5))),
    child: Text(s,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
            color: _statusColor(s))),
  );
}
