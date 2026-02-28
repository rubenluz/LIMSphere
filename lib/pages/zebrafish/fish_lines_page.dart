import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/models/connection_model.dart';
import 'shared_widgets.dart';
import 'fishline_detail_page.dart';

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
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted     = Color(0xFF64748B);

  static const TextStyle headerStyle = TextStyle(
    fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.07,
    color: textSecondary,
  );
}

class FishLinesPage extends StatefulWidget {
  const FishLinesPage({super.key});

  @override
  State<FishLinesPage> createState() => _FishLinesPageState();
}

class _FishLinesPageState extends State<FishLinesPage> {
  List<FishLine> _lines = [];
  List<FishLine> _filtered = [];
  final _searchCtrl = TextEditingController();
  String? _filterType;
  String? _filterStatus;
  String? _filterReporter;
  String _sortKey = 'fishlineName';
  bool _sortAsc = true;
  int? _editingId;

  final _vertCtrl = ScrollController();
  final _horizCtrl = ScrollController();
  final _headerHorizCtrl = ScrollController();

  static const _cols = [
    ('fishlineName',       'Name',        160.0, false),
    ('fishlineAlias',      'Alias',       100.0, false),
    ('fishlineType',       'Type',        100.0, false),
    ('fishlineStatus',     'Status',      110.0, false),
    ('fishlineZygosity',   'Zygosity',    110.0, false),
    ('fishlineGeneration', 'Gen.',         60.0, false),
    ('fishlineAffectedGene','Gene',        90.0, true),
    ('fishlineReporter',   'Reporter',     80.0, false),
    ('fishlineTargetTissue','Tissue',     120.0, false),
    ('fishlineOriginLab',  'Origin Lab',  150.0, false),
    ('fishlineDateCreated','Created',     100.0, false),
    ('fishlineZfinId',     'ZFIN ID',     130.0, true),
    ('fishlineCryopreserved','Cryo',       60.0, false),
    ('fishlineSpfStatus',  'SPF',          80.0, false),
    ('fishlineNotes',      'Notes',       150.0, false),
  ];

  @override
  void initState() {
    super.initState();
    _applyFilters();
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

  void _applyFilters() {
    var d = _lines.toList();
    final q = _searchCtrl.text.toLowerCase();
    if (q.isNotEmpty) {
      d = d.where((r) =>
        r.fishlineName.toLowerCase().contains(q) ||
        (r.fishlineAlias?.toLowerCase().contains(q) ?? false) ||
        (r.fishlineAffectedGene?.toLowerCase().contains(q) ?? false) ||
        (r.fishlineOriginLab?.toLowerCase().contains(q) ?? false) ||
        (r.fishlineZfinId?.toLowerCase().contains(q) ?? false)
      ).toList();
    }
    if (_filterType != null) d = d.where((r) => r.fishlineType == _filterType).toList();
    if (_filterStatus != null) d = d.where((r) => r.fishlineStatus == _filterStatus).toList();
    if (_filterReporter != null) d = d.where((r) => r.fishlineReporter == _filterReporter).toList();

    d.sort((a, b) {
      dynamic av, bv;
      switch (_sortKey) {
        case 'fishlineName':       av = a.fishlineName; bv = b.fishlineName; break;
        case 'fishlineAlias':      av = a.fishlineAlias ?? ''; bv = b.fishlineAlias ?? ''; break;
        case 'fishlineType':       av = a.fishlineType ?? ''; bv = b.fishlineType ?? ''; break;
        case 'fishlineStatus':     av = a.fishlineStatus ?? ''; bv = b.fishlineStatus ?? ''; break;
        case 'fishlineZygosity':   av = a.fishlineZygosity ?? ''; bv = b.fishlineZygosity ?? ''; break;
        case 'fishlineGeneration': av = a.fishlineGeneration ?? ''; bv = b.fishlineGeneration ?? ''; break;
        case 'fishlineAffectedGene': av = a.fishlineAffectedGene ?? ''; bv = b.fishlineAffectedGene ?? ''; break;
        case 'fishlineOriginLab':  av = a.fishlineOriginLab ?? ''; bv = b.fishlineOriginLab ?? ''; break;
        default: av = a.fishlineName; bv = b.fishlineName;
      }
      final c = av.toString().compareTo(bv.toString());
      return _sortAsc ? c : -c;
    });

    setState(() => _filtered = d);
  }

  void _sort(String key) {
    setState(() {
      if (_sortKey == key) _sortAsc = !_sortAsc;
      else { _sortKey = key; _sortAsc = true; }
    });
    _applyFilters();
  }

  void _openDetail(FishLine line) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => FishLineDetailPage(
        fishLine: line,
        onSave: (updated) {
          setState(() {
            final idx = _lines.indexWhere((l) => l.fishlineId == updated.fishlineId);
            if (idx >= 0) { _lines[idx] = updated; _applyFilters(); }
          });
        },
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final reporters = _lines.where((l) => l.fishlineReporter != null)
        .map((l) => l.fishlineReporter!).toSet().toList()..sort();
    final tableWidth = _cols.fold(0.0, (s, c) => s + c.$3) + 100;

    return Column(
      children: [
        // ── Toolbar ──────────────────────────────────────────────────────
        Container(
          color: _DS.surface,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(children: [
            AppSearchBar(controller: _searchCtrl, hint: 'Search lines…',
              onClear: _applyFilters),
            const SizedBox(width: 10),
            AppFilterChip(label: 'Type', value: _filterType,
              options: const ['WT', 'transgenic', 'mutant', 'CRISPR', 'KO'],
              onChanged: (v) { setState(() => _filterType = v); _applyFilters(); }),
            const SizedBox(width: 8),
            AppFilterChip(label: 'Status', value: _filterStatus,
              options: const ['active', 'archived', 'cryopreserved', 'lost'],
              onChanged: (v) { setState(() => _filterStatus = v); _applyFilters(); }),
            const SizedBox(width: 8),
            AppFilterChip(label: 'Reporter', value: _filterReporter,
              options: reporters,
              onChanged: (v) { setState(() => _filterReporter = v); _applyFilters(); }),
            const Spacer(),
            Text('${_filtered.length} of ${_lines.length}',
              style: GoogleFonts.jetBrainsMono(fontSize: 11, color: _DS.textMuted)),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 14),
              label: const Text('New Line'),
              onPressed: _showAddLineDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: _DS.accent,
                foregroundColor: _DS.bg,
              ),
            ),
          ]),
        ),
        const Divider(height: 1, color: _DS.border),
        // ── Table ────────────────────────────────────────────────────────
        Expanded(
          child: Column(
            children: [
              // Sticky header
              Container(
                color: _DS.surface2,
                child: SingleChildScrollView(
                  controller: _headerHorizCtrl,
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  child: SizedBox(
                    width: tableWidth,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                      child: Row(children: [
                        const SizedBox(width: 70),
                        ..._cols.map((c) => SizedBox(
                          width: c.$3,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: SortHeader(
                              label: c.$2, columnKey: c.$1,
                              sortKey: _sortKey, sortAsc: _sortAsc, onSort: _sort),
                          ),
                        )),
                      ]),
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
                            children: _filtered.map((l) => _buildRow(l)).toList()),
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

  Widget _buildRow(FishLine line) {
    final isEditing = _editingId == line.fishlineId;
    return Container(
      decoration: BoxDecoration(
        color: isEditing ? _DS.accent.withOpacity(0.04) : Colors.transparent,
        border: const Border(bottom: BorderSide(color: _DS.border, width: 1)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(children: [
                AppIconButton(
                  icon: Icons.open_in_new, tooltip: 'Open detail page',
                  color: _DS.textMuted,
                  onPressed: () => _openDetail(line)),
                AppIconButton(
                  icon: isEditing ? Icons.check : Icons.edit_outlined,
                  tooltip: isEditing ? 'Save' : 'Inline edit',
                  color: isEditing ? _DS.green : _DS.textMuted,
                  onPressed: () => setState(() =>
                    _editingId = isEditing ? null : line.fishlineId),
                ),
                AppIconButton(
                  icon: Icons.delete_outline, tooltip: 'Delete',
                  color: _DS.textMuted,
                  onPressed: () async {
                    final ok = await showConfirmDialog(context,
                      title: 'Delete Line',
                      message: 'Delete "${line.fishlineName}"?');
                    if (ok) setState(() {
                      _lines.removeWhere((l) => l.fishlineId == line.fishlineId);
                      _applyFilters();
                    });
                  }),
              ]),
            ),
          ),
          _nameCell(line, 160),
          _textCell(line, 'fishlineAlias', 100),
          _typeCell(line, 100),
          _statusCell(line, 110),
          _dropCell(line, 'fishlineZygosity', 110, ['homozygous', 'heterozygous', 'unknown']),
          _dropCell(line, 'fishlineGeneration', 60, ['F1','F2','F3','F4','F5']),
          _textCell(line, 'fishlineAffectedGene', 90, mono: true),
          _textCell(line, 'fishlineReporter', 80),
          _textCell(line, 'fishlineTargetTissue', 120),
          _textCell(line, 'fishlineOriginLab', 150),
          _dateCell(line, 100),
          _textCell(line, 'fishlineZfinId', 130, mono: true),
          _cryoCell(line, 60),
          _textCell(line, 'fishlineSpfStatus', 80),
          _textCell(line, 'fishlineNotes', 150),
        ],
      ),
    );
  }

  Widget _nameCell(FishLine l, double w) {
    final isEditing = _editingId == l.fishlineId;
    return SizedBox(
      width: w,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: isEditing
            ? InlineEditCell(
                value: l.fishlineName, width: w - 12,
                onSaved: (v) => setState(() => l.fishlineName = v))
            : Text(l.fishlineName,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 12.5, fontWeight: FontWeight.w600,
                  color: _DS.textPrimary),
                overflow: TextOverflow.ellipsis),
      ),
    );
  }

  Widget _textCell(FishLine l, String key, double w, {bool mono = false}) {
    final isEditing = _editingId == l.fishlineId;
    String? val;
    switch (key) {
      case 'fishlineAlias':       val = l.fishlineAlias; break;
      case 'fishlineAffectedGene':val = l.fishlineAffectedGene; break;
      case 'fishlineReporter':    val = l.fishlineReporter; break;
      case 'fishlineTargetTissue':val = l.fishlineTargetTissue; break;
      case 'fishlineOriginLab':   val = l.fishlineOriginLab; break;
      case 'fishlineZfinId':      val = l.fishlineZfinId; break;
      case 'fishlineSpfStatus':   val = l.fishlineSpfStatus; break;
      case 'fishlineNotes':       val = l.fishlineNotes; break;
      default: val = null;
    }
    return SizedBox(
      width: w,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: isEditing
            ? InlineEditCell(
                value: val, mono: mono, width: w - 12,
                onSaved: (v) => setState(() {
                  final s = v.isEmpty ? null : v;
                  switch (key) {
                    case 'fishlineAlias':       l.fishlineAlias = s; break;
                    case 'fishlineAffectedGene':l.fishlineAffectedGene = s; break;
                    case 'fishlineReporter':    l.fishlineReporter = s; break;
                    case 'fishlineTargetTissue':l.fishlineTargetTissue = s; break;
                    case 'fishlineOriginLab':   l.fishlineOriginLab = s; break;
                    case 'fishlineZfinId':      l.fishlineZfinId = s; break;
                    case 'fishlineSpfStatus':   l.fishlineSpfStatus = s; break;
                    case 'fishlineNotes':       l.fishlineNotes = s; break;
                  }
                }))
            : Text(
                val ?? '—',
                style: (mono
                    ? GoogleFonts.jetBrainsMono(fontSize: 11.5)
                    : GoogleFonts.spaceGrotesk(fontSize: 12))
                    .copyWith(color: val == null ? _DS.textMuted : _DS.textPrimary),
                overflow: TextOverflow.ellipsis),
      ),
    );
  }

  Widget _typeCell(FishLine l, double w) {
    final isEditing = _editingId == l.fishlineId;
    return SizedBox(
      width: w,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: isEditing
            ? DropdownCell(
                value: l.fishlineType,
                options: const ['WT', 'transgenic', 'mutant', 'CRISPR', 'KO', 'KI'],
                onChanged: (v) => setState(() => l.fishlineType = v))
            : StatusBadge(label: l.fishlineType, overrideStatus: l.fishlineType?.toLowerCase()),
      ),
    );
  }

  Widget _statusCell(FishLine l, double w) {
    final isEditing = _editingId == l.fishlineId;
    return SizedBox(
      width: w,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: isEditing
            ? DropdownCell(
                value: l.fishlineStatus,
                options: const ['active', 'archived', 'cryopreserved', 'lost'],
                onChanged: (v) => setState(() => l.fishlineStatus = v))
            : StatusBadge(label: l.fishlineStatus),
      ),
    );
  }

  Widget _dropCell(FishLine l, String key, double w, List<String> opts) {
    final isEditing = _editingId == l.fishlineId;
    String? val;
    switch (key) {
      case 'fishlineZygosity':   val = l.fishlineZygosity; break;
      case 'fishlineGeneration': val = l.fishlineGeneration; break;
    }
    return SizedBox(
      width: w,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: isEditing
            ? DropdownCell(
                value: val, options: opts,
                onChanged: (v) => setState(() {
                  switch (key) {
                    case 'fishlineZygosity':   l.fishlineZygosity = v; break;
                    case 'fishlineGeneration': l.fishlineGeneration = v; break;
                  }
                }))
            : Text(val ?? '—',
                style: GoogleFonts.spaceGrotesk(fontSize: 12, color: _DS.textPrimary),
                overflow: TextOverflow.ellipsis),
      ),
    );
  }

  Widget _dateCell(FishLine l, double w) => SizedBox(
    width: w,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: Text(
        l.fishlineDateCreated?.toIso8601String().split('T')[0] ?? '—',
        style: GoogleFonts.jetBrainsMono(fontSize: 11, color: _DS.textSecondary)),
    ),
  );

  Widget _cryoCell(FishLine l, double w) => SizedBox(
    width: w,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: _editingId == l.fishlineId
          ? Switch(
              value: l.fishlineCryopreserved,
              activeColor: _DS.accent,
              onChanged: (v) => setState(() => l.fishlineCryopreserved = v))
          : Icon(
              l.fishlineCryopreserved ? Icons.ac_unit : Icons.remove,
              size: 14,
              color: l.fishlineCryopreserved ? _DS.accent : _DS.textMuted),
    ),
  );

  void _showAddLineDialog() {
    showDialog(context: context, builder: (_) => _AddLineDialog(
      onAdd: (line) => setState(() { _lines.add(line); _applyFilters(); }),
    ));
  }
}

// ─── ADD LINE DIALOG ─────────────────────────────────────────────────────────
class _AddLineDialog extends StatefulWidget {
  final ValueChanged<FishLine> onAdd;
  const _AddLineDialog({required this.onAdd});

  @override
  State<_AddLineDialog> createState() => _AddLineDialogState();
}

class _AddLineDialogState extends State<_AddLineDialog> {
  final _nameCtrl  = TextEditingController();
  final _aliasCtrl = TextEditingController();
  final _geneCtrl  = TextEditingController();
  final _labCtrl   = TextEditingController();
  String _type     = 'transgenic';
  String _status   = 'active';
  String _zygosity = 'heterozygous';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _DS.surface2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: _DS.border2)),
      title: Text('New Fish Line',
        style: GoogleFonts.spaceGrotesk(
          fontSize: 16, fontWeight: FontWeight.w700, color: _DS.textPrimary)),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _f('Line Name (e.g. Tg(mpx:GFP)uwm1)', _nameCtrl),
            const SizedBox(height: 8),
            _f('Alias', _aliasCtrl),
            const SizedBox(height: 8),
            _f('Affected Gene', _geneCtrl),
            const SizedBox(height: 8),
            _f('Origin Lab', _labCtrl),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _dd('Type', _type,
                ['WT', 'transgenic', 'mutant', 'CRISPR', 'KO', 'KI'],
                (v) => setState(() => _type = v ?? _type))),
              const SizedBox(width: 8),
              Expanded(child: _dd('Status', _status,
                ['active', 'archived', 'cryopreserved', 'lost'],
                (v) => setState(() => _status = v ?? _status))),
            ]),
            const SizedBox(height: 8),
            _dd('Zygosity', _zygosity,
              ['homozygous', 'heterozygous', 'unknown'],
              (v) => setState(() => _zygosity = v ?? _zygosity)),
          ],
        ),
      ),
      actions: [
        OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _DS.accent, foregroundColor: _DS.bg),
          onPressed: () {
            if (_nameCtrl.text.isEmpty) return;
            widget.onAdd(FishLine(
              fishlineId: DateTime.now().millisecondsSinceEpoch,
              fishlineName: _nameCtrl.text,
              fishlineAlias: _aliasCtrl.text.isEmpty ? null : _aliasCtrl.text,
              fishlineType: _type,
              fishlineStatus: _status,
              fishlineZygosity: _zygosity,
              fishlineAffectedGene: _geneCtrl.text.isEmpty ? null : _geneCtrl.text,
              fishlineOriginLab: _labCtrl.text.isEmpty ? null : _labCtrl.text,
              fishlineDateCreated: DateTime.now(),
            ));
            Navigator.pop(context);
          },
          child: const Text('Add Line'),
        ),
      ],
    );
  }

  Widget _f(String label, TextEditingController ctrl) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: GoogleFonts.spaceGrotesk(
        fontSize: 11, color: _DS.textMuted, fontWeight: FontWeight.w700)),
      const SizedBox(height: 3),
      TextField(controller: ctrl,
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
        const SizedBox(height: 3),
        DropdownButtonFormField<String>(
          value: opts.contains(value) ? value : opts.first,
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
}