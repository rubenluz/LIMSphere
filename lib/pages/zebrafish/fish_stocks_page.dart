import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/models/connection_model.dart';
import 'shared_widgets.dart';
import 'stock_detail_page.dart';

// Design tokens
class _DS {
  static const Color bg       = Color(0xFF0F172A);
  static const Color surface  = Color(0xFF1E293B);
  static const Color surface2 = Color(0xFF1A2438);
  static const Color surface3 = Color(0xFF243044);
  static const Color border   = Color(0xFF334155);
  static const Color border2  = Color(0xFF2D3F55);
  static const Color accent   = Color(0xFF38BDF8);
  static const Color green    = Color(0xFF22C55E);
  static const Color yellow   = Color(0xFFEAB308);
  static const Color red      = Color(0xFFEF4444);
  static const Color purple   = Color(0xFFA855F7);
  static const Color textPrimary   = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFFB8C7DA);
  static const Color textMuted     = Color(0xFF64748B);
}

// ZebTec rack layout constants
// Row A (index 0): 15 positions × 1.5 L  (top shelf)
// Rows B–E (index 1–4): 10 positions × 3.5 L each
const _rowLabels = ['A', 'B', 'C', 'D', 'E'];
const _rowACount  = 15;  // 1.5 L
const _rowBECount = 10;  // 3.5 L

/// Generate the canonical ZebTec tank ID list: A1–A15, B1–B10, … E1–E10
List<String> get _allTankPositions {
  final ids = <String>[];
  for (int i = 0; i < _rowACount; i++) ids.add('A${i + 1}');
  for (int r = 1; r < _rowLabels.length; r++) {
    for (int c = 1; c <= _rowBECount; c++) ids.add('${_rowLabels[r]}$c');
  }
  return ids;
}

class FishStocksPage extends StatefulWidget {
  const FishStocksPage({super.key});

  @override
  State<FishStocksPage> createState() => _FishStocksPageState();
}

class _FishStocksPageState extends State<FishStocksPage> {
  List<FishStock> _stocks = [];
  List<FishStock> _filtered = [];
  final _searchCtrl = TextEditingController();
  bool _loading = true;
  String? _loadError;
  String? _filterStatus;
  String? _filterHealth;
  String? _filterLine;
  String _sortKey = 'stockId';
  bool _sortAsc = true;
  int? _editingId;

  final _vertCtrl         = ScrollController();
  final _horizCtrl        = ScrollController();
  final _headerHorizCtrl  = ScrollController();

  static const _cols = [
    ('stockId',     'Stock ID',   100.0, true),
    ('line',        'Line',       140.0, false),
    ('genotype',    'Genotype',    90.0, false),
    ('ageMonths',   'Age (mo)',    70.0, false),
    ('males',       '♂',           50.0, false),
    ('females',     '♀',           50.0, false),
    ('juveniles',   'Juv.',        60.0, false),
    ('tankId',      'Tank',       110.0, true),
    ('responsible', 'Responsible',130.0, false),
    ('status',      'Status',     110.0, false),
    ('health',      'Health',     110.0, false),
    ('experiment',  'Experiment', 140.0, true),
    ('notes',       'Notes',      160.0, false),
  ];

  @override
  void initState() {
    super.initState();
    _loadStocks();
    _searchCtrl.addListener(_applyFilters);
    _horizCtrl.addListener(() {
      if (_headerHorizCtrl.hasClients &&
          _headerHorizCtrl.offset != _horizCtrl.offset) {
        _headerHorizCtrl.jumpTo(_horizCtrl.offset);
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _vertCtrl.dispose();
    _horizCtrl.dispose();
    _headerHorizCtrl.dispose();
    super.dispose();
  }

  int _asInt(dynamic v, {int fallback = 0}) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? fallback;
  }

  String _normalizedTankId(Map<String, dynamic> row) {
    final raw = (row['fish_tank_id']?.toString() ?? '').trim().toUpperCase();
    final rack = (row['fish_rack']?.toString() ?? '').trim().toUpperCase();
    final dbRow = (row['fish_row']?.toString() ?? '').trim().toUpperCase();
    final dbCol = (row['fish_column']?.toString() ?? '').trim();

    if (raw.contains('-')) return raw;
    if (RegExp(r'^[A-E]\d{1,2}$').hasMatch(raw)) {
      return '${rack.isNotEmpty ? rack : 'R1'}-$raw';
    }
    if (dbRow.isNotEmpty && dbCol.isNotEmpty) {
      return '${rack.isNotEmpty ? rack : 'R1'}-$dbRow$dbCol';
    }
    return raw.isEmpty ? '—' : raw;
  }

  FishStock _stockFromRow(Map<String, dynamic> row) {
    final fishId = row['fish_id'];
    final line = (row['fish_line']?.toString() ?? '').trim();
    final tankId = _normalizedTankId(row);

    return FishStock(
      id: fishId is int ? fishId : int.tryParse(fishId?.toString() ?? ''),
      stockId: fishId?.toString() ?? '—',
      line: line.isEmpty ? 'unknown' : line,
      genotype: (row['fish_genotype']?.toString() ?? 'unknown'),
      ageMonths: (_asInt(row['fish_age_days']) / 30).floor(),
      males: _asInt(row['fish_males']),
      females: _asInt(row['fish_females']),
      juveniles: _asInt(row['fish_juveniles']),
      tankId: tankId,
      responsible: row['fish_responsible']?.toString() ?? '',
      status: row['fish_status']?.toString() ?? 'active',
      health: row['fish_health_status']?.toString() ?? 'healthy',
      experiment: row['fish_experiment_id']?.toString(),
      notes: row['fish_notes']?.toString(),
      created: row['fish_created_at'] != null
          ? DateTime.tryParse(row['fish_created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Future<void> _loadStocks() async {
    try {
      setState(() {
        _loading = true;
        _loadError = null;
      });

      final rows = (await Supabase.instance.client
          .from('fish_stocks')
          .select()
          .order('fish_rack')
          .order('fish_row')
          .order('fish_column')
          .order('fish_id') as List<dynamic>)
          .cast<Map<String, dynamic>>();

      _stocks = rows.map(_stockFromRow).toList();
      _applyFilters();

      if (mounted) {
        setState(() => _loading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = e.toString();
        });
      }
    }
  }

  void _applyFilters() {
    var d = _stocks.toList();
    final q = _searchCtrl.text.toLowerCase();
    if (q.isNotEmpty) {
      d = d.where((r) =>
        r.stockId.toLowerCase().contains(q) ||
        r.line.toLowerCase().contains(q) ||
        r.tankId.toLowerCase().contains(q) ||
        r.responsible.toLowerCase().contains(q) ||
        (r.experiment?.toLowerCase().contains(q) ?? false)
      ).toList();
    }
    if (_filterStatus != null) d = d.where((r) => r.status == _filterStatus).toList();
    if (_filterHealth != null) d = d.where((r) => r.health == _filterHealth).toList();
    if (_filterLine   != null) d = d.where((r) => r.line   == _filterLine).toList();
    _applySortToList(d);
    setState(() => _filtered = d);
  }

  void _applySortToList(List<FishStock> d) {
    d.sort((a, b) {
      dynamic av, bv;
      switch (_sortKey) {
        case 'stockId':     av = a.stockId;     bv = b.stockId; break;
        case 'line':        av = a.line;         bv = b.line; break;
        case 'genotype':    av = a.genotype;     bv = b.genotype; break;
        case 'ageMonths':   av = a.ageMonths;    bv = b.ageMonths; break;
        case 'males':       av = a.males;        bv = b.males; break;
        case 'females':     av = a.females;      bv = b.females; break;
        case 'juveniles':   av = a.juveniles;    bv = b.juveniles; break;
        case 'tankId':      av = a.tankId;       bv = b.tankId; break;
        case 'responsible': av = a.responsible;  bv = b.responsible; break;
        case 'status':      av = a.status;       bv = b.status; break;
        case 'health':      av = a.health;       bv = b.health; break;
        default: av = a.stockId; bv = b.stockId;
      }
      int c = (av is num && bv is num)
          ? av.compareTo(bv)
          : av.toString().compareTo(bv.toString());
      return _sortAsc ? c : -c;
    });
  }

  void _sort(String key) {
    setState(() {
      if (_sortKey == key) _sortAsc = !_sortAsc;
      else { _sortKey = key; _sortAsc = true; }
    });
    _applyFilters();
  }

  void _openDetail(FishStock stock) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => StockDetailPage(stock: stock),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final lines      = _stocks.map((s) => s.line).toSet().toList()..sort();
    final totalFish  = _filtered.fold(0, (s, r) => s + r.totalFish);
    final tableWidth = _cols.fold(0.0, (s, c) => s + c.$3) + 100;

    return Column(
      children: [
        // ── Toolbar with integrated filter pills ──────────────────────────
        Container(
          color: _DS.bg,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              AppSearchBar(controller: _searchCtrl, hint: 'Search stocks…',
                onClear: _applyFilters),
              const SizedBox(width: 10),
              // Filter pills
              AppFilterChip(
                label: 'Line', value: _filterLine, options: lines,
                onChanged: (v) { setState(() => _filterLine = v); _applyFilters(); },
              ),
              const SizedBox(width: 8),
              AppFilterChip(
                label: 'Status', value: _filterStatus,
                options: const ['active', 'breeding', 'observation', 'archiving'],
                onChanged: (v) { setState(() => _filterStatus = v); _applyFilters(); },
              ),
              const SizedBox(width: 8),
              AppFilterChip(
                label: 'Health', value: _filterHealth,
                options: const ['healthy', 'observation', 'treatment', 'sick'],
                onChanged: (v) { setState(() => _filterHealth = v); _applyFilters(); },
              ),
              const Spacer(),
              // Summary chips
              _summaryChip('${_filtered.length}', 'stocks', _DS.textSecondary),
              const SizedBox(width: 8),
              _summaryChip('$totalFish', 'fish', _DS.green),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _showAddStockDialog,
                icon: const Icon(Icons.add, size: 14),
                label: const Text('New Stock'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _DS.accent,
                  foregroundColor: _DS.bg,
                ),
              ),
            ],
          ),
        ),
        Container(height: 1, color: _DS.border),
        // ── Table ────────────────────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _loadError != null
                  ? Center(
                      child: Text(
                        'Failed to load stocks: $_loadError',
                        style: GoogleFonts.spaceGrotesk(
                          color: _DS.red,
                          fontSize: 13,
                        ),
                      ),
                    )
                  : Column(
                      children: [
              // Sticky header
              Container(
                color: _DS.surface3,
                child: SingleChildScrollView(
                  controller: _headerHorizCtrl,
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  child: SizedBox(
                    width: tableWidth,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                      child: Row(
                        children: [
                          const SizedBox(width: 60),
                          ..._cols.map((c) => SizedBox(
                            width: c.$3,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: SortHeader(
                                label: c.$2, columnKey: c.$1,
                                sortKey: _sortKey, sortAsc: _sortAsc,
                                onSort: _sort),
                            ),
                          )),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Container(height: 1, color: _DS.border),
              Expanded(
                child: Scrollbar(
                  controller: _vertCtrl,
                  child: SingleChildScrollView(
                    controller: _vertCtrl,
                    child: Scrollbar(
                      controller: _horizCtrl,
                      scrollbarOrientation: ScrollbarOrientation.bottom,
                      child: SingleChildScrollView(
                        controller: _horizCtrl,
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: tableWidth,
                          child: Column(
                            children: _filtered
                                .asMap()
                                .entries
                                .map((e) => _buildRow(e.value, e.key))
                                .toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summaryChip(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(value, style: GoogleFonts.jetBrainsMono(
          fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(width: 4),
        Text(label, style: GoogleFonts.spaceGrotesk(
          fontSize: 11, color: _DS.textMuted)),
      ]),
    );
  }

  Widget _buildRow(FishStock stock, int rowIndex) {
    final isEditing = _editingId == stock.id;
    final rowBg = rowIndex.isEven
        ? _DS.surface.withOpacity(0.34)
        : _DS.surface2.withOpacity(0.24);
    return Container(
      decoration: BoxDecoration(
        color: isEditing ? _DS.accent.withOpacity(0.10) : rowBg,
        border: const Border(bottom: BorderSide(color: _DS.border2, width: 1)),
      ),
      child: MouseRegion(
        cursor: SystemMouseCursors.basic,
        child: Row(
          children: [
            SizedBox(
              width: 60,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  AppIconButton(
                    icon: Icons.open_in_new, tooltip: 'Open detail',
                    color: _DS.textMuted,
                    onPressed: () => _openDetail(stock)),
                  AppIconButton(
                    icon: isEditing ? Icons.check : Icons.edit_outlined,
                    tooltip: isEditing ? 'Save' : 'Edit',
                    color: isEditing ? _DS.green : _DS.textMuted,
                    onPressed: () => setState(() {
                      _editingId = isEditing ? null : stock.id;
                    })),
                ]),
              ),
            ),
            _cell(stock, 'stockId',    100),
            _cell(stock, 'line',       140),
            _cell(stock, 'genotype',    90),
            _cell(stock, 'ageMonths',   70),
            _cell(stock, 'males',       50),
            _cell(stock, 'females',     50),
            _cell(stock, 'juveniles',   60),
            _cell(stock, 'tankId',     110, mono: true),
            _cell(stock, 'responsible',130),
            _statusCell(stock, 'status', 110,
              ['active', 'breeding', 'observation', 'archiving']),
            _statusCell(stock, 'health', 110,
              ['healthy', 'observation', 'treatment', 'sick']),
            _cell(stock, 'experiment', 140, mono: true),
            _cell(stock, 'notes',      160),
          ],
        ),
      ),
    );
  }

  Widget _cell(FishStock s, String key, double width, {bool mono = false}) {
    final isEditing = _editingId == s.id && key != 'stockId';
    String? val;
    switch (key) {
      case 'stockId':     val = s.stockId; break;
      case 'line':        val = s.line; break;
      case 'genotype':    val = s.genotype; break;
      case 'ageMonths':   val = '${s.ageMonths}'; break;
      case 'males':       val = '${s.males}'; break;
      case 'females':     val = '${s.females}'; break;
      case 'juveniles':   val = '${s.juveniles}'; break;
      case 'tankId':      val = s.tankId; break;
      case 'responsible': val = s.responsible; break;
      case 'experiment':  val = s.experiment; break;
      case 'notes':       val = s.notes; break;
      default: val = null;
    }
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: isEditing
            ? InlineEditCell(
                value: val, mono: mono, width: width - 12,
                onSaved: (v) => setState(() {
                  switch (key) {
                    case 'line':        s.line = v; break;
                    case 'genotype':    s.genotype = v; break;
                    case 'ageMonths':   s.ageMonths = int.tryParse(v) ?? s.ageMonths; break;
                    case 'males':       s.males = int.tryParse(v) ?? s.males; break;
                    case 'females':     s.females = int.tryParse(v) ?? s.females; break;
                    case 'juveniles':   s.juveniles = int.tryParse(v) ?? s.juveniles; break;
                    case 'tankId':      s.tankId = v; break;
                    case 'responsible': s.responsible = v; break;
                    case 'experiment':  s.experiment = v.isEmpty ? null : v; break;
                    case 'notes':       s.notes = v.isEmpty ? null : v; break;
                  }
                }))
            : Text(
                val ?? '—',
                style: (mono
                    ? GoogleFonts.jetBrainsMono(fontSize: 12)
                    : GoogleFonts.spaceGrotesk(fontSize: 12.5))
                    .copyWith(color: val == null ? _DS.textMuted : _DS.textPrimary),
                overflow: TextOverflow.ellipsis),
      ),
    );
  }

  Widget _statusCell(FishStock s, String key, double width, List<String> options) {
    final isEditing = _editingId == s.id;
    final val = key == 'status' ? s.status : s.health;
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: isEditing
            ? DropdownCell(
                value: val, options: options,
                onChanged: (v) => setState(() {
                  if (v == null) return;
                  if (key == 'status') s.status = v;
                  else s.health = v;
                }))
            : StatusBadge(label: val),
      ),
    );
  }

  void _showAddStockDialog() {
    final occupied = _stocks.map((s) => s.tankId).toSet();
    showDialog(
      context: context,
      builder: (ctx) => _AddStockDialog(
        occupiedTankIds: occupied,
        onAdd: (stock) => setState(() { _stocks.add(stock); _applyFilters(); }),
      ),
    );
  }
}

// ─── ADD STOCK DIALOG ────────────────────────────────────────────────────────
class _AddStockDialog extends StatefulWidget {
  final ValueChanged<FishStock> onAdd;
  final Set<String> occupiedTankIds;
  const _AddStockDialog({
    required this.onAdd,
    required this.occupiedTankIds,
  });

  @override
  State<_AddStockDialog> createState() => _AddStockDialogState();
}

class _AddStockDialogState extends State<_AddStockDialog> {
  final _lineCtrl  = TextEditingController();
  final _genoCtrl  = TextEditingController(text: 'het');
  final _respCtrl  = TextEditingController();
  final _expCtrl   = TextEditingController();
  final _notesCtrl = TextEditingController();

  // Tank position selection
  String _selectedRack = 'R1';
  String _selectedRow = 'A';
  int    _selectedCol = 1;
  bool   _saving      = false;
  String? _error;

  String get _tankId => '$_selectedRack-$_selectedRow$_selectedCol';

  int get _maxCol => _selectedRow == 'A' ? _rowACount : _rowBECount;
  bool _isOccupied(int col) =>
      widget.occupiedTankIds.contains('$_selectedRack-$_selectedRow$col');

  void _selectFirstAvailablePosition() {
    for (int col = 1; col <= _maxCol; col++) {
      if (!_isOccupied(col)) {
        _selectedCol = col;
        return;
      }
    }
  }

  String _status = 'active';
  String _health = 'healthy';

  @override
  void initState() {
    super.initState();
    if (_isOccupied(_selectedCol)) {
      _selectFirstAvailablePosition();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _DS.surface2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: _DS.border2)),
      title: Text('New Fish Stock',
        style: GoogleFonts.spaceGrotesk(
          color: _DS.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
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
                    color: _DS.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _DS.red.withOpacity(0.4)),
                  ),
                  child: Text(_error!,
                    style: GoogleFonts.spaceGrotesk(color: _DS.red, fontSize: 12)),
                ),
                const SizedBox(height: 12),
              ],
              _f('Fish Line *', _lineCtrl),
              const SizedBox(height: 10),
              _f('Genotype', _genoCtrl),
              const SizedBox(height: 10),
              _f('Responsible', _respCtrl),
              const SizedBox(height: 12),
              // Tank position picker
              Text('Tank Position *',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 11, color: _DS.textMuted, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              _buildTankPicker(),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _dd('Status', _status,
                  ['active', 'breeding', 'observation', 'archiving'],
                  (v) => setState(() => _status = v ?? _status))),
                const SizedBox(width: 10),
                Expanded(child: _dd('Health', _health,
                  ['healthy', 'observation', 'treatment', 'sick'],
                  (v) => setState(() => _health = v ?? _health))),
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
            backgroundColor: _DS.accent, foregroundColor: _DS.bg),
          child: _saving
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Add Stock'),
        ),
      ],
    );
  }

  Widget _buildTankPicker() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _DS.surface3,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _DS.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row selector
          Row(children: [
            Text('Rack:', style: GoogleFonts.spaceGrotesk(
              fontSize: 11, color: _DS.textMuted, fontWeight: FontWeight.w700)),
            const SizedBox(width: 10),
            ...['R1', 'R2', 'R3'].map((rack) => Padding(
              padding: const EdgeInsets.only(right: 6),
              child: InkWell(
                onTap: () => setState(() {
                  _selectedRack = rack;
                  if (_isOccupied(_selectedCol)) _selectFirstAvailablePosition();
                }),
                borderRadius: BorderRadius.circular(6),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: 38, height: 32,
                  decoration: BoxDecoration(
                    color: _selectedRack == rack
                        ? _DS.accent.withOpacity(0.2) : _DS.surface2,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _selectedRack == rack ? _DS.accent : _DS.border,
                      width: _selectedRack == rack ? 1.5 : 1),
                  ),
                  child: Center(
                    child: Text(rack, style: GoogleFonts.jetBrainsMono(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      color: _selectedRack == rack ? _DS.accent : _DS.textSecondary)),
                  ),
                ),
              ),
            )),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Text('Row:', style: GoogleFonts.spaceGrotesk(
              fontSize: 11, color: _DS.textMuted, fontWeight: FontWeight.w700)),
            const SizedBox(width: 10),
            ..._rowLabels.map((r) => Padding(
              padding: const EdgeInsets.only(right: 6),
              child: InkWell(
                onTap: () => setState(() {
                  _selectedRow = r;
                  if (_selectedCol > _maxCol) _selectedCol = 1;
                  if (_isOccupied(_selectedCol)) _selectFirstAvailablePosition();
                }),
                borderRadius: BorderRadius.circular(6),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: _selectedRow == r
                        ? _DS.accent.withOpacity(0.2) : _DS.surface2,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _selectedRow == r ? _DS.accent : _DS.border,
                      width: _selectedRow == r ? 1.5 : 1),
                  ),
                  child: Center(
                    child: Text(r, style: GoogleFonts.jetBrainsMono(
                      fontSize: 12, fontWeight: FontWeight.w700,
                      color: _selectedRow == r ? _DS.accent : _DS.textSecondary)),
                  ),
                ),
              ),
            )),
            const SizedBox(width: 8),
            Text(
              _selectedRow == 'A' ? '(15 × 1.5 L)' : '(10 × 3.5 L)',
              style: GoogleFonts.jetBrainsMono(fontSize: 10, color: _DS.textMuted)),
          ]),
          const SizedBox(height: 10),
          // Column selector grid
          Text('Column:', style: GoogleFonts.spaceGrotesk(
            fontSize: 11, color: _DS.textMuted, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 5, runSpacing: 5,
            children: List.generate(_maxCol, (i) {
              final col = i + 1;
              final sel = _selectedCol == col;
              final occupied = _isOccupied(col);
              return InkWell(
                onTap: occupied ? null : () => setState(() => _selectedCol = col),
                borderRadius: BorderRadius.circular(5),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: 34, height: 30,
                  decoration: BoxDecoration(
                    color: occupied
                        ? _DS.red.withOpacity(0.12)
                        : (sel ? _DS.accent.withOpacity(0.18) : _DS.surface2),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: occupied
                          ? _DS.red.withOpacity(0.5)
                          : (sel ? _DS.accent : _DS.border),
                      width: sel ? 1.5 : 1),
                  ),
                  child: Center(
                    child: Text('$col', style: GoogleFonts.jetBrainsMono(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: occupied
                          ? _DS.red
                          : (sel ? _DS.accent : _DS.textSecondary))),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Text('Red positions are already occupied.',
            style: GoogleFonts.jetBrainsMono(fontSize: 10, color: _DS.textMuted)),
          const SizedBox(height: 6),
          // Selected position display
          Row(children: [
            const Icon(Icons.location_on_outlined, size: 13, color: _DS.accent),
            const SizedBox(width: 4),
            Text('Selected: $_tankId',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12, fontWeight: FontWeight.w700, color: _DS.accent)),
          ]),
        ],
      ),
    );
  }

  Widget _f(String label, TextEditingController ctrl) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: GoogleFonts.spaceGrotesk(
        fontSize: 11, color: _DS.textMuted, fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      TextField(
        controller: ctrl,
        style: GoogleFonts.spaceGrotesk(color: _DS.textPrimary, fontSize: 13),
        decoration: InputDecoration(
          isDense: true,
          filled: true, fillColor: _DS.surface3,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: _DS.border)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: _DS.accent, width: 1.5)),
        )),
    ],
  );

  Widget _dd(String label, String value, List<String> opts, ValueChanged<String?> cb) =>
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.spaceGrotesk(
          fontSize: 11, color: _DS.textMuted, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          value: value,
          dropdownColor: _DS.surface2,
          style: GoogleFonts.spaceGrotesk(color: _DS.textPrimary, fontSize: 13),
          items: opts.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
          onChanged: cb,
          decoration: InputDecoration(
            isDense: true,
            filled: true, fillColor: _DS.surface3,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: _DS.border)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: _DS.accent, width: 1.5)),
          )),
      ],
    );

  Future<void> _submit() async {
    final lineName = _lineCtrl.text.trim();
    if (lineName.isEmpty) {
      setState(() => _error = 'Fish line is required.');
      return;
    }
    if (widget.occupiedTankIds.contains(_tankId)) {
      setState(() => _error = 'Tank $_tankId is already occupied.');
      return;
    }
    setState(() { _saving = true; _error = null; });

    try {
      final existingLine = await Supabase.instance.client
          .from('fishlines')
          .select('fishline_id')
          .eq('fishline_name', lineName)
          .maybeSingle();
      if (existingLine == null) {
        setState(() {
          _saving = false;
          _error = 'Fish line "$lineName" does not exist in Fish Lines.';
        });
        return;
      }
    } catch (e) {
      setState(() {
        _saving = false;
        _error = 'Failed to validate fish line: $e';
      });
      return;
    }

    final payload = {
      'fish_line':        lineName,
      'fish_genotype':    _genoCtrl.text.trim(),
      'fish_tank_id':     _tankId,
      'fish_rack':        _selectedRack,
      'fish_row':         _selectedRow,
      'fish_column':      _selectedCol.toString(),
      'fish_responsible': _respCtrl.text.trim(),
      'fish_status':      _status,
      'fish_health_status':      _health,
      'fish_age_days':  0,
      'fish_males':       0,
      'fish_females':     0,
      'fish_juveniles':   0,
      if (_expCtrl.text.isNotEmpty)   'fish_experiment_id': _expCtrl.text.trim(),
      if (_notesCtrl.text.isNotEmpty) 'fish_notes':      _notesCtrl.text.trim()
    };

    try {
      final resp = await Supabase.instance.client
          .from('fish_stocks')
          .insert(payload)
          .select()
          .single();

      final stock = FishStock(
        stockId:     resp['fish_id'].toString(),
        line:        lineName,
        genotype:    _genoCtrl.text.trim(),
        ageMonths:   0,
        males:       0, females: 0, juveniles: 0,
        tankId:      _tankId,
        responsible: _respCtrl.text.trim(),
        status:      _status,
        health:      _health,
        experiment:  _expCtrl.text.isEmpty  ? null : _expCtrl.text.trim(),
        notes:       _notesCtrl.text.isEmpty ? null : _notesCtrl.text.trim(),
        created:     DateTime.now(),
      );

      widget.onAdd(stock);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _saving = false;
        _error  = 'Failed to save: ${e.toString()}';
      });
    }
  }
}
