import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide LocalStorage;
import '/core/supabase_manager.dart';
import '/theme/theme.dart';
import 'reagent_model.dart';
import 'reagent_detail_page.dart';

class ReagentsPage extends StatefulWidget {
  const ReagentsPage({super.key});

  @override
  State<ReagentsPage> createState() => _ReagentsPageState();
}

class _ReagentsPageState extends State<ReagentsPage> {
  List<ReagentModel> _all = [];
  List<ReagentModel> _filtered = [];
  bool _loading = true;
  String _search = '';
  String _typeFilter = 'all';
  String _statusFilter = 'all'; // all | expiring | expired | low
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await Supabase.instance.client
          .from('reagents')
          .select(
              '*, location:reagent_location_id(location_name)')
          .order('reagent_name');

      final items = rows.map<ReagentModel>((r) {
        final locData = r['location'];
        final locName =
            locData is Map ? locData['location_name'] as String? : null;
        return ReagentModel.fromMap({...r, 'location_name': locName});
      }).toList();

      if (mounted) {
        setState(() {
          _all = items;
          _loading = false;
          _applyFilters();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to load: $e')));
      }
    }
  }

  void _applyFilters() {
    final q = _search.toLowerCase();
    setState(() {
      _filtered = _all.where((r) {
        if (_typeFilter != 'all' && r.type != _typeFilter) return false;
        if (_statusFilter == 'expired' && !r.isExpired) return false;
        if (_statusFilter == 'expiring' && !r.isExpiringSoon) return false;
        if (_statusFilter == 'low' && !r.isLowStock) return false;
        if (q.isEmpty) return true;
        return r.name.toLowerCase().contains(q) ||
            (r.brand?.toLowerCase().contains(q) ?? false) ||
            (r.reference?.toLowerCase().contains(q) ?? false) ||
            (r.casNumber?.toLowerCase().contains(q) ?? false) ||
            (r.supplier?.toLowerCase().contains(q) ?? false);
      }).toList();
    });
  }

  Future<void> _showAddEditDialog([ReagentModel? existing]) async {
    final locations = await _loadLocations();
    if (!mounted) return;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) =>
          _ReagentFormDialog(existing: existing, locations: locations),
    );
    if (result == true) _load();
  }

  Future<List<Map<String, dynamic>>> _loadLocations() async {
    try {
      final rows = await Supabase.instance.client
          .from('storage_locations')
          .select('location_id, location_name')
          .order('location_name');
      return List<Map<String, dynamic>>.from(rows);
    } catch (_) {
      return [];
    }
  }

  Future<void> _delete(ReagentModel r) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppDS.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Delete Reagent',
            style: GoogleFonts.spaceGrotesk(color: AppDS.textPrimary)),
        content: Text('Delete "${r.name}"? This cannot be undone.',
            style: GoogleFonts.spaceGrotesk(color: AppDS.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style: GoogleFonts.spaceGrotesk(color: AppDS.textSecondary))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Delete',
                  style: GoogleFonts.spaceGrotesk(color: AppDS.red))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await Supabase.instance.client
          .from('reagents')
          .delete()
          .eq('reagent_id', r.id);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
      }
    }
  }

  void _showQr(ReagentModel r) {
    final ref = SupabaseManager.projectRef ?? 'local';
    final data = 'bluelims://$ref/reagent/${r.id}';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppDS.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('QR — ${r.name}',
            style: GoogleFonts.spaceGrotesk(color: AppDS.textPrimary)),
        content: SizedBox(
          width: 260,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                color: Colors.white,
                padding: const EdgeInsets.all(12),
                child: QrImageView(data: data, size: 200)),
            const SizedBox(height: 10),
            Text(data,
                style: GoogleFonts.spaceGrotesk(
                    color: AppDS.textMuted, fontSize: 11)),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: data));
                if (context.mounted) Navigator.pop(ctx);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copied to clipboard')));
              },
              child: Text('Copy Link',
                  style: GoogleFonts.spaceGrotesk(color: AppDS.accent))),
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Close',
                  style:
                      GoogleFonts.spaceGrotesk(color: AppDS.textSecondary))),
        ],
      ),
    );
  }

  Future<void> _exportCsv() async {
    final buf = StringBuffer();
    buf.writeln(
        'ID,Name,Brand,Reference,CAS,Type,Quantity,Unit,Storage,Location,Lot,Expiry,Supplier,Responsible');
    for (final r in _filtered) {
      buf.writeln(
          '${r.id},"${r.name}","${r.brand ?? ''}","${r.reference ?? ''}","${r.casNumber ?? ''}","${r.type}","${r.quantity ?? ''}","${r.unit ?? ''}","${r.storageTemp ?? ''}","${r.locationName ?? ''}","${r.lotNumber ?? ''}","${r.expiryDate != null ? r.expiryDate!.toIso8601String().substring(0, 10) : ''}","${r.supplier ?? ''}","${r.responsible ?? ''}"');
    }
    try {
      final dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/reagents_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(buf.toString());
      await OpenFilex.open(file.path);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  int get _expiredCount => _all.where((r) => r.isExpired).length;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // ── Toolbar ──────────────────────────────────────────────────────────────
      Container(
        height: 56,
        decoration: const BoxDecoration(
          color: AppDS.surface2,
          border: Border(bottom: BorderSide(color: AppDS.border)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          const Icon(Icons.water_drop_outlined,
              color: Color(0xFFF59E0B), size: 18),
          const SizedBox(width: 8),
          Text('Reagents',
              style: GoogleFonts.spaceGrotesk(
                  color: AppDS.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 16),
          Expanded(
            child: SizedBox(
              height: 36,
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) {
                  _search = v;
                  _applyFilters();
                },
                style: GoogleFonts.spaceGrotesk(
                    color: AppDS.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search reagents...',
                  hintStyle: GoogleFonts.spaceGrotesk(
                      color: AppDS.textMuted, fontSize: 13),
                  prefixIcon: const Icon(Icons.search,
                      color: AppDS.textMuted, size: 16),
                  suffixIcon: _search.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear,
                              size: 14, color: AppDS.textMuted),
                          onPressed: () {
                            _searchCtrl.clear();
                            _search = '';
                            _applyFilters();
                          })
                      : null,
                  filled: true,
                  fillColor: AppDS.surface3,
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppDS.border)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppDS.border)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppDS.accent)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 36,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _typeFilter,
                dropdownColor: AppDS.surface,
                style: GoogleFonts.spaceGrotesk(
                    color: AppDS.textPrimary, fontSize: 13),
                items: [
                  DropdownMenuItem(
                      value: 'all',
                      child: Text('All Types',
                          style: GoogleFonts.spaceGrotesk(
                              color: AppDS.textSecondary, fontSize: 13))),
                  ...ReagentModel.typeOptions.map((t) => DropdownMenuItem(
                        value: t,
                        child: Text(ReagentModel.typeLabel(t),
                            style: GoogleFonts.spaceGrotesk(
                                color: AppDS.textPrimary, fontSize: 13)),
                      )),
                ],
                onChanged: (v) {
                  _typeFilter = v ?? 'all';
                  _applyFilters();
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: 'Export CSV',
            child: IconButton(
              icon: const Icon(Icons.download_outlined,
                  color: AppDS.textSecondary, size: 18),
              onPressed: _exportCsv,
            ),
          ),
          const SizedBox(width: 4),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              minimumSize: const Size(0, 36),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => _showAddEditDialog(),
            icon: const Icon(Icons.add, size: 16),
            label:
                Text('Add Reagent', style: GoogleFonts.spaceGrotesk(fontSize: 13)),
          ),
        ]),
      ),

      // ── Filter chips ─────────────────────────────────────────────────────────
      Container(
        height: 44,
        decoration: const BoxDecoration(
          color: AppDS.bg,
          border: Border(bottom: BorderSide(color: AppDS.border)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          _FilterChip(
            label: 'All (${_all.length})',
            selected: _statusFilter == 'all',
            onTap: () {
              _statusFilter = 'all';
              _applyFilters();
            },
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label:
                'Expiring (${_all.where((r) => r.isExpiringSoon).length})',
            selected: _statusFilter == 'expiring',
            color: AppDS.yellow,
            onTap: () {
              _statusFilter = 'expiring';
              _applyFilters();
            },
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Expired ($_expiredCount)',
            selected: _statusFilter == 'expired',
            color: AppDS.red,
            onTap: () {
              _statusFilter = 'expired';
              _applyFilters();
            },
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label:
                'Low Stock (${_all.where((r) => r.isLowStock).length})',
            selected: _statusFilter == 'low',
            color: AppDS.orange,
            onTap: () {
              _statusFilter = 'low';
              _applyFilters();
            },
          ),
        ]),
      ),

      // ── Expired alert banner ──────────────────────────────────────────────────
      if (_expiredCount > 0 && _statusFilter == 'all')
        Container(
          width: double.infinity,
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: AppDS.red.withValues(alpha: 0.12),
          child: Row(children: [
            const Icon(Icons.warning_amber_outlined,
                color: AppDS.red, size: 16),
            const SizedBox(width: 8),
            Text(
              '$_expiredCount reagent${_expiredCount > 1 ? 's' : ''} expired — please review.',
              style: GoogleFonts.spaceGrotesk(
                  color: AppDS.red, fontSize: 12),
            ),
          ]),
        ),

      // ── Body ─────────────────────────────────────────────────────────────────
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.water_drop_outlined,
                            size: 48, color: AppDS.textMuted),
                        const SizedBox(height: 12),
                        Text('No reagents found',
                            style: GoogleFonts.spaceGrotesk(
                                color: AppDS.textMuted, fontSize: 15)),
                      ],
                    ),
                  )
                : Column(children: [
                    // ── Header row ─────────────────────────────────────────
                    Container(
                      height: 32,
                      decoration: const BoxDecoration(
                        color: AppDS.surface2,
                        border: Border(
                          bottom: BorderSide(color: AppDS.border),
                          top: BorderSide(color: AppDS.border),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(children: [
                        const SizedBox(width: 4), // accent strip
                        Expanded(
                          flex: 5,
                          child: Text('NAME / TYPE',
                              style: GoogleFonts.spaceGrotesk(
                                  color: AppDS.textMuted,
                                  fontSize: 10,
                                  letterSpacing: 0.8,
                                  fontWeight: FontWeight.w600)),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text('BRAND / REF',
                              style: GoogleFonts.spaceGrotesk(
                                  color: AppDS.textMuted,
                                  fontSize: 10,
                                  letterSpacing: 0.8,
                                  fontWeight: FontWeight.w600)),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text('QTY / UNIT',
                              style: GoogleFonts.spaceGrotesk(
                                  color: AppDS.textMuted,
                                  fontSize: 10,
                                  letterSpacing: 0.8,
                                  fontWeight: FontWeight.w600)),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text('LOCATION',
                              style: GoogleFonts.spaceGrotesk(
                                  color: AppDS.textMuted,
                                  fontSize: 10,
                                  letterSpacing: 0.8,
                                  fontWeight: FontWeight.w600)),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text('EXPIRY',
                              style: GoogleFonts.spaceGrotesk(
                                  color: AppDS.textMuted,
                                  fontSize: 10,
                                  letterSpacing: 0.8,
                                  fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 108), // actions
                      ]),
                    ),
                    // ── Rows ───────────────────────────────────────────────
                    Expanded(
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: _filtered.length,
                        itemBuilder: (ctx, i) {
                          final r = _filtered[i];
                          return _ReagentRow(
                            reagent: r,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ReagentDetailPage(reagentId: r.id),
                              ),
                            ),
                            onDelete: () => _delete(r),
                            onQr: () => _showQr(r),
                          );
                        },
                      ),
                    ),
                  ]),
      ),
    ]);
  }
}

// ─── Reagent Row ───────────────────────────────────────────────────────────────
class _ReagentRow extends StatelessWidget {
  final ReagentModel reagent;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onQr;

  const _ReagentRow({
    required this.reagent,
    required this.onTap,
    required this.onDelete,
    required this.onQr,
  });

  static const _typeAccent = {
    'chemical':   Color(0xFF38BDF8),
    'biological': Color(0xFF22C55E),
    'kit':        Color(0xFF8B5CF6),
    'media':      Color(0xFF10B981),
    'gas':        Color(0xFF64748B),
    'consumable': Color(0xFFF59E0B),
  };

  @override
  Widget build(BuildContext context) {
    final r = reagent;
    final accent = _typeAccent[r.type] ?? const Color(0xFF94A3B8);
    final expiryStr =
        r.expiryDate?.toIso8601String().substring(0, 10);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppDS.border),
              left: BorderSide(
                color: r.isExpired
                    ? AppDS.red
                    : r.isExpiringSoon
                        ? AppDS.yellow
                        : accent,
                width: 3,
              ),
            ),
            color: r.isExpired
                ? AppDS.red.withValues(alpha: 0.04)
                : AppDS.surface,
          ),
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            // ── Name / type ──────────────────────────────────────────────
            Expanded(
              flex: 5,
              child: Row(children: [
                Flexible(
                  child: Text(r.name,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.spaceGrotesk(
                          color: AppDS.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                ),
                const SizedBox(width: 6),
                _Badge(label: ReagentModel.typeLabel(r.type), color: accent),
                if (r.isExpired) ...[
                  const SizedBox(width: 4),
                  _Badge(label: 'Expired', color: AppDS.red),
                ] else if (r.isExpiringSoon) ...[
                  const SizedBox(width: 4),
                  _Badge(label: 'Expiring', color: AppDS.yellow),
                ],
                if (r.isLowStock) ...[
                  const SizedBox(width: 4),
                  _Badge(label: 'Low', color: AppDS.orange),
                ],
                if (r.hazard != null && r.hazard!.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Tooltip(
                    message: 'Hazard: ${r.hazard}',
                    child: const Icon(Icons.warning_amber_outlined,
                        size: 13, color: AppDS.yellow),
                  ),
                ],
              ]),
            ),
            // ── Brand / ref ──────────────────────────────────────────────
            Expanded(
              flex: 3,
              child: Text(
                [r.brand, if (r.reference != null) r.reference]
                    .whereType<String>()
                    .join(' · '),
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.spaceGrotesk(
                    color: AppDS.textSecondary, fontSize: 12),
              ),
            ),
            // ── Qty / unit ───────────────────────────────────────────────
            Expanded(
              flex: 2,
              child: Text(
                r.quantity != null ? r.displayQuantity : '—',
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.jetBrainsMono(
                    color: AppDS.textSecondary, fontSize: 12),
              ),
            ),
            // ── Location ─────────────────────────────────────────────────
            Expanded(
              flex: 2,
              child: Text(
                r.locationName ?? '—',
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.spaceGrotesk(
                    color: AppDS.textSecondary, fontSize: 12),
              ),
            ),
            // ── Expiry ───────────────────────────────────────────────────
            Expanded(
              flex: 2,
              child: Text(
                expiryStr ?? '—',
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.jetBrainsMono(
                    color: r.isExpired
                        ? AppDS.red
                        : r.isExpiringSoon
                            ? AppDS.yellow
                            : AppDS.textSecondary,
                    fontSize: 12),
              ),
            ),
            // ── Actions ──────────────────────────────────────────────────
            SizedBox(
              width: 108,
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                _RowBtn(Icons.open_in_new, 'View detail', onTap),
                _RowBtn(Icons.qr_code, 'QR Code', onQr),
                _RowBtn(Icons.delete_outline, 'Delete', onDelete,
                    color: AppDS.red.withValues(alpha: 0.7)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _RowBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? color;
  const _RowBtn(this.icon, this.tooltip, this.onPressed, {this.color});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 15, color: color ?? AppDS.textSecondary),
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: GoogleFonts.spaceGrotesk(color: color, fontSize: 11)),
    );
  }
}


class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;
  const _FilterChip(
      {required this.label,
      required this.selected,
      required this.onTap,
      this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppDS.accent;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? c.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? c : AppDS.border, width: selected ? 1.5 : 1),
        ),
        child: Text(label,
            style: GoogleFonts.spaceGrotesk(
                color: selected ? c : AppDS.textSecondary,
                fontSize: 12,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.normal)),
      ),
    );
  }
}

// ─── Add/Edit Form Dialog ───────────────────────────────────────────────────────
class _ReagentFormDialog extends StatefulWidget {
  final ReagentModel? existing;
  final List<Map<String, dynamic>> locations;
  const _ReagentFormDialog({this.existing, required this.locations});

  @override
  State<_ReagentFormDialog> createState() => _ReagentFormDialogState();
}

class _ReagentFormDialogState extends State<_ReagentFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _brandCtrl;
  late final TextEditingController _refCtrl;
  late final TextEditingController _casCtrl;
  late final TextEditingController _unitCtrl;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _qtyMinCtrl;
  late final TextEditingController _concCtrl;
  late final TextEditingController _lotCtrl;
  late final TextEditingController _supplierCtrl;
  late final TextEditingController _hazardCtrl;
  late final TextEditingController _responsibleCtrl;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _positionCtrl;
  String _type = 'chemical';
  String? _storageTemp;
  int? _locationId;
  DateTime? _expiryDate;
  DateTime? _receivedDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _brandCtrl = TextEditingController(text: e?.brand ?? '');
    _refCtrl = TextEditingController(text: e?.reference ?? '');
    _casCtrl = TextEditingController(text: e?.casNumber ?? '');
    _unitCtrl = TextEditingController(text: e?.unit ?? '');
    _qtyCtrl = TextEditingController(
        text: e?.quantity != null ? e!.quantity.toString() : '');
    _qtyMinCtrl = TextEditingController(
        text: e?.quantityMin != null ? e!.quantityMin.toString() : '');
    _concCtrl = TextEditingController(text: e?.concentration ?? '');
    _lotCtrl = TextEditingController(text: e?.lotNumber ?? '');
    _supplierCtrl = TextEditingController(text: e?.supplier ?? '');
    _hazardCtrl = TextEditingController(text: e?.hazard ?? '');
    _responsibleCtrl = TextEditingController(text: e?.responsible ?? '');
    _notesCtrl = TextEditingController(text: e?.notes ?? '');
    _positionCtrl = TextEditingController(text: e?.position ?? '');
    _type = e?.type ?? 'chemical';
    _storageTemp = e?.storageTemp;
    _locationId = e?.locationId;
    _expiryDate = e?.expiryDate;
    _receivedDate = e?.receivedDate;
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl, _brandCtrl, _refCtrl, _casCtrl, _unitCtrl,
      _qtyCtrl, _qtyMinCtrl, _concCtrl, _lotCtrl, _supplierCtrl,
      _hazardCtrl, _responsibleCtrl, _notesCtrl, _positionCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final data = {
        'reagent_name': _nameCtrl.text.trim(),
        'reagent_type': _type,
        if (_brandCtrl.text.isNotEmpty) 'reagent_brand': _brandCtrl.text.trim(),
        if (_refCtrl.text.isNotEmpty) 'reagent_reference': _refCtrl.text.trim(),
        if (_casCtrl.text.isNotEmpty) 'reagent_cas_number': _casCtrl.text.trim(),
        if (_unitCtrl.text.isNotEmpty) 'reagent_unit': _unitCtrl.text.trim(),
        if (_qtyCtrl.text.isNotEmpty)
          'reagent_quantity': double.tryParse(_qtyCtrl.text.trim()),
        if (_qtyMinCtrl.text.isNotEmpty)
          'reagent_quantity_min': double.tryParse(_qtyMinCtrl.text.trim()),
        if (_concCtrl.text.isNotEmpty)
          'reagent_concentration': _concCtrl.text.trim(),
        if (_storageTemp != null) 'reagent_storage_temp': _storageTemp,
        if (_locationId != null) 'reagent_location_id': _locationId,
        if (_positionCtrl.text.isNotEmpty)
          'reagent_position': _positionCtrl.text.trim(),
        if (_lotCtrl.text.isNotEmpty)
          'reagent_lot_number': _lotCtrl.text.trim(),
        if (_expiryDate != null)
          'reagent_expiry_date':
              _expiryDate!.toIso8601String().substring(0, 10),
        if (_receivedDate != null)
          'reagent_received_date':
              _receivedDate!.toIso8601String().substring(0, 10),
        if (_supplierCtrl.text.isNotEmpty)
          'reagent_supplier': _supplierCtrl.text.trim(),
        if (_hazardCtrl.text.isNotEmpty)
          'reagent_hazard': _hazardCtrl.text.trim(),
        if (_responsibleCtrl.text.isNotEmpty)
          'reagent_responsible': _responsibleCtrl.text.trim(),
        if (_notesCtrl.text.isNotEmpty) 'reagent_notes': _notesCtrl.text.trim(),
        'reagent_updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      if (widget.existing != null) {
        await Supabase.instance.client
            .from('reagents')
            .update(data)
            .eq('reagent_id', widget.existing!.id);
      } else {
        await Supabase.instance.client.from('reagents').insert(data);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to save: $e')));
      }
    }
  }

  Future<void> _pickDate(bool isExpiry) async {
    final now = DateTime.now();
    final initial = isExpiry
        ? (_expiryDate ?? now.add(const Duration(days: 365)))
        : (_receivedDate ?? now);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2040),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppDS.accent,
            surface: AppDS.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isExpiry) {
          _expiryDate = picked;
        } else {
          _receivedDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppDS.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(
          widget.existing != null ? 'Edit Reagent' : 'Add Reagent',
          style: GoogleFonts.spaceGrotesk(
              color: AppDS.textPrimary, fontWeight: FontWeight.w600)),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _field(_nameCtrl, 'Name *',
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Required' : null),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _field(_brandCtrl, 'Brand')),
                const SizedBox(width: 10),
                Expanded(child: _field(_refCtrl, 'Reference / Cat #')),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _field(_casCtrl, 'CAS Number')),
                const SizedBox(width: 10),
                Expanded(child: _dropdownField<String>(
                  label: 'Type',
                  value: _type,
                  items: ReagentModel.typeOptions.map((t) =>
                    DropdownMenuItem(value: t,
                      child: Text(ReagentModel.typeLabel(t),
                        style: GoogleFonts.spaceGrotesk(color: AppDS.textPrimary, fontSize: 13)))).toList(),
                  onChanged: (v) => setState(() => _type = v ?? 'chemical'),
                )),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _field(_qtyCtrl, 'Quantity',
                    keyboardType: TextInputType.number)),
                const SizedBox(width: 10),
                Expanded(child: _field(_unitCtrl, 'Unit (mL / g / …)')),
                const SizedBox(width: 10),
                Expanded(child: _field(_qtyMinCtrl, 'Min Qty (reorder)',
                    keyboardType: TextInputType.number)),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _field(_concCtrl, 'Concentration')),
                const SizedBox(width: 10),
                Expanded(child: _dropdownField<String?>(
                  label: 'Storage Temp',
                  value: _storageTemp,
                  items: [
                    DropdownMenuItem<String?>(value: null,
                      child: Text('—', style: GoogleFonts.spaceGrotesk(
                          color: AppDS.textMuted, fontSize: 13))),
                    ...ReagentModel.tempOptions.map((t) =>
                      DropdownMenuItem(value: t,
                        child: Text(t, style: GoogleFonts.spaceGrotesk(
                            color: AppDS.textPrimary, fontSize: 13)))),
                  ],
                  onChanged: (v) => setState(() => _storageTemp = v),
                )),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _dropdownField<int?>(
                  label: 'Location',
                  value: _locationId,
                  items: [
                    DropdownMenuItem<int?>(value: null,
                      child: Text('None', style: GoogleFonts.spaceGrotesk(
                          color: AppDS.textMuted, fontSize: 13))),
                    ...widget.locations.map((l) => DropdownMenuItem<int?>(
                      value: (l['location_id'] as num).toInt(),
                      child: Text(l['location_name'] as String,
                        style: GoogleFonts.spaceGrotesk(
                            color: AppDS.textPrimary, fontSize: 13)))),
                  ],
                  onChanged: (v) => setState(() => _locationId = v),
                )),
                const SizedBox(width: 10),
                Expanded(child: _field(_positionCtrl, 'Position in location')),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _field(_lotCtrl, 'Lot Number')),
                const SizedBox(width: 10),
                Expanded(child: _datePicker('Expiry Date', _expiryDate,
                    () => _pickDate(true))),
                const SizedBox(width: 10),
                Expanded(child: _datePicker('Received Date', _receivedDate,
                    () => _pickDate(false))),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _field(_supplierCtrl, 'Supplier')),
                const SizedBox(width: 10),
                Expanded(child: _field(_responsibleCtrl, 'Responsible')),
              ]),
              const SizedBox(height: 10),
              _field(_hazardCtrl, 'Hazard codes (e.g. H225 H302)'),
              const SizedBox(height: 10),
              _field(_notesCtrl, 'Notes', maxLines: 3),
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: Text('Cancel',
              style: GoogleFonts.spaceGrotesk(color: AppDS.textSecondary)),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFF59E0B),
            foregroundColor: Colors.black,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(widget.existing != null ? 'Save' : 'Create',
                  style: GoogleFonts.spaceGrotesk()),
        ),
      ],
    );
  }

  Widget _field(TextEditingController ctrl, String label,
      {int maxLines = 1,
      TextInputType? keyboardType,
      String? Function(String?)? validator}) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      style:
          GoogleFonts.spaceGrotesk(color: AppDS.textPrimary, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.spaceGrotesk(
            color: AppDS.textSecondary, fontSize: 12),
        filled: true,
        fillColor: AppDS.surface3,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppDS.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppDS.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppDS.accent)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }

  Widget _dropdownField<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.spaceGrotesk(
            color: AppDS.textSecondary, fontSize: 12),
        filled: true,
        fillColor: AppDS.surface3,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppDS.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppDS.border)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          dropdownColor: AppDS.surface,
          style: GoogleFonts.spaceGrotesk(
              color: AppDS.textPrimary, fontSize: 13),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _datePicker(String label, DateTime? date, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppDS.surface3,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppDS.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: GoogleFonts.spaceGrotesk(
                  color: AppDS.textSecondary, fontSize: 11)),
          const SizedBox(height: 2),
          Text(
            date != null
                ? date.toIso8601String().substring(0, 10)
                : 'Select date',
            style: GoogleFonts.spaceGrotesk(
                color: date != null ? AppDS.textPrimary : AppDS.textMuted,
                fontSize: 13),
          ),
        ]),
      ),
    );
  }
}
