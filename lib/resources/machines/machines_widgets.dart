// machines_widgets.dart - Part of machines_page.dart.
// _MachineRow: table row for a single machine.
// _StatusBadge, _SmallBadge, _RowBtn, _Chip: small UI atoms.
// _MachineFormDialog: add/edit machine form dialog.
part of 'machines_page.dart';

// ─── Machine Row ──────────────────────────────────────────────────────────────
class _MachineRow extends StatelessWidget {
  final MachineModel machine;
  final VoidCallback onTap;
  final VoidCallback onDetail;
  final VoidCallback onReserve;

  const _MachineRow({
    required this.machine,
    required this.onTap,
    required this.onDetail,
    required this.onReserve,
  });

  @override
  Widget build(BuildContext context) {
    final m = machine;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: context.appBorder)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            // ── Actions ──────────────────────────────────────────────────
            _RowBtn(icon: Icons.open_in_new, tooltip: 'View detail', onTap: onDetail),
            _RowBtn(icon: Icons.event_available_outlined, tooltip: 'Quick Reservation', onTap: onReserve),
            const SizedBox(width: 4),
            Expanded(
              flex: 5,
              child: Row(children: [
                Flexible(
                  child: Text(m.name,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.spaceGrotesk(
                          color: context.appTextPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 8),
                _StatusBadge(status: m.status),
                if (m.maintenanceOverdue) ...[
                  const SizedBox(width: 4),
                  _SmallBadge(label: 'Overdue', color: AppDS.red),
                ] else if (m.maintenanceDueSoon) ...[
                  const SizedBox(width: 4),
                  _SmallBadge(label: 'Due soon', color: AppDS.yellow),
                ],
              ]),
            ),
            Expanded(
              flex: 3,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (m.type != null)
                    Text(m.type!,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.spaceGrotesk(
                            color: context.appTextPrimary, fontSize: 12)),
                  if (m.brand != null || m.model != null)
                    Text(
                      '${m.brand ?? ''}${m.brand != null && m.model != null ? ' · ' : ''}${m.model ?? ''}',
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.spaceGrotesk(
                          color: context.appTextSecondary, fontSize: 11),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: m.locationName != null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.locationName!,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.spaceGrotesk(
                                color: context.appTextPrimary, fontSize: 12)),
                        if (m.room != null)
                          Text(m.room!,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.spaceGrotesk(
                                  color: context.appTextSecondary,
                                  fontSize: 11)),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
            Expanded(
              flex: 2,
              child: m.nextMaintenance != null
                  ? Text(
                      m.nextMaintenance!.toIso8601String().substring(0, 10),
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.jetBrainsMono(
                          color: m.maintenanceOverdue
                              ? AppDS.red
                              : m.maintenanceDueSoon
                                  ? AppDS.yellow
                                  : context.appTextSecondary,
                          fontSize: 11),
                    )
                  : Text('—',
                      style: GoogleFonts.spaceGrotesk(
                          color: context.appTextMuted, fontSize: 12)),
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
  final VoidCallback onTap;
  const _RowBtn(
      {required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: IconButton(
          icon: Icon(icon, size: 16),
          color: context.appTextSecondary,
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          onPressed: onTap,
        ),
      );
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status.toLowerCase()) {
      'operational' => AppDS.green,
      'maintenance' => AppDS.orange,
      'broken' => AppDS.red,
      'retired' => AppDS.textMuted,
      _ => AppDS.textSecondary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(MachineModel.statusLabel(status),
          style: GoogleFonts.spaceGrotesk(color: color, fontSize: 11)),
    );
  }
}

class _SmallBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _SmallBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label,
            style: GoogleFonts.spaceGrotesk(color: color, fontSize: 10)),
      );
}


class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _Chip(
      {required this.label,
      required this.selected,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color:
                selected ? color.withValues(alpha: 0.18) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: selected ? color : context.appBorder,
                width: selected ? 1.5 : 1),
          ),
          child: Text(label,
              style: GoogleFonts.spaceGrotesk(
                  color: selected ? color : context.appTextSecondary,
                  fontSize: 12,
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.normal)),
        ),
      );
}

// ─── Add/Edit Machine Dialog ────────────────────────────────────────────────────
class _MachineFormDialog extends StatefulWidget {
  final MachineModel? existing;
  final List<Map<String, dynamic>> locations;
  const _MachineFormDialog({this.existing, required this.locations});

  @override
  State<_MachineFormDialog> createState() => _MachineFormDialogState();
}

class _MachineFormDialogState extends State<_MachineFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _typeCtrl;
  late final TextEditingController _brandCtrl;
  late final TextEditingController _modelCtrl;
  late final TextEditingController _serialCtrl;
  late final TextEditingController _patrimonyCtrl;
  late final TextEditingController _roomCtrl;
  late final TextEditingController _responsibleCtrl;
  late final TextEditingController _supplierCtrl;
  late final TextEditingController _manualCtrl;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _maintIntervalCtrl;
  late final TextEditingController _calIntervalCtrl;
  String _status = 'operational';
  int? _locationId;
  DateTime? _purchaseDate;
  DateTime? _warrantyUntil;
  DateTime? _lastMaintenance;
  DateTime? _nextMaintenance;
  DateTime? _lastCalibration;
  DateTime? _nextCalibration;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _typeCtrl = TextEditingController(text: e?.type ?? '');
    _brandCtrl = TextEditingController(text: e?.brand ?? '');
    _modelCtrl = TextEditingController(text: e?.model ?? '');
    _serialCtrl = TextEditingController(text: e?.serialNumber ?? '');
    _patrimonyCtrl = TextEditingController(text: e?.patrimonyNumber ?? '');
    _roomCtrl = TextEditingController(text: e?.room ?? '');
    _responsibleCtrl = TextEditingController(text: e?.responsible ?? '');
    _supplierCtrl = TextEditingController(text: e?.supplier ?? '');
    _manualCtrl = TextEditingController(text: e?.manualLink ?? '');
    _notesCtrl = TextEditingController(text: e?.notes ?? '');
    _maintIntervalCtrl = TextEditingController(
        text: e?.maintenanceIntervalDays?.toString() ?? '');
    _calIntervalCtrl = TextEditingController(
        text: e?.calibrationIntervalDays?.toString() ?? '');
    _status = e?.status ?? 'operational';
    _locationId = e?.locationId;
    _purchaseDate = e?.purchaseDate;
    _warrantyUntil = e?.warrantyUntil;
    _lastMaintenance = e?.lastMaintenance;
    _nextMaintenance = e?.nextMaintenance;
    _lastCalibration = e?.lastCalibration;
    _nextCalibration = e?.nextCalibration;
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl, _typeCtrl, _brandCtrl, _modelCtrl, _serialCtrl,
      _patrimonyCtrl, _roomCtrl, _responsibleCtrl, _supplierCtrl,
      _manualCtrl, _notesCtrl, _maintIntervalCtrl, _calIntervalCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate(String field) async {
    final now = DateTime.now();
    final initial = switch (field) {
      'purchase' => _purchaseDate ?? now,
      'warranty' => _warrantyUntil ?? now.add(const Duration(days: 365)),
      'lastMaint' => _lastMaintenance ?? now,
      'nextMaint' => _nextMaintenance ?? now.add(const Duration(days: 180)),
      'lastCal' => _lastCalibration ?? now,
      'nextCal' => _nextCalibration ?? now.add(const Duration(days: 365)),
      _ => now,
    };
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2040),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
                primary: AppDS.accent, surface: AppDS.surface)),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      switch (field) {
        case 'purchase': _purchaseDate = picked;
        case 'warranty': _warrantyUntil = picked;
        case 'lastMaint': _lastMaintenance = picked;
        case 'nextMaint': _nextMaintenance = picked;
        case 'lastCal': _lastCalibration = picked;
        case 'nextCal': _nextCalibration = picked;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final data = {
        'equipment_name': _nameCtrl.text.trim(),
        'equipment_status': _status,
        if (_typeCtrl.text.isNotEmpty) 'equipment_type': _typeCtrl.text.trim(),
        if (_brandCtrl.text.isNotEmpty)
          'equipment_brand': _brandCtrl.text.trim(),
        if (_modelCtrl.text.isNotEmpty)
          'equipment_model': _modelCtrl.text.trim(),
        if (_serialCtrl.text.isNotEmpty)
          'equipment_serial_number': _serialCtrl.text.trim(),
        if (_patrimonyCtrl.text.isNotEmpty)
          'equipment_patrimony_number': _patrimonyCtrl.text.trim(),
        if (_locationId != null) 'equipment_location_id': _locationId,
        if (_roomCtrl.text.isNotEmpty) 'equipment_room': _roomCtrl.text.trim(),
        if (_purchaseDate != null)
          'equipment_purchase_date':
              _purchaseDate!.toIso8601String().substring(0, 10),
        if (_warrantyUntil != null)
          'equipment_warranty_until':
              _warrantyUntil!.toIso8601String().substring(0, 10),
        if (_lastMaintenance != null)
          'equipment_last_maintenance':
              _lastMaintenance!.toIso8601String().substring(0, 10),
        if (_nextMaintenance != null)
          'equipment_next_maintenance':
              _nextMaintenance!.toIso8601String().substring(0, 10),
        if (_maintIntervalCtrl.text.isNotEmpty)
          'equipment_maintenance_interval_days':
              int.tryParse(_maintIntervalCtrl.text.trim()),
        if (_lastCalibration != null)
          'equipment_last_calibration':
              _lastCalibration!.toIso8601String().substring(0, 10),
        if (_nextCalibration != null)
          'equipment_next_calibration':
              _nextCalibration!.toIso8601String().substring(0, 10),
        if (_calIntervalCtrl.text.isNotEmpty)
          'equipment_calibration_interval_days':
              int.tryParse(_calIntervalCtrl.text.trim()),
        if (_responsibleCtrl.text.isNotEmpty)
          'equipment_responsible': _responsibleCtrl.text.trim(),
        if (_supplierCtrl.text.isNotEmpty)
          'equipment_supplier': _supplierCtrl.text.trim(),
        if (_manualCtrl.text.isNotEmpty)
          'equipment_manual_link': _manualCtrl.text.trim(),
        if (_notesCtrl.text.isNotEmpty)
          'equipment_notes': _notesCtrl.text.trim(),
      };

      if (widget.existing != null) {
        await Supabase.instance.client
            .from('equipment')
            .update(data)
            .eq('equipment_id', widget.existing!.id);
      } else {
        final row = await Supabase.instance.client
            .from('equipment')
            .insert(data)
            .select('equipment_id')
            .single();
        final newId = row['equipment_id'] as int;
        await Supabase.instance.client
            .from('equipment')
            .update({'equipment_qrcode': QrRules.build(
                SupabaseManager.projectRef ?? 'local', 'machines', newId)})
            .eq('equipment_id', newId);
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.appSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(
          widget.existing != null ? 'Edit Machine' : 'Add Machine',
          style: GoogleFonts.spaceGrotesk(
              color: context.appTextPrimary, fontWeight: FontWeight.w600)),
      content: SizedBox(
        width: 580,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _f(context, _nameCtrl, 'Name *',
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Required' : null),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _f(context, _typeCtrl, 'Type (e.g. Centrifuge)')),
                const SizedBox(width: 10),
                Expanded(child: _dd<String>(context,
                  label: 'Status',
                  value: _status,
                  items: MachineModel.statusOptions
                      .map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(MachineModel.statusLabel(s),
                              style: GoogleFonts.spaceGrotesk(
                                  color: context.appTextPrimary, fontSize: 13))))
                      .toList(),
                  onChanged: (v) => setState(() => _status = v ?? 'operational'),
                )),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _f(context, _brandCtrl, 'Brand')),
                const SizedBox(width: 10),
                Expanded(child: _f(context, _modelCtrl, 'Model')),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _f(context, _serialCtrl, 'Serial Number')),
                const SizedBox(width: 10),
                Expanded(child: _f(context, _patrimonyCtrl, 'Patrimony Number')),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _dd<int?>(context,
                  label: 'Location',
                  value: _locationId,
                  items: [
                    DropdownMenuItem<int?>(
                        value: null,
                        child: Text('None',
                            style: GoogleFonts.spaceGrotesk(
                                color: context.appTextMuted, fontSize: 13))),
                    ...widget.locations.map((l) => DropdownMenuItem<int?>(
                          value: (l['location_id'] as num).toInt(),
                          child: Text(l['location_name'] as String,
                              style: GoogleFonts.spaceGrotesk(
                                  color: context.appTextPrimary, fontSize: 13)),
                        )),
                  ],
                  onChanged: (v) => setState(() => _locationId = v),
                )),
                const SizedBox(width: 10),
                Expanded(child: _f(context, _roomCtrl, 'Room')),
              ]),
              const SizedBox(height: 10),
              _sectionLabel(context, 'Maintenance'),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(
                    child: _dp(context, 'Last Maintenance', _lastMaintenance,
                        () => _pickDate('lastMaint'))),
                const SizedBox(width: 10),
                Expanded(
                    child: _dp(context, 'Next Maintenance', _nextMaintenance,
                        () => _pickDate('nextMaint'))),
                const SizedBox(width: 10),
                Expanded(
                    child: _f(context, _maintIntervalCtrl, 'Interval (days)',
                        keyboardType: TextInputType.number)),
              ]),
              const SizedBox(height: 10),
              _sectionLabel(context, 'Calibration'),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(
                    child: _dp(context, 'Last Calibration', _lastCalibration,
                        () => _pickDate('lastCal'))),
                const SizedBox(width: 10),
                Expanded(
                    child: _dp(context, 'Next Calibration', _nextCalibration,
                        () => _pickDate('nextCal'))),
                const SizedBox(width: 10),
                Expanded(
                    child: _f(context, _calIntervalCtrl, 'Interval (days)',
                        keyboardType: TextInputType.number)),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                    child: _dp(context, 'Purchase Date', _purchaseDate,
                        () => _pickDate('purchase'))),
                const SizedBox(width: 10),
                Expanded(
                    child: _dp(context, 'Warranty Until', _warrantyUntil,
                        () => _pickDate('warranty'))),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _f(context, _responsibleCtrl, 'Responsible')),
                const SizedBox(width: 10),
                Expanded(child: _f(context, _supplierCtrl, 'Supplier')),
              ]),
              const SizedBox(height: 10),
              _f(context, _manualCtrl, 'Manual Link (URL)'),
              const SizedBox(height: 10),
              _f(context, _notesCtrl, 'Notes', maxLines: 3),
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
            backgroundColor: const Color(0xFF14B8A6),
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

  Widget _sectionLabel(BuildContext context, String t) => Align(
        alignment: Alignment.centerLeft,
        child: Text(t,
            style: GoogleFonts.spaceGrotesk(
                color: context.appTextSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6)),
      );

  Widget _f(BuildContext context, TextEditingController ctrl, String label,
      {int maxLines = 1,
      TextInputType? keyboardType,
      String? Function(String?)? validator}) =>
      TextFormField(
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

  Widget _dd<T>(BuildContext context, {
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) =>
      InputDecorator(
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

  Widget _dp(BuildContext context, String label, DateTime? date, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: context.appSurface3,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: context.appBorder),
          ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.spaceGrotesk(
                        color: context.appTextSecondary, fontSize: 11)),
                const SizedBox(height: 2),
                Text(
                    date != null
                        ? date.toIso8601String().substring(0, 10)
                        : 'Select date',
                    style: GoogleFonts.spaceGrotesk(
                        color:
                            date != null ? context.appTextPrimary : context.appTextMuted,
                        fontSize: 13)),
              ]),
        ),
      );
}
