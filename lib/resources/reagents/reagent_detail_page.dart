// reagent_detail_page.dart - Reagent editor: inline fields for all reagent
// properties, date pickers, location & type dropdowns, QR code display.
// Pushed via Navigator with its own Scaffold + AppBar.
// Light and dark theme

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide LocalStorage;
import '../../backups/backup_service.dart';
import '../../supabase/supabase_manager.dart';
import '/theme/theme.dart';
import 'reagent_model.dart';
import '../../requests/requests_page.dart';
import '../../camera/qr_scanner/qr_code_rules.dart';

class ReagentDetailPage extends StatefulWidget {
  final int reagentId;
  const ReagentDetailPage({super.key, required this.reagentId});

  @override
  State<ReagentDetailPage> createState() => _ReagentDetailPageState();
}

class _ReagentDetailPageState extends State<ReagentDetailPage> {
  ReagentModel? _reagent;
  List<Map<String, dynamic>> _allLocations = [];
  bool _loading = true;
  bool _saving  = false;
  final Set<int> _expanded = {0, 1, 2, 3, 4};

  // Controllers
  late final TextEditingController _codeCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _brandCtrl;
  late final TextEditingController _supplierCtrl;
  late final TextEditingController _responsibleCtrl;
  late final TextEditingController _referenceCtrl;
  late final TextEditingController _casCtrl;
  late final TextEditingController _lotCtrl;
  late final TextEditingController _concentrationCtrl;
  late final TextEditingController _formulaCtrl;
  late final TextEditingController _hazardCtrl;
  late final TextEditingController _quantityCtrl;
  late final TextEditingController _unitCtrl;
  late final TextEditingController _quantityMinCtrl;
  late final TextEditingController _positionCtrl;
  late final TextEditingController _notesCtrl;

  // Dropdown / date state
  String  _type          = 'biological';
  String? _physicalState;
  String? _storageTemp;
  int?    _locationId;
  DateTime? _expiryDate;
  DateTime? _receivedDate;
  DateTime? _openedDate;

  @override
  void initState() {
    super.initState();
    _codeCtrl          = TextEditingController();
    _nameCtrl          = TextEditingController();
    _brandCtrl         = TextEditingController();
    _supplierCtrl      = TextEditingController();
    _responsibleCtrl   = TextEditingController();
    _referenceCtrl     = TextEditingController();
    _casCtrl           = TextEditingController();
    _lotCtrl           = TextEditingController();
    _concentrationCtrl = TextEditingController();
    _formulaCtrl       = TextEditingController();
    _hazardCtrl        = TextEditingController();
    _quantityCtrl      = TextEditingController();
    _unitCtrl          = TextEditingController();
    _quantityMinCtrl   = TextEditingController();
    _positionCtrl      = TextEditingController();
    _notesCtrl         = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _brandCtrl.dispose();
    _supplierCtrl.dispose();
    _responsibleCtrl.dispose();
    _referenceCtrl.dispose();
    _casCtrl.dispose();
    _lotCtrl.dispose();
    _concentrationCtrl.dispose();
    _formulaCtrl.dispose();
    _hazardCtrl.dispose();
    _quantityCtrl.dispose();
    _unitCtrl.dispose();
    _quantityMinCtrl.dispose();
    _positionCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  // ── Data ───────────────────────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        Supabase.instance.client
            .from('reagents')
            .select('*, location:reagent_location_id(location_name)')
            .eq('reagent_id', widget.reagentId)
            .limit(1),
        Supabase.instance.client
            .from('storage_locations')
            .select('location_id, location_name')
            .order('location_name'),
      ]);

      final rows     = results[0] as List<dynamic>;
      final locRows  = results[1] as List<dynamic>;

      if (rows.isEmpty) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final r       = rows[0] as Map<String, dynamic>;
      final locData = r['location'];
      final reagent = ReagentModel.fromMap({
        ...r,
        'location_name': locData is Map ? locData['location_name'] as String? : null,
      });

      if (mounted) {
        _codeCtrl.text          = reagent.code ?? '';
        _nameCtrl.text          = reagent.name ?? '';
        _brandCtrl.text         = reagent.brand ?? '';
        _supplierCtrl.text      = reagent.supplier ?? '';
        _responsibleCtrl.text   = reagent.responsible ?? '';
        _referenceCtrl.text     = reagent.reference ?? '';
        _casCtrl.text           = reagent.casNumber ?? '';
        _lotCtrl.text           = reagent.lotNumber ?? '';
        _concentrationCtrl.text = reagent.concentration ?? '';
        _formulaCtrl.text       = reagent.formula ?? '';
        _hazardCtrl.text        = reagent.hazard ?? '';
        _quantityCtrl.text      = reagent.quantity?.toString() ?? '';
        _unitCtrl.text          = reagent.unit ?? '';
        _quantityMinCtrl.text   = reagent.quantityMin?.toString() ?? '';
        _positionCtrl.text      = reagent.position ?? '';
        _notesCtrl.text         = reagent.notes ?? '';
        _type          = reagent.type;
        _physicalState = reagent.physicalState;
        _storageTemp   = reagent.storageTemp;
        _locationId  = reagent.locationId;
        _expiryDate  = reagent.expiryDate;
        _receivedDate = reagent.receivedDate;
        _openedDate  = reagent.openedDate;

        setState(() {
          _reagent      = reagent;
          _allLocations = List<Map<String, dynamic>>.from(locRows);
          _loading      = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _snack('Failed to load: $e');
      }
    }
  }

  Future<void> _save() async {
    if (_codeCtrl.text.trim().isEmpty) { _snack('Code is required'); return; }
    setState(() => _saving = true);
    try {
      final data = <String, dynamic>{
        'reagent_code':         _codeCtrl.text.trim(),
        'reagent_name':         _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
        'reagent_type':           _type,
        'reagent_physical_state': _physicalState,
        'reagent_brand':          _brandCtrl.text.trim().isEmpty ? null : _brandCtrl.text.trim(),
        'reagent_supplier':     _supplierCtrl.text.trim().isEmpty     ? null : _supplierCtrl.text.trim(),
        'reagent_responsible':  _responsibleCtrl.text.trim().isEmpty  ? null : _responsibleCtrl.text.trim(),
        'reagent_reference':    _referenceCtrl.text.trim().isEmpty    ? null : _referenceCtrl.text.trim(),
        'reagent_cas_number':   _casCtrl.text.trim().isEmpty          ? null : _casCtrl.text.trim(),
        'reagent_lot_number':   _lotCtrl.text.trim().isEmpty          ? null : _lotCtrl.text.trim(),
        'reagent_concentration':_concentrationCtrl.text.trim().isEmpty? null : _concentrationCtrl.text.trim(),
        'reagent_formula':      _formulaCtrl.text.trim().isEmpty      ? null : _formulaCtrl.text.trim(),
        'reagent_hazard':       _hazardCtrl.text.trim().isEmpty       ? null : _hazardCtrl.text.trim(),
        'reagent_quantity':     double.tryParse(_quantityCtrl.text.trim()),
        'reagent_unit':         _unitCtrl.text.trim().isEmpty         ? null : _unitCtrl.text.trim(),
        'reagent_quantity_min': double.tryParse(_quantityMinCtrl.text.trim()),
        'reagent_storage_temp': _storageTemp,
        'reagent_location_id':  _locationId,
        'reagent_position':     _positionCtrl.text.trim().isEmpty     ? null : _positionCtrl.text.trim(),
        'reagent_expiry_date':  _expiryDate?.toIso8601String().substring(0, 10),
        'reagent_received_date':_receivedDate?.toIso8601String().substring(0, 10),
        'reagent_opened_date':  _openedDate?.toIso8601String().substring(0, 10),
        'reagent_notes':        _notesCtrl.text.trim().isEmpty        ? null : _notesCtrl.text.trim(),
        'reagent_qrcode':       QrRules.build(SupabaseManager.projectRef ?? 'local', 'reagents', widget.reagentId),
      };
      await Supabase.instance.client
          .from('reagents')
          .update(data)
          .eq('reagent_id', widget.reagentId);
      unawaited(BackupService.instance.notifyCrudChange('reagents'));
      await _load();
      _snack('Saved');
    } catch (e) {
      _snack('Save failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate(DateTime? current, void Function(DateTime?) onPicked) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) onPicked(picked);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.appSurface,
        title: Text('Delete reagent?',
            style: GoogleFonts.spaceGrotesk(color: ctx.appTextPrimary)),
        content: Text(
          'This will permanently delete "${_reagent?.name}". This cannot be undone.',
          style: GoogleFonts.spaceGrotesk(color: ctx.appTextSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.spaceGrotesk(color: ctx.appTextSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete',
                style: GoogleFonts.spaceGrotesk(color: AppDS.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await Supabase.instance.client
          .from('reagents')
          .delete()
          .eq('reagent_id', widget.reagentId);
      unawaited(BackupService.instance.notifyCrudChange('reagents'));
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      _snack('Delete failed: $e');
    }
  }

  Color _physicalStateColor(String s) => switch (s) {
        'liquid' => const Color(0xFF38BDF8),
        'solid'  => const Color(0xFF94A3B8),
        'gas'    => const Color(0xFFA78BFA),
        _        => const Color(0xFF64748B),
      };

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppDS.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final r = _reagent;
    return Scaffold(
      backgroundColor: context.appBg,
      appBar: AppBar(
        backgroundColor: context.appSurface2,
        foregroundColor: context.appTextPrimary,
        elevation: 0,
        title: Text(
          r?.name ?? 'Reagent',
          style: GoogleFonts.spaceGrotesk(
              color: context.appTextPrimary, fontWeight: FontWeight.w600),
        ),
        actions: [
          if (r != null) ...[
            IconButton(
              icon: const Icon(Icons.outbox_outlined, size: 20),
              tooltip: 'Quick Request',
              onPressed: () => showQuickRequestDialog(
                context,
                type: 'reagents',
                prefillTitle: r.name ?? '',
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20, color: AppDS.red),
              tooltip: 'Delete',
              onPressed: _delete,
            ),
            _saving
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppDS.accent)))
                : TextButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save_outlined, size: 16, color: AppDS.accent),
                    label: Text('Save',
                        style: GoogleFonts.spaceGrotesk(color: AppDS.accent)),
                  ),
          ],
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : r == null
              ? Center(
                  child: Text('Reagent not found',
                      style: GoogleFonts.spaceGrotesk(color: context.appTextMuted)))
              : _buildBody(context, r),
    );
  }

  Widget _buildBody(BuildContext context, ReagentModel r) {
    final typeAccentMap = <String, Color>{
      'biological':           const Color(0xFF22C55E),
      'consumables':          const Color(0xFFF59E0B),
      'ppe':                  const Color(0xFFF97316),
      'bioactivity_assays':   const Color(0xFF8B5CF6),
      'analytical_chemistry': const Color(0xFF06B6D4),
      'media_preparation':    const Color(0xFF10B981),
      'cleaning_maintenance': const Color(0xFF94A3B8),
      'standards':            const Color(0xFF86b0d3),
      // legacy
      'chemical': const Color(0xFF38BDF8),
      'kit':      const Color(0xFF8B5CF6),
      'media':    const Color(0xFF10B981),
      'gas':      const Color(0xFF64748B),
      'consumable': const Color(0xFFF59E0B),
    };
    final accent = typeAccentMap[r.type] ?? AppDS.accent;
    final qrData = 'bluelims://${SupabaseManager.projectRef ?? 'local'}/reagents/${r.id}';

    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // ── Header ────────────────────────────────────────────────────────────
        _buildHeader(context, r, accent, qrData),

        // ── Sections ──────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            _Section(
              index: 0,
              title: 'REAGENT DETAILS',
              icon: Icons.science_outlined,
              expanded: _expanded.contains(0),
              onToggle: () => setState(() =>
                  _expanded.contains(0) ? _expanded.remove(0) : _expanded.add(0)),
              child: _buildDetailsSection(context),
            ),
            _Section(
              index: 1,
              title: 'IDENTIFICATION',
              icon: Icons.fingerprint_outlined,
              expanded: _expanded.contains(1),
              onToggle: () => setState(() =>
                  _expanded.contains(1) ? _expanded.remove(1) : _expanded.add(1)),
              child: _buildIdentificationSection(context),
            ),
            _Section(
              index: 2,
              title: 'STOCK & STORAGE',
              icon: Icons.inventory_2_outlined,
              expanded: _expanded.contains(2),
              onToggle: () => setState(() =>
                  _expanded.contains(2) ? _expanded.remove(2) : _expanded.add(2)),
              child: _buildStockSection(context),
            ),
            _Section(
              index: 3,
              title: 'DATES',
              icon: Icons.calendar_today_outlined,
              expanded: _expanded.contains(3),
              onToggle: () => setState(() =>
                  _expanded.contains(3) ? _expanded.remove(3) : _expanded.add(3)),
              child: _buildDatesSection(context),
            ),
            _Section(
              index: 4,
              title: 'NOTES',
              icon: Icons.notes_rounded,
              expanded: _expanded.contains(4),
              onToggle: () => setState(() =>
                  _expanded.contains(4) ? _expanded.remove(4) : _expanded.add(4)),
              child: _InlineField(
                  label: 'Notes', controller: _notesCtrl, maxLines: 4),
            ),
          ]),
        ),
      ]),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, ReagentModel r, Color accent, String qrData) {
    return Container(
      color: context.appSurface2,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GestureDetector(
          onTap: () => _showQr(r),
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.all(10),
            child: QrImageView(data: qrData, size: 110),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.name ?? '—',
                style: GoogleFonts.spaceGrotesk(
                    color: context.appTextPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700)),
            if (r.brand != null) ...[
              const SizedBox(height: 2),
              Text(r.brand!,
                  style: GoogleFonts.spaceGrotesk(
                      color: context.appTextSecondary, fontSize: 13)),
            ],
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 4, children: [
              _Badge(label: ReagentModel.typeLabel(r.type), color: accent),
              if (r.physicalState != null)
                _Badge(
                  label: ReagentModel.physicalStateLabel(r.physicalState!),
                  color: _physicalStateColor(r.physicalState!),
                ),
              if (r.isExpired)      _Badge(label: 'Expired',       color: AppDS.red),
              if (r.isExpiringSoon && !r.isExpired)
                                    _Badge(label: 'Expiring soon', color: AppDS.yellow),
              if (r.isLowStock)     _Badge(label: 'Low stock',     color: AppDS.orange),
              if (r.hazard != null && r.hazard!.isNotEmpty)
                                    _Badge(label: r.hazard!,       color: AppDS.yellow),
            ]),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: qrData));
                _snack('Link copied');
              },
              child: Text(qrData,
                  style: GoogleFonts.jetBrainsMono(
                      color: context.appTextMuted, fontSize: 10)),
            ),
          ]),
        ),
      ]),
    );
  }

  // ── Section bodies ─────────────────────────────────────────────────────────

  Widget _buildDetailsSection(BuildContext context) {
    return Column(children: [
      _FieldRow(children: [
        _InlineField(label: 'Name', controller: _nameCtrl),
        _InlineDropdown<String>(
          label: 'Type',
          value: _type,
          items: ReagentModel.typeOptions
              .map((t) => DropdownMenuItem(
                    value: t,
                    child: Text(ReagentModel.typeLabel(t),
                        style: GoogleFonts.spaceGrotesk(
                            color: context.appTextPrimary, fontSize: 13)),
                  ))
              .toList(),
          onChanged: (v) => setState(() => _type = v ?? 'biological'),
        ),
      ]),
      const SizedBox(height: 10),
      _FieldRow(children: [
        _InlineDropdown<String?>(
          label: 'Physical State',
          value: _physicalState,
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text('—',
                  style: GoogleFonts.spaceGrotesk(
                      color: context.appTextMuted, fontSize: 13)),
            ),
            ...ReagentModel.physicalStateOptions.map((s) => DropdownMenuItem<String?>(
                  value: s,
                  child: Text(ReagentModel.physicalStateLabel(s),
                      style: GoogleFonts.spaceGrotesk(
                          color: context.appTextPrimary, fontSize: 13)),
                )),
          ],
          onChanged: (v) => setState(() => _physicalState = v),
        ),
        _InlineField(label: 'Brand', controller: _brandCtrl),
      ]),
      const SizedBox(height: 10),
      _FieldRow(children: [
        _InlineField(label: 'Supplier', controller: _supplierCtrl),
        _InlineField(label: 'Responsible', controller: _responsibleCtrl),
      ]),
    ]);
  }

  Widget _buildIdentificationSection(BuildContext context) {
    return Column(children: [
      _FieldRow(children: [
        _InlineField(label: 'Code * (e.g. BR001)', controller: _codeCtrl),
        _InlineField(label: 'Reference', controller: _referenceCtrl),
        _InlineField(label: 'CAS Number', controller: _casCtrl),
      ]),
      const SizedBox(height: 10),
      _FieldRow(children: [
        _InlineField(label: 'Lot Number', controller: _lotCtrl),
        _InlineField(label: 'Concentration', controller: _concentrationCtrl),
      ]),
      const SizedBox(height: 10),
      _FieldRow(children: [
        _InlineField(label: 'Formula', controller: _formulaCtrl),
        _InlineField(label: 'Hazard', controller: _hazardCtrl),
      ]),
    ]);
  }

  Widget _buildStockSection(BuildContext context) {
    return Column(children: [
      _FieldRow(children: [
        _InlineField(
            label: 'Quantity',
            controller: _quantityCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true)),
        _InlineField(label: 'Unit', controller: _unitCtrl),
      ]),
      const SizedBox(height: 10),
      _FieldRow(children: [
        _InlineField(
            label: 'Reorder threshold',
            controller: _quantityMinCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true)),
        _InlineDropdown<String?>(
          label: 'Storage Temp',
          value: _storageTemp,
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text('—', style: GoogleFonts.spaceGrotesk(
                  color: context.appTextMuted, fontSize: 13)),
            ),
            ...ReagentModel.tempOptions.map((t) => DropdownMenuItem<String?>(
                  value: t,
                  child: Text(t, style: GoogleFonts.spaceGrotesk(
                      color: context.appTextPrimary, fontSize: 13)),
                )),
          ],
          onChanged: (v) => setState(() => _storageTemp = v),
        ),
      ]),
      const SizedBox(height: 10),
      _FieldRow(children: [
        _InlineDropdown<int?>(
          label: 'Location',
          value: _locationId,
          items: [
            DropdownMenuItem<int?>(
              value: null,
              child: Text('None', style: GoogleFonts.spaceGrotesk(
                  color: context.appTextMuted, fontSize: 13)),
            ),
            ..._allLocations.map((l) => DropdownMenuItem<int?>(
                  value: (l['location_id'] as num).toInt(),
                  child: Text(l['location_name'] as String,
                      style: GoogleFonts.spaceGrotesk(
                          color: context.appTextPrimary, fontSize: 13)),
                )),
          ],
          onChanged: (v) => setState(() => _locationId = v),
        ),
        _InlineField(label: 'Position', controller: _positionCtrl),
      ]),
    ]);
  }

  Widget _buildDatesSection(BuildContext context) {
    return Column(children: [
      _FieldRow(children: [
        _DateField(
          label: 'Expiry Date',
          date: _expiryDate,
          onTap: () => _pickDate(_expiryDate, (d) => setState(() => _expiryDate = d)),
          onClear: () => setState(() => _expiryDate = null),
          danger: _reagent?.isExpired == true,
          warning: _reagent?.isExpiringSoon == true && _reagent?.isExpired == false,
        ),
        _DateField(
          label: 'Received',
          date: _receivedDate,
          onTap: () => _pickDate(_receivedDate, (d) => setState(() => _receivedDate = d)),
          onClear: () => setState(() => _receivedDate = null),
        ),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
          child: _DateField(
            label: 'Opened',
            date: _openedDate,
            onTap: () => _pickDate(_openedDate, (d) => setState(() => _openedDate = d)),
            onClear: () => setState(() => _openedDate = null),
          ),
        ),
        const Expanded(child: SizedBox()),
      ]),
    ]);
  }

  // ── QR dialog ──────────────────────────────────────────────────────────────

  void _showQr(ReagentModel r) {
    final ref  = SupabaseManager.projectRef ?? 'local';
    final data = 'bluelims://$ref/reagents/${r.id}';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.appSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('QR — ${r.name}',
            style: GoogleFonts.spaceGrotesk(color: ctx.appTextPrimary)),
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
                    color: ctx.appTextMuted, fontSize: 11)),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: data));
              if (context.mounted) Navigator.pop(ctx);
              _snack('Link copied');
            },
            child: Text('Copy Link',
                style: GoogleFonts.spaceGrotesk(color: AppDS.accent)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Close',
                style: GoogleFonts.spaceGrotesk(color: ctx.appTextSecondary)),
          ),
        ],
      ),
    );
  }

}

// ─── Collapsible Section ─────────────────────────────────────────────────────
class _Section extends StatelessWidget {
  final int index;
  final String title;
  final IconData icon;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;

  const _Section({
    required this.index,
    required this.title,
    required this.icon,
    required this.expanded,
    required this.onToggle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.appBorder),
      ),
      child: Column(children: [
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.vertical(
            top: const Radius.circular(10),
            bottom: Radius.circular(expanded ? 0 : 10),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: context.appSurface2,
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(10),
                bottom: Radius.circular(expanded ? 0 : 10),
              ),
            ),
            child: Row(children: [
              Icon(icon, size: 14, color: AppDS.accent),
              const SizedBox(width: 8),
              Text(title,
                  style: GoogleFonts.spaceGrotesk(
                      color: context.appTextSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8)),
              const Spacer(),
              Icon(expanded ? Icons.expand_less : Icons.expand_more,
                  size: 18, color: context.appTextMuted),
            ]),
          ),
        ),
        if (expanded) ...[
          Divider(height: 1, color: context.appBorder),
          Padding(padding: const EdgeInsets.all(14), child: child),
        ],
      ]),
    );
  }
}

// ─── Layout helpers ──────────────────────────────────────────────────────────
class _FieldRow extends StatelessWidget {
  final List<Widget> children;
  const _FieldRow({required this.children});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: children
          .expand((w) => [Expanded(child: w), const SizedBox(width: 10)])
          .toList()
        ..removeLast(),
    );
  }
}

class _InlineField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final int maxLines;
  final TextInputType? keyboardType;

  const _InlineField({
    required this.label,
    required this.controller,
    this.maxLines = 1,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: GoogleFonts.spaceGrotesk(color: context.appTextPrimary, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.spaceGrotesk(
            color: context.appTextSecondary, fontSize: 11),
        filled: true,
        fillColor: context.appSurface3,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: context.appBorder)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: context.appBorder)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppDS.accent)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}

class _InlineDropdown<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final void Function(T?) onChanged;

  const _InlineDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.spaceGrotesk(
            color: context.appTextSecondary, fontSize: 11),
        filled: true,
        fillColor: context.appSurface3,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: context.appBorder)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: context.appBorder)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          dropdownColor: context.appSurface,
          style: GoogleFonts.spaceGrotesk(
              color: context.appTextPrimary, fontSize: 13),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  final VoidCallback onClear;
  final bool danger;
  final bool warning;

  const _DateField({
    required this.label,
    required this.date,
    required this.onTap,
    required this.onClear,
    this.danger  = false,
    this.warning = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppDS.red : warning ? AppDS.yellow : AppDS.accent;
    return GestureDetector(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.spaceGrotesk(
              color: context.appTextSecondary, fontSize: 11),
          filled: true,
          fillColor: context.appSurface3,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                  color: (danger || warning) ? color.withValues(alpha: 0.5) : context.appBorder)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                  color: (danger || warning) ? color.withValues(alpha: 0.5) : context.appBorder)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          suffixIcon: date != null
              ? GestureDetector(
                  onTap: onClear,
                  child: Icon(Icons.clear, size: 16, color: context.appTextMuted))
              : const Icon(Icons.calendar_today_outlined, size: 14),
        ),
        child: Text(
          date != null
              ? '${date!.year}-${date!.month.toString().padLeft(2, '0')}-${date!.day.toString().padLeft(2, '0')}'
              : '—',
          style: GoogleFonts.spaceGrotesk(
              color: date != null ? (danger || warning ? color : context.appTextPrimary) : context.appTextMuted,
              fontSize: 13),
        ),
      ),
    );
  }
}

// ─── Badges ──────────────────────────────────────────────────────────────────
class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label,
            style: GoogleFonts.spaceGrotesk(color: color, fontSize: 11)),
      );
}
