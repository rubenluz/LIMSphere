import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'fish_lines_connection_model.dart';
import '/core/fish_db_schema.dart';
import '../tanks/tanks_connection_model.dart';
import '../tanks/tanks_detail_page.dart';

// ─── Design tokens (same palette as tanks_detail_page) ───────────────────────
class _DS {
  static const Color headerBg   = Color(0xFF1E293B);
  static const Color accent     = Color(0xFF3B82F6);
  static const Color sectionBg  = Color(0xFFF8FAFC);
  static const Color cardBorder = Color(0xFFE2E8F0);
  static const Color labelColor = Color(0xFF64748B);
  static const Color titleColor = Color(0xFF0F172A);
  static const Color scaffoldBg = Color(0xFFF1F5F9);
  static const Color green      = Color(0xFF16A34A);
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
      (key: 'fish_line_name',       label: 'Name',       lines: 1),
      (key: 'fish_line_alias',      label: 'Alias',      lines: 1),
      (key: 'fish_line_type',       label: 'Type',       lines: 1),
      (key: 'fish_line_status',     label: 'Status',     lines: 1),
      (key: 'fish_line_zygosity',   label: 'Zygosity',   lines: 1),
      (key: 'fish_line_generation', label: 'Generation', lines: 1),
    ],
  ),
  (
    title: 'Genetics',
    icon: 'genetics',
    fields: [
      (key: 'fish_line_affected_gene',        label: 'Affected Gene',        lines: 1),
      (key: 'fish_line_affected_chromosome',  label: 'Chromosome',           lines: 1),
      (key: 'fish_line_mutation_type',        label: 'Mutation Type',        lines: 1),
      (key: 'fish_line_mutation_description', label: 'Mutation Description', lines: 2),
      (key: 'fish_line_transgene',            label: 'Transgene',            lines: 1),
      (key: 'fish_line_construct',            label: 'Construct',            lines: 1),
      (key: 'fish_line_promoter',             label: 'Promoter',             lines: 1),
      (key: 'fish_line_reporter',             label: 'Reporter',             lines: 1),
      (key: 'fish_line_target_tissue',        label: 'Target Tissue',        lines: 1),
    ],
  ),
  (
    title: 'Breeding',
    icon: 'breeding',
    fields: [
      (key: 'fish_line_date_birth', label: 'Date of Birth', lines: 1),
      (key: '_breeders',            label: 'Parent Lines',  lines: 1),
    ],
  ),
  (
    title: 'Origin',
    icon: 'origin',
    fields: [
      (key: 'fish_line_origin_lab',    label: 'Origin Lab',    lines: 1),
      (key: 'fish_line_origin_person', label: 'Origin Person', lines: 1),
      (key: 'fish_line_date_received', label: 'Date Received', lines: 1),
      (key: 'fish_line_source',        label: 'Source',        lines: 1),
      (key: 'fish_line_import_permit', label: 'Import Permit', lines: 1),
      (key: 'fish_line_mta',           label: 'MTA',           lines: 1),
    ],
  ),
  (
    title: 'Publications',
    icon: 'publications',
    fields: [
      (key: 'fish_line_zfin_id', label: 'ZFIN ID',   lines: 1),
      (key: 'fish_line_pubmed',  label: 'PubMed ID', lines: 1),
      (key: 'fish_line_doi',     label: 'DOI',       lines: 1),
    ],
  ),
  (
    title: 'Health',
    icon: 'health',
    fields: [
      (key: 'fish_line_phenotype',    label: 'Phenotype',    lines: 2),
      (key: 'fish_line_lethality',    label: 'Lethality',    lines: 1),
      (key: 'fish_line_health_notes', label: 'Health Notes', lines: 2),
      (key: 'fish_line_risk_level',   label: 'Risk Level',   lines: 1),
      (key: 'fish_line_spf_status',   label: 'SPF Status',   lines: 1),
    ],
  ),
  (
    title: 'Cryopreservation',
    icon: 'cryo',
    fields: [
      (key: '_cryopreserved',           label: 'Cryopreserved', lines: 1),
      (key: 'fish_line_cryo_location',  label: 'Cryo Location', lines: 1),
      (key: 'fish_line_cryo_date',      label: 'Cryo Date',     lines: 1),
      (key: 'fish_line_cryo_method',    label: 'Cryo Method',   lines: 1),
    ],
  ),
  (
    title: 'Identifiers',
    icon: 'identifiers',
    fields: [
      (key: 'fish_line_qrcode',  label: 'QR Code', lines: 1),
      (key: 'fish_line_barcode', label: 'Barcode', lines: 1),
    ],
  ),
  (
    title: 'Notes',
    icon: 'notes',
    fields: [
      (key: 'fish_line_notes',      label: 'Notes',        lines: 5),
      (key: '_created_at',          label: 'Record Created', lines: 1),
      (key: '_updated_at',          label: 'Last Updated',   lines: 1),
    ],
  ),
];

// ─── Constrained dropdowns ────────────────────────────────────────────────────
const _dropdowns = <String, List<String>>{
  'fish_line_type':          ['WT', 'transgenic', 'mutant', 'CRISPR', 'KO', 'KI'],
  'fish_line_status':        ['active', 'archived', 'cryopreserved', 'lost'],
  'fish_line_zygosity':      ['homozygous', 'heterozygous', 'unknown'],
  'fish_line_generation':    ['F1', 'F2', 'F3', 'F4', 'F5', 'F6'],
  'fish_line_mutation_type': ['', 'insertion', 'deletion', 'point mutation', 'inversion'],
  'fish_line_spf_status':    ['SPF', 'non-SPF', 'unknown'],
};

// ─── Date picker fields ───────────────────────────────────────────────────────
const _datePickers = <String>{
  'fish_line_date_birth',
  'fish_line_date_received',
  'fish_line_cryo_date',
};

// ─── Pseudo-keys (never saved directly via ctrl) ──────────────────────────────
const _pseudoKeys = <String>{'_breeders', '_cryopreserved', '_created_at', '_updated_at'};

// ─── Read-only metadata keys ──────────────────────────────────────────────────
const _readOnlyKeys = <String>{'_created_at', '_updated_at'};

// ─── Helpers ──────────────────────────────────────────────────────────────────
IconData _sectionIcon(String icon) => switch (icon) {
  'identity'     => Icons.tag_rounded,
  'genetics'     => Icons.biotech_outlined,
  'breeding'     => Icons.favorite_border_rounded,
  'origin'       => Icons.public_rounded,
  'publications' => Icons.article_outlined,
  'health'       => Icons.health_and_safety_outlined,
  'cryo'         => Icons.ac_unit_rounded,
  'identifiers'  => Icons.qr_code_rounded,
  _              => Icons.notes_rounded,
};

Color _statusColor(String? s) => switch (s?.toLowerCase()) {
  'active'        => _DS.green,
  'healthy'       => _DS.green,
  'archived'      => _DS.labelColor,
  'cryopreserved' => const Color(0xFF6366F1),
  'lost'          => _DS.red,
  _               => _DS.labelColor,
};

bool _isMobile(BuildContext context) => MediaQuery.of(context).size.width < 720;

String _fmtDate(String? s) {
  if (s == null || s.isEmpty) return '';
  return s.split('T').first;
}

String _fmtDateTime(String? s) {
  if (s == null || s.isEmpty) return '—';
  final parts = s.split('T');
  if (parts.length < 2) return parts.first;
  final timePart = parts[1].substring(0, parts[1].length > 5 ? 5 : parts[1].length);
  return '${parts.first}  $timePart';
}

// ─── Page ─────────────────────────────────────────────────────────────────────
class FishLineDetailPage extends StatefulWidget {
  final FishLine fishLine;
  final VoidCallback? onSaved;

  const FishLineDetailPage({super.key, required this.fishLine, this.onSaved});

  @override
  State<FishLineDetailPage> createState() => _FishLineDetailPageState();
}

class _FishLineDetailPageState extends State<FishLineDetailPage> {
  Map<String, dynamic> _data = {};
  bool _loading = true;
  bool _saving  = false;
  int  _mobileSection = 0;
  final Set<int> _expanded = {};
  final Map<String, TextEditingController> _ctrl = {};

  // Stocks
  List<Map<String, dynamic>> _stocks = [];
  bool _stocksLoading = false;

  // Breeders
  List<String> _breeders = [];
  final TextEditingController _breederCustomCtrl = TextEditingController();
  List<String> _allLines = [];

  // Cryopreserved toggle
  bool _cryopreserved = false;

  // ── Computed age from DOB ───────────────────────────────────────────────────
  DateTime? get _dob {
    final s = _ctrl['fish_line_date_birth']?.text ?? '';
    return s.isEmpty ? null : DateTime.tryParse(s);
  }

  int get _ageDays => _dob != null ? DateTime.now().difference(_dob!).inDays : -1;

  String get _ageDaysLabel => _ageDays >= 0 ? '$_ageDays d' : '—';

  @override
  void initState() {
    super.initState();
    _expanded.addAll(List.generate(_groups.length + 1, (i) => i));
    _prefill();
    _load();
    _fetchAllLines();
    _fetchStocks();
  }

  @override
  void dispose() {
    for (final c in _ctrl.values) { c.dispose(); }
    _breederCustomCtrl.dispose();
    super.dispose();
  }

  void _prefill() {
    final l = widget.fishLine;
    _data = {
      'fish_line_name':               l.fishlineName,
      'fish_line_alias':              l.fishlineAlias,
      'fish_line_type':               l.fishlineType,
      'fish_line_status':             l.fishlineStatus,
      'fish_line_zygosity':           l.fishlineZygosity,
      'fish_line_generation':         l.fishlineGeneration,
      'fish_line_affected_gene':      l.fishlineAffectedGene,
      'fish_line_affected_chromosome':l.fishlineAffectedChromosome,
      'fish_line_mutation_type':      l.fishlineMutationType,
      'fish_line_mutation_description':l.fishlineMutationDescription,
      'fish_line_transgene':          l.fishlineTransgene,
      'fish_line_construct':          l.fishlineConstruct,
      'fish_line_promoter':           l.fishlinePromoter,
      'fish_line_reporter':           l.fishlineReporter,
      'fish_line_target_tissue':      l.fishlineTargetTissue,
      'fish_line_date_birth':         l.fishlineDateBirth?.toIso8601String().split('T')[0],
      'fish_line_origin_lab':         l.fishlineOriginLab,
      'fish_line_origin_person':      l.fishlineOriginPerson,
      'fish_line_date_received':      l.fishlineDateReceived?.toIso8601String().split('T')[0],
      'fish_line_source':             l.fishlineSource,
      'fish_line_import_permit':      l.fishlineImportPermit,
      'fish_line_mta':                l.fishlineMta,
      'fish_line_zfin_id':            l.fishlineZfinId,
      'fish_line_pubmed':             l.fishlinePubmed,
      'fish_line_doi':                l.fishlineDoi,
      'fish_line_phenotype':          l.fishlinePhenotype,
      'fish_line_lethality':          l.fishlineLethality,
      'fish_line_health_notes':       l.fishlineHealthNotes,
      'fish_line_risk_level':         l.fishlineRiskLevel,
      'fish_line_spf_status':         l.fishlineSpfStatus,
      'fish_line_cryo_location':      l.fishlineCryoLocation,
      'fish_line_cryo_date':          l.fishlineCryoDate?.toIso8601String().split('T')[0],
      'fish_line_cryo_method':        l.fishlineCryoMethod,
      'fish_line_qrcode':             l.fishlineQrcode,
      'fish_line_barcode':            l.fishlineBarcode,
      'fish_line_notes':              l.fishlineNotes,
      'fish_line_created_at':         l.fishlineCreatedAt?.toIso8601String(),
      'fish_line_updated_at':         l.fishlineUpdatedAt?.toIso8601String(),
    };
    _cryopreserved = l.fishlineCryopreserved;
    final bs = l.fishlineBreeders ?? '';
    _breeders = bs.isEmpty ? [] : bs.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    _syncCtrls();
  }

  void _syncCtrls() {
    for (final g in _groups) {
      for (final f in g.fields) {
        if (_pseudoKeys.contains(f.key)) continue;
        final raw  = _data[f.key];
        final text = raw == null
            ? ''
            : _datePickers.contains(f.key)
                ? _fmtDate(raw.toString())
                : raw.toString();
        if (_ctrl.containsKey(f.key)) {
          _ctrl[f.key]!.text = text;
        } else {
          _ctrl[f.key] = TextEditingController(text: text);
        }
      }
    }
  }

  // ── Supabase ───────────────────────────────────────────────────────────────
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final id = widget.fishLine.fishlineId;
      if (id == null) return;
      final res = await Supabase.instance.client
          .from(FishSch.linesTable)
          .select()
          .eq(FishSch.lineId, id)
          .maybeSingle();
      if (res != null) {
        _data = Map<String, dynamic>.from(res);
        _cryopreserved = res[FishSch.lineCryopreserved] as bool? ?? false;
        final bs = res[FishSch.lineBreeders] as String? ?? '';
        _breeders = bs.isEmpty ? [] : bs.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
        _syncCtrls();
      }
    } catch (e) {
      _snack('Error loading: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchAllLines() async {
    try {
      final rows = await Supabase.instance.client
          .from(FishSch.linesTable)
          .select(FishSch.lineName)
          .order(FishSch.lineName) as List<dynamic>;
      if (!mounted) return;
      setState(() => _allLines = rows.map((r) => r[FishSch.lineName] as String).toList());
    } catch (_) {}
  }

  Future<void> _fetchStocks() async {
    final id = widget.fishLine.fishlineId;
    if (id == null) return;
    setState(() => _stocksLoading = true);
    try {
      final rows = await Supabase.instance.client
          .from(FishSch.stocksTable)
          .select('${FishSch.stockId}, ${FishSch.stockTankId}, ${FishSch.stockTankType}, '
              '${FishSch.stockRack}, ${FishSch.stockRow}, ${FishSch.stockColumn}, '
              '${FishSch.stockVolumeL}, ${FishSch.stockLine}, ${FishSch.stockLineId}, '
              '${FishSch.stockMales}, ${FishSch.stockFemales}, ${FishSch.stockJuveniles}, '
              '${FishSch.stockStatus}')
          .eq(FishSch.stockLineId, id) as List<dynamic>;
      if (!mounted) return;
      final list = rows.map((r) => Map<String, dynamic>.from(r as Map)).toList();
      list.sort((a, b) => _compareTankId(
          a[FishSch.stockTankId] as String? ?? '',
          b[FishSch.stockTankId] as String? ?? ''));
      setState(() => _stocks = list);
    } catch (e) {
      _snack('Error loading stocks: $e');
    } finally {
      if (mounted) setState(() => _stocksLoading = false);
    }
  }

  static int _compareTankId(String a, String b) {
    final re = RegExp(r'^([^-]+)-([A-Za-z]+)(\d+)$');
    final ma = re.firstMatch(a); final mb = re.firstMatch(b);
    if (ma == null || mb == null) return a.compareTo(b);
    final rack = ma.group(1)!.compareTo(mb.group(1)!);
    if (rack != 0) return rack;
    final row = ma.group(2)!.compareTo(mb.group(2)!);
    if (row != 0) return row;
    return int.parse(ma.group(3)!).compareTo(int.parse(mb.group(3)!));
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final payload = <String, dynamic>{};
      for (final g in _groups) {
        for (final f in g.fields) {
          if (_pseudoKeys.contains(f.key)) continue;
          final v = _ctrl[f.key]?.text.trim() ?? '';
          payload[f.key] = v.isEmpty ? null : v;
        }
      }
      payload[FishSch.lineCryopreserved] = _cryopreserved;
      payload[FishSch.lineBreeders] = _breeders.isEmpty ? null : _breeders.join(', ');
      payload[FishSch.lineUpdatedAt] = DateTime.now().toIso8601String();

      final id = widget.fishLine.fishlineId;
      if (id != null) {
        await Supabase.instance.client
            .from(FishSch.linesTable)
            .update(payload)
            .eq(FishSch.lineId, id);
      } else {
        await Supabase.instance.client
            .from(FishSch.linesTable)
            .upsert(payload, onConflict: FishSch.lineName);
      }
      // Update displayed updated_at
      setState(() => _data[FishSch.lineUpdatedAt] = payload[FishSch.lineUpdatedAt]);
      widget.onSaved?.call();
      _snack('Saved successfully.');
    } catch (e) {
      _snack('Save error: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final name = widget.fishLine.fishlineName;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.delete_forever_rounded, color: Color(0xFFDC2626), size: 40),
        title: Text('Delete $name?',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: const TextStyle(fontSize: 14, color: Color(0xFF475569), height: 1.5),
            children: [
              const TextSpan(text: 'This will permanently remove the record for\n'),
              TextSpan(text: name,
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
      final id = widget.fishLine.fishlineId;
      if (id != null) {
        await Supabase.instance.client
            .from(FishSch.linesTable)
            .delete()
            .eq(FishSch.lineId, id);
      }
      widget.onSaved?.call();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _snack('Delete error: $e');
    }
  }

  // ── Calendar date picker ───────────────────────────────────────────────────
  Future<void> _pickDate(String key, String title) async {
    final cur = DateTime.tryParse(_ctrl[key]?.text ?? '') ?? DateTime.now();
    DateTime selected = cur;
    final result = await showDialog<DateTime>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          content: SizedBox(
            width: 300,
            child: CalendarDatePicker(
              initialDate: selected,
              firstDate: DateTime(1990),
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

  // ── Build ──────────────────────────────────────────────────────────────────
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
            _buildSidebarStats(),
            _buildMobileSectionBar(),
            Expanded(child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 100),
              child: _mobileSection == _groups.length
                  ? _buildStocksSection()
                  : Column(
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
        Text(widget.fishLine.fishlineName,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        if (widget.fishLine.fishlineAlias != null)
          Text(widget.fishLine.fishlineAlias!,
              style: const TextStyle(fontSize: 11, color: Colors.white60,
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
              title: Text('Delete line',
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
    final status = _ctrl['fish_line_status']?.text
        ?? widget.fishLine.fishlineStatus ?? '';
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
            Text(widget.fishLine.fishlineName,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(width: 10),
            if (status.isNotEmpty) _statusPill(status),
            if (widget.fishLine.fishlineType != null) ...[
              const SizedBox(width: 6),
              _infoPill(widget.fishLine.fishlineType!),
            ],
          ]),
          if (widget.fishLine.fishlineAlias != null || widget.fishLine.fishlineZfinId != null)
            Text(
              [
                if (widget.fishLine.fishlineAlias != null) widget.fishLine.fishlineAlias!,
                if (widget.fishLine.fishlineZfinId != null) widget.fishLine.fishlineZfinId!,
              ].join('  ·  '),
              style: const TextStyle(fontSize: 11, color: Colors.white60,
                  fontStyle: FontStyle.italic)),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded,
              color: Color(0xFFFC8181), size: 20),
          tooltip: 'Delete line',
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
      // ── Sidebar ────────────────────────────────────────────────────────────
      SizedBox(
        width: 240,
        child: Container(
          color: Colors.white,
          child: Column(children: [
            const Divider(height: 1),
            _buildSidebarStats(),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _groups.length + 1,
                itemBuilder: (ctx, i) {
                  final isTanks = i == _groups.length;
                  final isExp   = _expanded.contains(i);
                  final title   = isTanks
                      ? 'Tanks (${_stocks.length})'
                      : _groups[i].title;
                  final icon    = isTanks
                      ? Icons.water_rounded
                      : _sectionIcon(_groups[i].icon);
                  return ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                    leading: Icon(icon, size: 18,
                        color: isExp ? _DS.accent : const Color(0xFF94A3B8)),
                    title: Text(title,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isExp ? FontWeight.w600 : FontWeight.normal,
                          color: isExp ? _DS.accent : const Color(0xFF475569))),
                    trailing: Icon(
                        isExp ? Icons.keyboard_arrow_down_rounded
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
      // ── Main content ────────────────────────────────────────────────────────
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
              if (_expanded.contains(_groups.length)) _buildStocksSection(),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    ],
  );

  // ── Sidebar stats ──────────────────────────────────────────────────────────
  Widget _buildSidebarStats() => Container(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
    color: _DS.sectionBg,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('OVERVIEW',
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
              color: _DS.labelColor, letterSpacing: 0.8)),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _sidebarStat('TYPE',
            _ctrl['fish_line_type']?.text.isNotEmpty == true
                ? _ctrl['fish_line_type']!.text
                : (widget.fishLine.fishlineType ?? '—'),
            _DS.accent)),
        const SizedBox(width: 6),
        Expanded(child: _sidebarStat('GEN',
            _ctrl['fish_line_generation']?.text.isNotEmpty == true
                ? _ctrl['fish_line_generation']!.text
                : (widget.fishLine.fishlineGeneration ?? '—'),
            _DS.labelColor)),
      ]),
      if (_ageDays >= 0) ...[
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: _sidebarStat('AGE', _ageDaysLabel, _DS.orange)),
          const SizedBox(width: 6),
          Expanded(child: _sidebarStat('CRYO',
              _cryopreserved ? 'Yes' : 'No',
              _cryopreserved ? const Color(0xFF6366F1) : _DS.labelColor)),
        ]),
      ] else ...[
        const SizedBox(height: 6),
        _sidebarStat('CRYO',
            _cryopreserved ? 'Yes' : 'No',
            _cryopreserved ? const Color(0xFF6366F1) : _DS.labelColor),
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

  // ── Mobile section tab bar ─────────────────────────────────────────────────
  Widget _buildMobileSectionBar() {
    final totalTabs = _groups.length + 1; // +1 for Tanks
    return Container(
      color: Colors.white,
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        itemCount: totalTabs,
        itemBuilder: (ctx, i) {
          final isActive = _mobileSection == i;
          final isTanks = i == _groups.length;
          final label = isTanks ? 'Tanks (${_stocks.length})' : _groups[i].title;
          final icon  = isTanks ? Icons.water_rounded : _sectionIcon(_groups[i].icon);
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
                Icon(icon, size: 13,
                    color: isActive ? Colors.white : const Color(0xFF64748B)),
                const SizedBox(width: 5),
                Text(label,
                    style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: isActive ? Colors.white : const Color(0xFF475569))),
              ]),
            ),
          );
        },
      ),
    );
  }

  // ── Desktop section card ───────────────────────────────────────────────────
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
          Padding(
            padding: const EdgeInsets.all(20),
            child: LayoutBuilder(builder: (ctx, box) {
              final cols  = box.maxWidth > 800 ? 3 : box.maxWidth > 520 ? 2 : 1;
              final fieldW = (box.maxWidth - (cols - 1) * 16) / cols;
              return Wrap(
                spacing: 16, runSpacing: 16,
                children: fields.map((f) => SizedBox(
                  width: (f.key == '_breeders' || f.lines > 1)
                      ? double.infinity
                      : fieldW,
                  child: _buildField(f))).toList(),
              );
            }),
          ),
        ]),
      ),
    );

  // ── Field dispatcher ───────────────────────────────────────────────────────
  Widget _buildField(_Field f) {
    // Read-only metadata
    if (_readOnlyKeys.contains(f.key)) { return _buildMetaField(f); }

    // Breeders multi-select
    if (f.key == '_breeders') { return _buildBreedersField(); }

    // Cryopreserved toggle
    if (f.key == '_cryopreserved') { return _buildCryoToggle(); }

    final ctrl = _ctrl[f.key] ??= TextEditingController(
        text: _data[f.key]?.toString() ?? '');

    // Constrained dropdown
    if (_dropdowns.containsKey(f.key)) {
      final opts = _dropdowns[f.key]!;
      final val  = opts.contains(ctrl.text) ? ctrl.text : null;
      return DropdownButtonFormField<String>(
        initialValue: val,
        decoration: _dec(f.label),
        style: const TextStyle(fontSize: 13, color: _DS.titleColor),
        items: [
          if (opts.contains(''))
            const DropdownMenuItem<String>(value: '',
                child: Text('\u2014 not set \u2014',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)))
          else
            const DropdownMenuItem<String>(value: null,
                child: Text('\u2014 not set \u2014',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13))),
          ...opts.where((v) => v.isNotEmpty).map((v) => DropdownMenuItem(
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

  // ── Cryopreserved toggle ───────────────────────────────────────────────────
  Widget _buildCryoToggle() => InputDecorator(
    decoration: _dec('Cryopreserved'),
    child: Row(children: [
      Expanded(child: Text(
          _cryopreserved ? 'Yes' : 'No',
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600,
              color: _cryopreserved ? const Color(0xFF6366F1) : _DS.labelColor))),
      Switch(
        value: _cryopreserved,
        activeThumbColor: Colors.white,
        activeTrackColor: const Color(0xFF6366F1),
        onChanged: (v) => setState(() => _cryopreserved = v)),
    ]),
  );

  // ── Breeders multi-select + custom entry ────────────────────────────────────
  Widget _buildBreedersField() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      InputDecorator(
        decoration: _dec('Parent Lines').copyWith(
          helperText: 'Select from existing lines or type a custom name',
          helperStyle: const TextStyle(fontSize: 10, color: _DS.labelColor)),
        child: _breeders.isEmpty
            ? const Text('No parent lines set',
                style: TextStyle(color: _DS.labelColor, fontSize: 13))
            : Wrap(
                spacing: 6, runSpacing: 4,
                children: _breeders.map((b) => Chip(
                  label: Text(b,
                      style: const TextStyle(fontSize: 11, color: _DS.titleColor)),
                  backgroundColor: _DS.accent.withValues(alpha: 0.08),
                  side: BorderSide(color: _DS.accent.withValues(alpha: 0.3)),
                  visualDensity: VisualDensity.compact,
                  deleteIcon: const Icon(Icons.close, size: 14),
                  deleteIconColor: _DS.labelColor,
                  onDeleted: () => setState(() => _breeders.remove(b)),
                )).toList()),
      ),
      const SizedBox(height: 10),
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        // Dropdown for existing lines
        Expanded(
          flex: 3,
          child: DropdownButtonFormField<String>(
            decoration: _dec('Add from existing line')
                .copyWith(isDense: true),
            style: const TextStyle(fontSize: 13, color: _DS.titleColor),
            hint: const Text('Select…',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
            items: _allLines
                .where((l) => !_breeders.contains(l) && l != widget.fishLine.fishlineName)
                .map((l) => DropdownMenuItem(value: l,
                    child: Text(l, style: const TextStyle(fontSize: 13, color: _DS.titleColor))))
                .toList(),
            onChanged: (v) {
              if (v != null && !_breeders.contains(v)) {
                setState(() => _breeders.add(v));
              }
            },
          ),
        ),
        const SizedBox(width: 10),
        // Custom text entry
        Expanded(
          flex: 2,
          child: TextFormField(
            controller: _breederCustomCtrl,
            style: const TextStyle(fontSize: 13, color: _DS.titleColor),
            decoration: _dec('Custom name').copyWith(isDense: true),
            onFieldSubmitted: _addCustomBreeder,
          ),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: () => _addCustomBreeder(_breederCustomCtrl.text),
          style: FilledButton.styleFrom(
            backgroundColor: _DS.accent,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Add', style: TextStyle(fontSize: 12))),
      ]),
    ]);
  }

  void _addCustomBreeder(String val) {
    final v = val.trim();
    if (v.isNotEmpty && !_breeders.contains(v)) {
      setState(() {
        _breeders.add(v);
        _breederCustomCtrl.clear();
      });
    }
  }

  // ── Read-only metadata field ───────────────────────────────────────────────
  Widget _buildMetaField(_Field f) {
    final rawKey = f.key == '_created_at' ? 'fish_line_created_at' : 'fish_line_updated_at';
    final raw = _data[rawKey] as String?;
    final display = _fmtDateTime(raw);
    return InputDecorator(
      decoration: _dec(f.label).copyWith(
        fillColor: const Color(0xFFF0F4F8),
        suffixIcon: const Icon(Icons.schedule_outlined,
            size: 14, color: _DS.labelColor)),
      child: Text(display,
          style: GoogleFonts.jetBrainsMono(
              fontSize: 12, color: _DS.labelColor)),
    );
  }

  // ── Shared decoration ──────────────────────────────────────────────────────
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

  Widget _infoPill(String s) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white.withValues(alpha: 0.3))),
    child: Text(s,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
            color: Colors.white70)),
  );

  // ── Stocks / Tanks section ─────────────────────────────────────────────────
  Widget _buildStocksSection() {
    if (_stocks.isEmpty && !_stocksLoading) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _DS.cardBorder),
          boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              color: _DS.sectionBg,
              borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12), topRight: Radius.circular(12)),
              border: Border(bottom: BorderSide(color: _DS.cardBorder)),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _DS.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.water_rounded, size: 16, color: _DS.accent)),
              const SizedBox(width: 10),
              Text('TANKS  (${_stocks.length})', style: _DS.sectionTitle),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() {
                  final idx = _groups.length;
                  if (_expanded.contains(idx)) { _expanded.remove(idx); }
                  else { _expanded.add(idx); }
                }),
                child: const Icon(Icons.keyboard_arrow_up_rounded,
                    size: 20, color: Color(0xFF94A3B8))),
            ]),
          ),
          if (_stocksLoading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
          else
            _buildStocksTable(),
        ]),
      ),
    );
  }

  Widget _buildStocksTable() {
    final availRacks = _stocks
        .map((s) => s[FishSch.stockRack] as String? ?? '')
        .where((r) => r.isNotEmpty)
        .toSet()
        .toList()..sort();

    return Column(children: [
      // Header row
      Container(
        color: const Color(0xFFF8FAFC),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          const SizedBox(width: 110,
              child: Text('TANK', style: TextStyle(fontSize: 10,
                  fontWeight: FontWeight.w700, color: _DS.labelColor, letterSpacing: 0.5))),
          const SizedBox(width: 44,
              child: Text('♂', textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _DS.accent))),
          const SizedBox(width: 44,
              child: Text('♀', textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _DS.pink))),
          const SizedBox(width: 44,
              child: Text('Juv', textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _DS.orange))),
          const SizedBox(width: 54,
              child: Text('Total', textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _DS.titleColor))),
          const Expanded(
              child: Text('STATUS', style: TextStyle(fontSize: 10,
                  fontWeight: FontWeight.w700, color: _DS.labelColor, letterSpacing: 0.5))),
        ]),
      ),
      const Divider(height: 1),
      ...List.generate(_stocks.length, (i) {
        final s       = _stocks[i];
        final males   = (s[FishSch.stockMales]     as int?) ?? 0;
        final females = (s[FishSch.stockFemales]   as int?) ?? 0;
        final juvs    = (s[FishSch.stockJuveniles] as int?) ?? 0;
        final total   = males + females + juvs;
        final tankId  = s[FishSch.stockTankId] as String? ?? '—';
        final status  = s[FishSch.stockStatus]  as String? ?? '';
        final tank    = ZebrafishTank.fromMap(s);
        return InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => TankDetailPage(tank: tank, availableRacks: availRacks))),
          child: Container(
            color: i.isEven ? Colors.white : const Color(0xFFFAFAFC),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: [
              SizedBox(width: 110, child: Text(tankId,
                  style: GoogleFonts.jetBrainsMono(
                      fontSize: 12, fontWeight: FontWeight.w700, color: _DS.accent))),
              SizedBox(width: 44, child: _stockNumCell(males,   males   > 0 ? _DS.accent : _DS.labelColor)),
              SizedBox(width: 44, child: _stockNumCell(females, females > 0 ? _DS.pink   : _DS.labelColor)),
              SizedBox(width: 44, child: _stockNumCell(juvs,    juvs    > 0 ? _DS.orange : _DS.labelColor)),
              SizedBox(width: 54, child: _stockNumCell(total,   total   > 0 ? _DS.titleColor : _DS.labelColor)),
              Expanded(child: _stockStatusChip(status)),
            ]),
          ),
        );
      }),
      const SizedBox(height: 4),
    ]);
  }

  Widget _stockNumCell(int val, Color color) => Text(
      val == 0 ? '—' : '$val',
      textAlign: TextAlign.center,
      style: GoogleFonts.jetBrainsMono(
          fontSize: 12, fontWeight: FontWeight.w600, color: color));

  Widget _stockStatusChip(String status) {
    if (status.isEmpty) return const SizedBox.shrink();
    final color = switch (status.toLowerCase()) {
      'active'   => _DS.green,
      'empty'    => _DS.labelColor,
      'breeding' => _DS.accent,
      'sick'     => _DS.red,
      _          => _DS.labelColor,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Text(status,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }
}
