// reservations_widgets.dart - Part of reservations_page.dart.
// _ReservationCard: list card for a booking with status badge.
// _Badge, _ListSectionHeader, _ViewToggleBtn: small UI atoms.
// _ReservationFormDialog: new/edit reservation form dialog.
part of 'reservations_page.dart';

// ─── Reservation Card ──────────────────────────────────────────────────────────
class _ReservationCard extends StatelessWidget {
  final ReservationModel reservation;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool past;

  const _ReservationCard({
    required this.reservation,
    required this.onEdit,
    required this.onDelete,
    this.past = false,
  });

  @override
  Widget build(BuildContext context) {
    final r = reservation;
    final sc = r.statusColor;
    final durationH = r.duration.inHours;
    final durationM = r.duration.inMinutes % 60;
    final durationStr = durationH > 0
        ? '${durationH}h${durationM > 0 ? ' ${durationM}m' : ''}'
        : '${durationM}m';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: context.appSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: past
                  ? context.appBorder
                  : r.isOngoing
                      ? AppDS.accent.withValues(alpha: 0.5)
                      : sc.withValues(alpha: 0.3)),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          // Left accent bar for ongoing
          if (r.isOngoing)
            Container(
              width: 3,
              height: 40,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: AppDS.accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(
                      child: Text(
                        r.resourceName ?? r.resourceType,
                        style: GoogleFonts.spaceGrotesk(
                            color: past
                                ? context.appTextSecondary
                                : context.appTextPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _Badge(label: r.status, color: sc),
                    if (r.isOngoing) ...[
                      const SizedBox(width: 6),
                      _Badge(label: 'ONGOING', color: AppDS.accent),
                    ],
                  ]),
                  const SizedBox(height: 4),
                  Text(
                    '${_fmtDt(r.start)} → ${_fmtDt(r.end)}  ·  $durationStr',
                    style: GoogleFonts.spaceGrotesk(
                        color: context.appTextSecondary, fontSize: 12),
                  ),
                  if (r.purpose != null || r.project != null)
                    Text(
                      [
                        if (r.purpose != null) r.purpose!,
                        if (r.project != null) '(${r.project})',
                      ].join(' '),
                      style: GoogleFonts.spaceGrotesk(
                          color: context.appTextMuted, fontSize: 11),
                    ),
                ]),
          ),
          Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(
                icon: Icon(Icons.edit_outlined,
                    size: 16, color: context.appTextSecondary),
                tooltip: 'Edit',
                onPressed: onEdit),
            IconButton(
                icon: Icon(Icons.delete_outline,
                    size: 16, color: context.appTextSecondary),
                tooltip: 'Delete',
                onPressed: onDelete),
          ]),
        ]),
      ),
    );
  }

  String _fmtDt(DateTime d) =>
      '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label,
            style: GoogleFonts.spaceGrotesk(color: color, fontSize: 10)),
      );
}

class _ListSectionHeader extends StatelessWidget {
  final String title;
  const _ListSectionHeader(this.title);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(title,
            style: GoogleFonts.spaceGrotesk(
                color: context.appTextSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8)),
      );
}

class _ViewToggleBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ViewToggleBtn(
      {required this.icon,
      required this.label,
      required this.active,
      required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFFEC4899).withValues(alpha: 0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon,
                size: 14,
                color:
                    active ? const Color(0xFFEC4899) : context.appTextSecondary),
            const SizedBox(width: 5),
            Text(label,
                style: GoogleFonts.spaceGrotesk(
                    color:
                        active ? const Color(0xFFEC4899) : context.appTextSecondary,
                    fontSize: 12,
                    fontWeight:
                        active ? FontWeight.w600 : FontWeight.normal)),
          ]),
        ),
      );
}

// ─── New / Edit Reservation Dialog ─────────────────────────────────────────────
class _ReservationFormDialog extends StatefulWidget {
  final ReservationModel? existing;
  final List<Map<String, dynamic>> equipment;
  final List<ReservationModel> allReservations;
  final int? prefillResourceId;
  final String? prefillResourceName;

  const _ReservationFormDialog({
    this.existing,
    required this.equipment,
    required this.allReservations,
    this.prefillResourceId,
    this.prefillResourceName,
  });

  @override
  State<_ReservationFormDialog> createState() =>
      _ReservationFormDialogState();
}

class _ReservationFormDialogState extends State<_ReservationFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _purposeCtrl;
  late final TextEditingController _projectCtrl;
  late final TextEditingController _notesCtrl;

  String _resourceType = 'equipment';
  int? _resourceId;
  String? _resourceName;
  String _status = 'confirmed';
  DateTime _start = DateTime.now().add(const Duration(hours: 1));
  DateTime _end = DateTime.now().add(const Duration(hours: 3));
  bool _saving = false;
  String? _conflictError;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _purposeCtrl = TextEditingController(text: e?.purpose ?? '');
    _projectCtrl = TextEditingController(text: e?.project ?? '');
    _notesCtrl = TextEditingController(text: e?.notes ?? '');
    _resourceType = e?.resourceType ?? 'equipment';
    _resourceId   = e?.resourceId   ?? widget.prefillResourceId;
    _resourceName = e?.resourceName ?? widget.prefillResourceName;
    _status = e?.status ?? 'confirmed';
    if (e != null) {
      _start = e.start;
      _end = e.end;
    }
  }

  @override
  void dispose() {
    _purposeCtrl.dispose();
    _projectCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  bool _checkConflict() {
    if (_resourceId == null) return false;
    final conflicts = widget.allReservations.where((r) {
      if (r.resourceType != _resourceType) return false;
      if (r.resourceId != _resourceId) return false;
      if (r.status == 'cancelled') return false;
      // Exclude self when editing
      if (widget.existing != null && r.id == widget.existing!.id) return false;
      // Overlap: start < other.end AND end > other.start
      return _start.isBefore(r.end) && _end.isAfter(r.start);
    }).toList();
    return conflicts.isNotEmpty;
  }

  Future<void> _pickDateTime(bool isStart) async {
    final initial = isStart ? _start : _end;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
                primary: Color(0xFFEC4899), surface: AppDS.surface)),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
                primary: Color(0xFFEC4899), surface: AppDS.surface)),
        child: child!,
      ),
    );
    if (time == null) return;

    final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isStart) {
        _start = dt;
        if (_end.isBefore(_start)) {
          _end = _start.add(const Duration(hours: 1));
        }
      } else {
        _end = dt;
      }
      _conflictError = _checkConflict()
          ? 'Conflict: this machine is already booked during this time.'
          : null;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_end.isBefore(_start) || _end.isAtSameMomentAs(_start)) {
      setState(() => _conflictError = 'End must be after start.');
      return;
    }
    if (_checkConflict()) {
      setState(() => _conflictError =
          'Conflict: this machine is already booked during this time.');
      return;
    }
    setState(() { _saving = true; _conflictError = null; });
    try {
      final data = {
        'reservation_resource_type': _resourceType,
        'reservation_start': _start.toUtc().toIso8601String(),
        'reservation_end': _end.toUtc().toIso8601String(),
        'reservation_status': _status,
        if (_resourceId != null) 'reservation_resource_id': _resourceId,
        if (_resourceName != null) 'reservation_resource_name': _resourceName,
        if (_purposeCtrl.text.isNotEmpty)
          'reservation_purpose': _purposeCtrl.text.trim(),
        if (_projectCtrl.text.isNotEmpty)
          'reservation_project': _projectCtrl.text.trim(),
        if (_notesCtrl.text.isNotEmpty)
          'reservation_notes': _notesCtrl.text.trim(),
        'reservation_updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      if (widget.existing != null) {
        await Supabase.instance.client
            .from('reservations')
            .update(data)
            .eq('reservation_id', widget.existing!.id);
      } else {
        await Supabase.instance.client
            .from('reservations')
            .insert(data);
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
          widget.existing != null
              ? 'Edit Reservation'
              : 'New Reservation',
          style: GoogleFonts.spaceGrotesk(
              color: context.appTextPrimary, fontWeight: FontWeight.w600)),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Equipment selector
              _dd<int?>(context,
                label: 'Machine / Equipment',
                value: _resourceId,
                items: [
                  DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Select machine…',
                          style: GoogleFonts.spaceGrotesk(
                              color: context.appTextMuted, fontSize: 13))),
                  ...widget.equipment.map((e) => DropdownMenuItem<int?>(
                        value: (e['equipment_id'] as num).toInt(),
                        child: Text(e['equipment_name'] as String,
                            style: GoogleFonts.spaceGrotesk(
                                color: context.appTextPrimary, fontSize: 13)),
                      )),
                ],
                onChanged: (v) {
                  setState(() {
                    _resourceId = v;
                    if (v != null) {
                      final match = widget.equipment.firstWhere(
                          (e) => (e['equipment_id'] as num).toInt() == v,
                          orElse: () => {});
                      _resourceName = match['equipment_name'] as String?;
                    } else {
                      _resourceName = null;
                    }
                    _conflictError = _checkConflict()
                        ? 'Conflict: this machine is already booked during this time.'
                        : null;
                  });
                },
              ),

              const SizedBox(height: 12),

              // Date/time pickers
              Row(children: [
                Expanded(child: _dtPicker(context, 'Start', _start, () => _pickDateTime(true))),
                const SizedBox(width: 10),
                Expanded(child: _dtPicker(context, 'End', _end, () => _pickDateTime(false))),
              ]),

              // Conflict error
              if (_conflictError != null) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppDS.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: AppDS.red.withValues(alpha: 0.4)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.warning_amber_outlined,
                        color: AppDS.red, size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(_conflictError!,
                          style: GoogleFonts.spaceGrotesk(
                              color: AppDS.red, fontSize: 12)),
                    ),
                  ]),
                ),
              ],

              const SizedBox(height: 12),

              // Status
              _dd<String>(context,
                label: 'Status',
                value: _status,
                items: ReservationModel.statusOptions
                    .map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(
                              s[0].toUpperCase() + s.substring(1),
                              style: GoogleFonts.spaceGrotesk(
                                  color: context.appTextPrimary, fontSize: 13)),
                        ))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _status = v ?? 'confirmed'),
              ),

              const SizedBox(height: 10),
              _f(context, _purposeCtrl, 'Purpose'),
              const SizedBox(height: 10),
              _f(context, _projectCtrl, 'Project'),
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
            backgroundColor: const Color(0xFFEC4899),
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

  Widget _f(BuildContext context, TextEditingController ctrl, String label,
      {int maxLines = 1, String? Function(String?)? validator}) =>
      TextFormField(
        controller: ctrl,
        maxLines: maxLines,
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
              borderSide: const BorderSide(color: Color(0xFFEC4899))),
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

  Widget _dtPicker(BuildContext context, String label, DateTime dt, VoidCallback onTap) =>
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
                  '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}',
                  style: GoogleFonts.spaceGrotesk(
                      color: context.appTextPrimary, fontSize: 13),
                ),
              ]),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Quick reservation entry point — callable from machine detail page
// ─────────────────────────────────────────────────────────────────────────────

Future<void> showMachineQuickReservationDialog(
  BuildContext context, {
  required int machineId,
  required String machineName,
}) async {
  List<Map<String, dynamic>> equipment = [];
  List<ReservationModel> allReservations = [];
  try {
    final eq = await Supabase.instance.client
        .from('equipment').select('equipment_id, equipment_name');
    equipment = List<Map<String, dynamic>>.from(eq);
  } catch (_) {}
  if (!context.mounted) return;
  try {
    final res = await Supabase.instance.client.from('reservations').select();
    allReservations = res
        .map((r) => ReservationModel.fromMap(Map<String, dynamic>.from(r)))
        .toList();
  } catch (_) {}
  if (!context.mounted) return;
  await showDialog<bool>(
    context: context,
    builder: (_) => _ReservationFormDialog(
      equipment: equipment,
      allReservations: allReservations,
      prefillResourceId: machineId,
      prefillResourceName: machineName,
    ),
  );
}
