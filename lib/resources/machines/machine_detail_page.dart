// machine_detail_page.dart - Machine editor: inline fields for all equipment
// properties, date pickers, location & status dropdowns, reservations list.
// Pushed via Navigator with its own Scaffold + AppBar.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide LocalStorage;
import '../../supabase/supabase_manager.dart';
import '/theme/theme.dart';
import 'machine_model.dart';
import '../reservations/reservation_model.dart';
import '../reservations/reservations_page.dart';

class MachineDetailPage extends StatefulWidget {
  final int machineId;
  const MachineDetailPage({super.key, required this.machineId});

  @override
  State<MachineDetailPage> createState() => _MachineDetailPageState();
}

class _MachineDetailPageState extends State<MachineDetailPage> {
  MachineModel?           _machine;
  List<ReservationModel>  _reservations  = [];
  List<Map<String, dynamic>> _allLocations = [];
  bool _loading = true;
  bool _saving  = false;
  final Set<int> _expanded = {0, 1, 2, 3, 4, 5, 6};

  // Controllers
  late final TextEditingController _nameCtrl;
  late final TextEditingController _typeCtrl;
  late final TextEditingController _brandCtrl;
  late final TextEditingController _modelCtrl;
  late final TextEditingController _serialCtrl;
  late final TextEditingController _patrimonyCtrl;
  late final TextEditingController _roomCtrl;
  late final TextEditingController _supplierCtrl;
  late final TextEditingController _responsibleCtrl;
  late final TextEditingController _manualCtrl;
  late final TextEditingController _maintIntervalCtrl;
  late final TextEditingController _calibIntervalCtrl;
  late final TextEditingController _notesCtrl;

  // Dropdown / date state
  String    _status     = 'operational';
  int?      _locationId;
  DateTime? _purchaseDate;
  DateTime? _warrantyDate;
  DateTime? _lastMaintenance;
  DateTime? _nextMaintenance;
  DateTime? _lastCalibration;
  DateTime? _nextCalibration;

  @override
  void initState() {
    super.initState();
    _nameCtrl         = TextEditingController();
    _typeCtrl         = TextEditingController();
    _brandCtrl        = TextEditingController();
    _modelCtrl        = TextEditingController();
    _serialCtrl       = TextEditingController();
    _patrimonyCtrl    = TextEditingController();
    _roomCtrl         = TextEditingController();
    _supplierCtrl     = TextEditingController();
    _responsibleCtrl  = TextEditingController();
    _manualCtrl       = TextEditingController();
    _maintIntervalCtrl= TextEditingController();
    _calibIntervalCtrl= TextEditingController();
    _notesCtrl        = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _typeCtrl.dispose();
    _brandCtrl.dispose();
    _modelCtrl.dispose();
    _serialCtrl.dispose();
    _patrimonyCtrl.dispose();
    _roomCtrl.dispose();
    _supplierCtrl.dispose();
    _responsibleCtrl.dispose();
    _manualCtrl.dispose();
    _maintIntervalCtrl.dispose();
    _calibIntervalCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  // ── Data ───────────────────────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        Supabase.instance.client
            .from('equipment')
            .select('*, location:equipment_location_id(location_name)')
            .eq('equipment_id', widget.machineId)
            .limit(1),
        Supabase.instance.client
            .from('reservations')
            .select()
            .eq('reservation_resource_type', 'equipment')
            .eq('reservation_resource_id', widget.machineId)
            .order('reservation_start', ascending: false)
            .limit(20),
        Supabase.instance.client
            .from('storage_locations')
            .select('location_id, location_name')
            .order('location_name'),
      ]);

      final rows    = results[0] as List<dynamic>;
      final resRows = results[1] as List<dynamic>;
      final locRows = results[2] as List<dynamic>;

      if (rows.isEmpty) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final r       = rows[0] as Map<String, dynamic>;
      final locData = r['location'];
      final machine = MachineModel.fromMap({
        ...r,
        'location_name': locData is Map ? locData['location_name'] as String? : null,
      });

      if (mounted) {
        _nameCtrl.text          = machine.name;
        _typeCtrl.text          = machine.type ?? '';
        _brandCtrl.text         = machine.brand ?? '';
        _modelCtrl.text         = machine.model ?? '';
        _serialCtrl.text        = machine.serialNumber ?? '';
        _patrimonyCtrl.text     = machine.patrimonyNumber ?? '';
        _roomCtrl.text          = machine.room ?? '';
        _supplierCtrl.text      = machine.supplier ?? '';
        _responsibleCtrl.text   = machine.responsible ?? '';
        _manualCtrl.text        = machine.manualLink ?? '';
        _maintIntervalCtrl.text = machine.maintenanceIntervalDays?.toString() ?? '';
        _calibIntervalCtrl.text = machine.calibrationIntervalDays?.toString() ?? '';
        _notesCtrl.text         = machine.notes ?? '';
        _status          = machine.status;
        _locationId      = machine.locationId;
        _purchaseDate    = machine.purchaseDate;
        _warrantyDate    = machine.warrantyUntil;
        _lastMaintenance = machine.lastMaintenance;
        _nextMaintenance = machine.nextMaintenance;
        _lastCalibration = machine.lastCalibration;
        _nextCalibration = machine.nextCalibration;

        setState(() {
          _machine      = machine;
          _reservations = resRows.map<ReservationModel>((r) => ReservationModel.fromMap(r as Map<String, dynamic>)).toList();
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
    if (_nameCtrl.text.trim().isEmpty) { _snack('Name is required'); return; }
    setState(() => _saving = true);
    try {
      final data = <String, dynamic>{
        'equipment_name':                    _nameCtrl.text.trim(),
        'equipment_status':                  _status,
        'equipment_type':                    _typeCtrl.text.trim().isEmpty          ? null : _typeCtrl.text.trim(),
        'equipment_brand':                   _brandCtrl.text.trim().isEmpty         ? null : _brandCtrl.text.trim(),
        'equipment_model':                   _modelCtrl.text.trim().isEmpty         ? null : _modelCtrl.text.trim(),
        'equipment_serial_number':           _serialCtrl.text.trim().isEmpty        ? null : _serialCtrl.text.trim(),
        'equipment_patrimony_number':        _patrimonyCtrl.text.trim().isEmpty     ? null : _patrimonyCtrl.text.trim(),
        'equipment_location_id':             _locationId,
        'equipment_room':                    _roomCtrl.text.trim().isEmpty          ? null : _roomCtrl.text.trim(),
        'equipment_supplier':                _supplierCtrl.text.trim().isEmpty      ? null : _supplierCtrl.text.trim(),
        'equipment_responsible':             _responsibleCtrl.text.trim().isEmpty   ? null : _responsibleCtrl.text.trim(),
        'equipment_manual_link':             _manualCtrl.text.trim().isEmpty        ? null : _manualCtrl.text.trim(),
        'equipment_maintenance_interval_days': int.tryParse(_maintIntervalCtrl.text.trim()),
        'equipment_calibration_interval_days': int.tryParse(_calibIntervalCtrl.text.trim()),
        'equipment_purchase_date':           _purchaseDate?.toIso8601String().substring(0, 10),
        'equipment_warranty_until':          _warrantyDate?.toIso8601String().substring(0, 10),
        'equipment_last_maintenance':        _lastMaintenance?.toIso8601String().substring(0, 10),
        'equipment_next_maintenance':        _nextMaintenance?.toIso8601String().substring(0, 10),
        'equipment_last_calibration':        _lastCalibration?.toIso8601String().substring(0, 10),
        'equipment_next_calibration':        _nextCalibration?.toIso8601String().substring(0, 10),
        'equipment_notes':                   _notesCtrl.text.trim().isEmpty         ? null : _notesCtrl.text.trim(),
      };
      await Supabase.instance.client
          .from('equipment')
          .update(data)
          .eq('equipment_id', widget.machineId);
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
    final name = _machine?.name ?? 'this machine';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.appSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Delete Machine?',
            style: GoogleFonts.spaceGrotesk(
                color: ctx.appTextPrimary, fontWeight: FontWeight.w600)),
        content: Text(
          'This will permanently delete "$name". This cannot be undone.',
          style: GoogleFonts.spaceGrotesk(
              color: ctx.appTextSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.spaceGrotesk(color: ctx.appTextSecondary)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppDS.red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: GoogleFonts.spaceGrotesk()),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await Supabase.instance.client
          .from('equipment')
          .delete()
          .eq('equipment_id', widget.machineId);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _snack('Delete failed: $e');
    }
  }

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
    final m = _machine;
    return Scaffold(
      backgroundColor: context.appBg,
      appBar: AppBar(
        backgroundColor: context.appSurface2,
        foregroundColor: context.appTextPrimary,
        elevation: 0,
        title: Text(
          m?.name ?? 'Machine',
          style: GoogleFonts.spaceGrotesk(
              color: context.appTextPrimary, fontWeight: FontWeight.w600),
        ),
        actions: [
          if (m != null) ...[
            IconButton(
              icon: const Icon(Icons.qr_code, size: 20),
              tooltip: 'QR Code',
              onPressed: () => _showQr(m),
            ),
            IconButton(
              icon: const Icon(Icons.event_available_outlined, size: 20),
              tooltip: 'Quick Reservation',
              onPressed: () => showMachineQuickReservationDialog(
                context,
                machineId: m.id,
                machineName: m.name,
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
          : m == null
              ? Center(
                  child: Text('Machine not found',
                      style: GoogleFonts.spaceGrotesk(color: context.appTextMuted)))
              : _buildBody(context, m),
    );
  }

  Widget _buildBody(BuildContext context, MachineModel m) {
    final sc     = m.statusColor;
    final qrData = 'bluelims://${SupabaseManager.projectRef ?? 'local'}/machines/${m.id}';
    final upcoming = _reservations
        .where((r) => r.start.isAfter(DateTime.now()) || r.isOngoing)
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    final past = _reservations
        .where((r) => r.end.isBefore(DateTime.now()))
        .toList();

    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // ── Header ────────────────────────────────────────────────────────────
        _buildHeader(context, m, sc, qrData),

        // ── Sections ──────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            _Section(
              index: 0,
              title: 'MACHINE DETAILS',
              icon: Icons.precision_manufacturing_outlined,
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
              title: 'LOCATION',
              icon: Icons.place_outlined,
              expanded: _expanded.contains(2),
              onToggle: () => setState(() =>
                  _expanded.contains(2) ? _expanded.remove(2) : _expanded.add(2)),
              child: _buildLocationSection(context),
            ),
            _Section(
              index: 3,
              title: 'MAINTENANCE & CALIBRATION',
              icon: Icons.build_outlined,
              expanded: _expanded.contains(3),
              onToggle: () => setState(() =>
                  _expanded.contains(3) ? _expanded.remove(3) : _expanded.add(3)),
              child: _buildMaintenanceSection(context, m),
            ),
            _Section(
              index: 4,
              title: 'PURCHASE & WARRANTY',
              icon: Icons.receipt_long_outlined,
              expanded: _expanded.contains(4),
              onToggle: () => setState(() =>
                  _expanded.contains(4) ? _expanded.remove(4) : _expanded.add(4)),
              child: _buildPurchaseSection(context),
            ),
            _Section(
              index: 5,
              title: 'NOTES',
              icon: Icons.notes_rounded,
              expanded: _expanded.contains(5),
              onToggle: () => setState(() =>
                  _expanded.contains(5) ? _expanded.remove(5) : _expanded.add(5)),
              child: _InlineField(
                  label: 'Notes', controller: _notesCtrl, maxLines: 4),
            ),
            _Section(
              index: 6,
              title: 'RESERVATIONS (${_reservations.length})',
              icon: Icons.event_outlined,
              expanded: _expanded.contains(6),
              onToggle: () => setState(() =>
                  _expanded.contains(6) ? _expanded.remove(6) : _expanded.add(6)),
              child: _buildReservationsSection(context, upcoming, past),
            ),
          ]),
        ),
      ]),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, MachineModel m, Color sc, String qrData) {
    return Container(
      color: context.appSurface2,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GestureDetector(
          onTap: () => _showQr(m),
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.all(10),
            child: QrImageView(data: qrData, size: 110),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(m.name,
                style: GoogleFonts.spaceGrotesk(
                    color: context.appTextPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700)),
            if (m.brand != null || m.model != null) ...[
              const SizedBox(height: 2),
              Text(
                [if (m.brand != null) m.brand!, if (m.model != null) m.model!].join(' · '),
                style: GoogleFonts.spaceGrotesk(
                    color: context.appTextSecondary, fontSize: 13)),
            ],
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 4, children: [
              _StatusBadge(status: m.status, color: sc),
              if (m.maintenanceOverdue)
                _SmallBadge(label: 'Maintenance overdue', color: AppDS.red),
              if (m.maintenanceDueSoon && !m.maintenanceOverdue)
                _SmallBadge(label: 'Maintenance due soon', color: AppDS.yellow),
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
        _InlineField(label: 'Name *', controller: _nameCtrl),
        _InlineDropdown<String>(
          label: 'Status',
          value: _status,
          items: MachineModel.statusOptions
              .map((s) => DropdownMenuItem(
                    value: s,
                    child: Text(MachineModel.statusLabel(s),
                        style: GoogleFonts.spaceGrotesk(
                            color: context.appTextPrimary, fontSize: 13)),
                  ))
              .toList(),
          onChanged: (v) => setState(() => _status = v ?? 'operational'),
        ),
      ]),
      const SizedBox(height: 10),
      _FieldRow(children: [
        _InlineField(label: 'Type', controller: _typeCtrl),
        _InlineField(label: 'Brand', controller: _brandCtrl),
      ]),
      const SizedBox(height: 10),
      _InlineField(label: 'Model', controller: _modelCtrl),
    ]);
  }

  Widget _buildIdentificationSection(BuildContext context) {
    return Column(children: [
      _FieldRow(children: [
        _InlineField(label: 'Serial Number', controller: _serialCtrl),
        _InlineField(label: 'Patrimony Number', controller: _patrimonyCtrl),
      ]),
      const SizedBox(height: 10),
      _FieldRow(children: [
        _InlineField(label: 'Supplier', controller: _supplierCtrl),
        _InlineField(label: 'Responsible', controller: _responsibleCtrl),
      ]),
      const SizedBox(height: 10),
      _InlineField(label: 'Manual Link', controller: _manualCtrl),
    ]);
  }

  Widget _buildLocationSection(BuildContext context) {
    return _FieldRow(children: [
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
      _InlineField(label: 'Room', controller: _roomCtrl),
    ]);
  }

  Widget _buildMaintenanceSection(BuildContext context, MachineModel m) {
    return Column(children: [
      _FieldRow(children: [
        _DateField(
          label: 'Last Maintenance',
          date: _lastMaintenance,
          onTap: () => _pickDate(_lastMaintenance, (d) => setState(() => _lastMaintenance = d)),
          onClear: () => setState(() => _lastMaintenance = null),
        ),
        _DateField(
          label: 'Next Maintenance',
          date: _nextMaintenance,
          onTap: () => _pickDate(_nextMaintenance, (d) => setState(() => _nextMaintenance = d)),
          onClear: () => setState(() => _nextMaintenance = null),
          danger: m.maintenanceOverdue,
          warning: m.maintenanceDueSoon && !m.maintenanceOverdue,
        ),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _InlineField(
          label: 'Maintenance interval (days)',
          controller: _maintIntervalCtrl,
          keyboardType: TextInputType.number,
        )),
        const Expanded(child: SizedBox()),
      ]),
      const SizedBox(height: 10),
      _FieldRow(children: [
        _DateField(
          label: 'Last Calibration',
          date: _lastCalibration,
          onTap: () => _pickDate(_lastCalibration, (d) => setState(() => _lastCalibration = d)),
          onClear: () => setState(() => _lastCalibration = null),
        ),
        _DateField(
          label: 'Next Calibration',
          date: _nextCalibration,
          onTap: () => _pickDate(_nextCalibration, (d) => setState(() => _nextCalibration = d)),
          onClear: () => setState(() => _nextCalibration = null),
        ),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _InlineField(
          label: 'Calibration interval (days)',
          controller: _calibIntervalCtrl,
          keyboardType: TextInputType.number,
        )),
        const Expanded(child: SizedBox()),
      ]),
    ]);
  }

  Widget _buildPurchaseSection(BuildContext context) {
    return _FieldRow(children: [
      _DateField(
        label: 'Purchase Date',
        date: _purchaseDate,
        onTap: () => _pickDate(_purchaseDate, (d) => setState(() => _purchaseDate = d)),
        onClear: () => setState(() => _purchaseDate = null),
      ),
      _DateField(
        label: 'Warranty Until',
        date: _warrantyDate,
        onTap: () => _pickDate(_warrantyDate, (d) => setState(() => _warrantyDate = d)),
        onClear: () => setState(() => _warrantyDate = null),
        warning: _warrantyDate != null &&
            _warrantyDate!.isAfter(DateTime.now()) &&
            _warrantyDate!.difference(DateTime.now()).inDays <= 30,
        danger: _warrantyDate != null && _warrantyDate!.isBefore(DateTime.now()),
      ),
    ]);
  }

  Widget _buildReservationsSection(
      BuildContext context,
      List<ReservationModel> upcoming,
      List<ReservationModel> past) {
    if (_reservations.isEmpty) {
      return Text('No reservations recorded.',
          style: GoogleFonts.spaceGrotesk(
              color: context.appTextMuted, fontSize: 13));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (upcoming.isNotEmpty) ...[
        Text('Upcoming / Ongoing',
            style: GoogleFonts.spaceGrotesk(
                color: context.appTextMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6)),
        const SizedBox(height: 6),
        ...upcoming.map((r) => _ReservationTile(reservation: r)),
        if (past.isNotEmpty) const SizedBox(height: 12),
      ],
      if (past.isNotEmpty) ...[
        Text('Past (last ${past.take(5).length})',
            style: GoogleFonts.spaceGrotesk(
                color: context.appTextMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6)),
        const SizedBox(height: 6),
        ...past.take(5).map((r) => _ReservationTile(reservation: r, past: true)),
      ],
    ]);
  }

  // ── QR dialog ──────────────────────────────────────────────────────────────

  void _showQr(MachineModel m) {
    final ref  = SupabaseManager.projectRef ?? 'local';
    final data = 'bluelims://$ref/machines/${m.id}';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.appSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('QR — ${m.name}',
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

// ─── Reservation tile ─────────────────────────────────────────────────────────
class _ReservationTile extends StatelessWidget {
  final ReservationModel reservation;
  final bool past;
  const _ReservationTile({required this.reservation, this.past = false});

  @override
  Widget build(BuildContext context) {
    final r  = reservation;
    final sc = r.statusColor;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: past ? context.appBorder : sc.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              '${_fmtDt(r.start)} → ${_fmtDt(r.end)}',
              style: GoogleFonts.spaceGrotesk(
                  color: past
                      ? context.appTextSecondary
                      : context.appTextPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
            ),
            if (r.purpose != null || r.project != null)
              Text(
                [if (r.purpose != null) r.purpose!, if (r.project != null) r.project!].join(' · '),
                style: GoogleFonts.spaceGrotesk(
                    color: context.appTextMuted, fontSize: 11),
              ),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: sc.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(r.status,
              style: GoogleFonts.spaceGrotesk(color: sc, fontSize: 11)),
        ),
      ]),
    );
  }

  String _fmtDt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
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
                  color: (danger || warning)
                      ? color.withValues(alpha: 0.5)
                      : context.appBorder)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                  color: (danger || warning)
                      ? color.withValues(alpha: 0.5)
                      : context.appBorder)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
              color: date != null
                  ? (danger || warning ? color : context.appTextPrimary)
                  : context.appTextMuted,
              fontSize: 13),
        ),
      ),
    );
  }
}

// ─── Badges ──────────────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final String status;
  final Color color;
  const _StatusBadge({required this.status, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(MachineModel.statusLabel(status),
            style: GoogleFonts.spaceGrotesk(
                color: color, fontSize: 13, fontWeight: FontWeight.w600)),
      );
}

class _SmallBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _SmallBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label,
            style: GoogleFonts.spaceGrotesk(color: color, fontSize: 11)),
      );
}
