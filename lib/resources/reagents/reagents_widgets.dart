// reagents_widgets.dart - Part of reagents_page.dart.
// _ReagentRow: list tile with expiry/stock indicators.
// _RowBtn, _Badge, _FilterChip: small UI atoms.
// _ReagentFormDialog: add/edit reagent form dialog.
part of 'reagents_page.dart';

// ─── Reagent Row ───────────────────────────────────────────────────────────────
class _ReagentRow extends StatelessWidget {
  final ReagentModel reagent;
  final VoidCallback onTap;
  final VoidCallback onRequest;

  const _ReagentRow({
    required this.reagent,
    required this.onTap,
    required this.onRequest,
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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: context.appBorder)),
            color: r.isExpired
                ? AppDS.red.withValues(alpha: 0.04)
                : context.appSurface,
          ),
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            // ── Actions ──────────────────────────────────────────────────
            _RowBtn(Icons.open_in_new, 'View detail', onTap),
            _RowBtn(Icons.outbox_outlined, 'Quick Request', onRequest),
            const SizedBox(width: 4),
            // ── Code ─────────────────────────────────────────────────────
            Expanded(
              flex: 1,
              child: r.code != null && r.code!.isNotEmpty
                  ? Text(r.code!,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.jetBrainsMono(
                          color: AppDS.accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w600))
                  : const SizedBox.shrink(),
            ),
            // ── Name ─────────────────────────────────────────────────────
            Expanded(
              flex: 4,
              child: Row(children: [
                Flexible(
                  child: Text(r.name,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.spaceGrotesk(
                          color: context.appTextPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                ),
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
            // ── Type ─────────────────────────────────────────────────────
            Expanded(
              flex: 2,
              child: _Badge(label: ReagentModel.typeLabel(r.type), color: accent),
            ),
            // ── Location ─────────────────────────────────────────────────
            Expanded(
              flex: 2,
              child: Text(
                r.locationName ?? '—',
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.spaceGrotesk(
                    color: context.appTextSecondary, fontSize: 12),
              ),
            ),
            // ── Brand ────────────────────────────────────────────────────
            Expanded(
              flex: 2,
              child: Text(
                r.brand ?? '—',
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.spaceGrotesk(
                    color: context.appTextSecondary, fontSize: 12),
              ),
            ),
            // ── Size (concentration) ──────────────────────────────────────
            Expanded(
              flex: 1,
              child: Text(
                r.concentration ?? '—',
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.jetBrainsMono(
                    color: context.appTextSecondary, fontSize: 11),
              ),
            ),
            // ── Unit ─────────────────────────────────────────────────────
            Expanded(
              flex: 1,
              child: Text(
                r.unit ?? '—',
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.spaceGrotesk(
                    color: context.appTextSecondary, fontSize: 12),
              ),
            ),
            // ── Amount ───────────────────────────────────────────────────
            Expanded(
              flex: 1,
              child: Text(
                r.quantity != null ? r.quantity.toString() : '—',
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.jetBrainsMono(
                    color: r.isLowStock
                        ? AppDS.orange
                        : context.appTextSecondary,
                    fontSize: 12),
              ),
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
      icon: Icon(icon, size: 15, color: color ?? context.appTextSecondary),
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
  late final TextEditingController _codeCtrl;
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
    _codeCtrl = TextEditingController(text: e?.code ?? '');
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
      _codeCtrl, _nameCtrl, _brandCtrl, _refCtrl, _casCtrl, _unitCtrl,
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
        'reagent_code': _codeCtrl.text.trim().isEmpty ? null : _codeCtrl.text.trim(),
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
      backgroundColor: context.appSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(
          widget.existing != null ? 'Edit Reagent' : 'Add Reagent',
          style: GoogleFonts.spaceGrotesk(
              color: context.appTextPrimary, fontWeight: FontWeight.w600)),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Expanded(
                  flex: 2,
                  child: _field(context, _nameCtrl, 'Name *',
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null)),
                const SizedBox(width: 10),
                Expanded(
                  flex: 1,
                  child: _field(context, _codeCtrl, 'Code (e.g. BR001)')),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _field(context, _brandCtrl, 'Brand')),
                const SizedBox(width: 10),
                Expanded(child: _field(context, _refCtrl, 'Reference / Cat #')),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _field(context, _casCtrl, 'CAS Number')),
                const SizedBox(width: 10),
                Expanded(child: _dropdownField<String>(context,
                  label: 'Type',
                  value: _type,
                  items: ReagentModel.typeOptions.map((t) =>
                    DropdownMenuItem(value: t,
                      child: Text(ReagentModel.typeLabel(t),
                        style: GoogleFonts.spaceGrotesk(color: context.appTextPrimary, fontSize: 13)))).toList(),
                  onChanged: (v) => setState(() => _type = v ?? 'chemical'),
                )),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _field(context, _qtyCtrl, 'Quantity',
                    keyboardType: TextInputType.number)),
                const SizedBox(width: 10),
                Expanded(child: _field(context, _unitCtrl, 'Unit (mL / g / …)')),
                const SizedBox(width: 10),
                Expanded(child: _field(context, _qtyMinCtrl, 'Min Qty (reorder)',
                    keyboardType: TextInputType.number)),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _field(context, _concCtrl, 'Concentration')),
                const SizedBox(width: 10),
                Expanded(child: _dropdownField<String?>(context,
                  label: 'Storage Temp',
                  value: _storageTemp,
                  items: [
                    DropdownMenuItem<String?>(value: null,
                      child: Text('—', style: GoogleFonts.spaceGrotesk(
                          color: context.appTextMuted, fontSize: 13))),
                    ...ReagentModel.tempOptions.map((t) =>
                      DropdownMenuItem(value: t,
                        child: Text(t, style: GoogleFonts.spaceGrotesk(
                            color: context.appTextPrimary, fontSize: 13)))),
                  ],
                  onChanged: (v) => setState(() => _storageTemp = v),
                )),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _dropdownField<int?>(context,
                  label: 'Location',
                  value: _locationId,
                  items: [
                    DropdownMenuItem<int?>(value: null,
                      child: Text('None', style: GoogleFonts.spaceGrotesk(
                          color: context.appTextMuted, fontSize: 13))),
                    ...widget.locations.map((l) => DropdownMenuItem<int?>(
                      value: (l['location_id'] as num).toInt(),
                      child: Text(l['location_name'] as String,
                        style: GoogleFonts.spaceGrotesk(
                            color: context.appTextPrimary, fontSize: 13)))),
                  ],
                  onChanged: (v) => setState(() => _locationId = v),
                )),
                const SizedBox(width: 10),
                Expanded(child: _field(context, _positionCtrl, 'Position in location')),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _field(context, _lotCtrl, 'Lot Number')),
                const SizedBox(width: 10),
                Expanded(child: _datePicker(context, 'Expiry Date', _expiryDate,
                    () => _pickDate(true))),
                const SizedBox(width: 10),
                Expanded(child: _datePicker(context, 'Received Date', _receivedDate,
                    () => _pickDate(false))),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _field(context, _supplierCtrl, 'Supplier')),
                const SizedBox(width: 10),
                Expanded(child: _field(context, _responsibleCtrl, 'Responsible')),
              ]),
              const SizedBox(height: 10),
              _field(context, _hazardCtrl, 'Hazard codes (e.g. H225 H302)'),
              const SizedBox(height: 10),
              _field(context, _notesCtrl, 'Notes', maxLines: 3),
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: Text('Cancel',
              style: GoogleFonts.spaceGrotesk(color: context.appTextSecondary)),
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

  Widget _field(BuildContext context, TextEditingController ctrl, String label,
      {int maxLines = 1,
      TextInputType? keyboardType,
      String? Function(String?)? validator}) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      style:
          GoogleFonts.spaceGrotesk(color: context.appTextPrimary, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.spaceGrotesk(
            color: context.appTextSecondary, fontSize: 12),
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }

  Widget _dropdownField<T>(BuildContext context, {
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.spaceGrotesk(
            color: context.appTextSecondary, fontSize: 12),
        filled: true,
        fillColor: context.appSurface3,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: context.appBorder)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: context.appBorder)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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

  Widget _datePicker(BuildContext context, String label, DateTime? date, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: context.appSurface3,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: context.appBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: GoogleFonts.spaceGrotesk(
                  color: context.appTextSecondary, fontSize: 11)),
          const SizedBox(height: 2),
          Text(
            date != null
                ? date.toIso8601String().substring(0, 10)
                : 'Select date',
            style: GoogleFonts.spaceGrotesk(
                color: date != null ? context.appTextPrimary : context.appTextMuted,
                fontSize: 13),
          ),
        ]),
      ),
    );
  }
}
