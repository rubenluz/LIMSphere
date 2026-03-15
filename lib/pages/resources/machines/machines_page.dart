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
import 'machine_model.dart';
import 'machine_detail_page.dart';

class MachinesPage extends StatefulWidget {
  const MachinesPage({super.key});

  @override
  State<MachinesPage> createState() => _MachinesPageState();
}

class _MachinesPageState extends State<MachinesPage> {
  List<MachineModel> _all = [];
  List<MachineModel> _filtered = [];
  bool _loading = true;
  String _search = '';
  String _statusFilter = 'all';
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
          .from('equipment')
          .select('*, location:equipment_location_id(location_name)')
          .order('equipment_name');

      final items = rows.map<MachineModel>((r) {
        final locData = r['location'];
        final locName =
            locData is Map ? locData['location_name'] as String? : null;
        return MachineModel.fromMap({...r, 'location_name': locName});
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
      _filtered = _all.where((m) {
        if (_statusFilter != 'all' && m.status != _statusFilter) return false;
        if (q.isEmpty) return true;
        return m.name.toLowerCase().contains(q) ||
            (m.brand?.toLowerCase().contains(q) ?? false) ||
            (m.model?.toLowerCase().contains(q) ?? false) ||
            (m.type?.toLowerCase().contains(q) ?? false) ||
            (m.serialNumber?.toLowerCase().contains(q) ?? false) ||
            (m.locationName?.toLowerCase().contains(q) ?? false);
      }).toList();
    });
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

  Future<void> _showAddEditDialog([MachineModel? existing]) async {
    final locations = await _loadLocations();
    if (!mounted) return;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) =>
          _MachineFormDialog(existing: existing, locations: locations),
    );
    if (result == true) _load();
  }

  Future<void> _delete(MachineModel m) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppDS.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Delete Machine',
            style: GoogleFonts.spaceGrotesk(color: AppDS.textPrimary)),
        content: Text('Delete "${m.name}"? This cannot be undone.',
            style: GoogleFonts.spaceGrotesk(color: AppDS.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style:
                      GoogleFonts.spaceGrotesk(color: AppDS.textSecondary))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child:
                  Text('Delete', style: GoogleFonts.spaceGrotesk(color: AppDS.red))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await Supabase.instance.client
          .from('equipment')
          .delete()
          .eq('equipment_id', m.id);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
      }
    }
  }

  void _showQr(MachineModel m) {
    final ref = SupabaseManager.projectRef ?? 'local';
    final data = 'bluelims://$ref/machine/${m.id}';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppDS.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('QR — ${m.name}',
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
        'ID,Name,Type,Brand,Model,Serial,Status,Location,Room,NextMaintenance,NextCalibration,Responsible');
    for (final m in _filtered) {
      buf.writeln(
          '${m.id},"${m.name}","${m.type ?? ''}","${m.brand ?? ''}","${m.model ?? ''}","${m.serialNumber ?? ''}","${m.status}","${m.locationName ?? ''}","${m.room ?? ''}","${m.nextMaintenance != null ? m.nextMaintenance!.toIso8601String().substring(0, 10) : ''}","${m.nextCalibration != null ? m.nextCalibration!.toIso8601String().substring(0, 10) : ''}","${m.responsible ?? ''}"');
    }
    try {
      final dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/machines_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(buf.toString());
      await OpenFilex.open(file.path);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

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
          const Icon(Icons.precision_manufacturing_outlined,
              color: Color(0xFF14B8A6), size: 18),
          const SizedBox(width: 8),
          Text('Machines',
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
                  hintText: 'Search machines...',
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
              backgroundColor: const Color(0xFF14B8A6),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              minimumSize: const Size(0, 36),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => _showAddEditDialog(),
            icon: const Icon(Icons.add, size: 16),
            label: Text('Add Machine',
                style: GoogleFonts.spaceGrotesk(fontSize: 13)),
          ),
        ]),
      ),

      // ── Status filter chips ──────────────────────────────────────────────────
      Container(
        height: 44,
        decoration: const BoxDecoration(
          color: AppDS.bg,
          border: Border(bottom: BorderSide(color: AppDS.border)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          _Chip(
              label: 'All (${_all.length})',
              selected: _statusFilter == 'all',
              color: AppDS.accent,
              onTap: () { _statusFilter = 'all'; _applyFilters(); }),
          const SizedBox(width: 8),
          _Chip(
              label: 'Operational (${_all.where((m) => m.status == 'operational').length})',
              selected: _statusFilter == 'operational',
              color: AppDS.green,
              onTap: () { _statusFilter = 'operational'; _applyFilters(); }),
          const SizedBox(width: 8),
          _Chip(
              label: 'Maintenance (${_all.where((m) => m.status == 'maintenance').length})',
              selected: _statusFilter == 'maintenance',
              color: AppDS.orange,
              onTap: () { _statusFilter = 'maintenance'; _applyFilters(); }),
          const SizedBox(width: 8),
          _Chip(
              label: 'Broken (${_all.where((m) => m.status == 'broken').length})',
              selected: _statusFilter == 'broken',
              color: AppDS.red,
              onTap: () { _statusFilter = 'broken'; _applyFilters(); }),
          const SizedBox(width: 8),
          _Chip(
              label: 'Retired (${_all.where((m) => m.status == 'retired').length})',
              selected: _statusFilter == 'retired',
              color: AppDS.textMuted,
              onTap: () { _statusFilter = 'retired'; _applyFilters(); }),
        ]),
      ),

      // ── Body ─────────────────────────────────────────────────────────────────
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _filtered.isEmpty
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.precision_manufacturing_outlined,
                          size: 48, color: AppDS.textMuted),
                      const SizedBox(height: 12),
                      Text('No machines found',
                          style: GoogleFonts.spaceGrotesk(
                              color: AppDS.textMuted, fontSize: 15)),
                    ]),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filtered.length,
                    itemBuilder: (ctx, i) {
                      final m = _filtered[i];
                      return _MachineCard(
                        machine: m,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  MachineDetailPage(machineId: m.id)),
                        ),
                        onEdit: () => _showAddEditDialog(m),
                        onDelete: () => _delete(m),
                        onQr: () => _showQr(m),
                      );
                    },
                  ),
      ),
    ]);
  }
}

// ─── Machine Card ──────────────────────────────────────────────────────────────
class _MachineCard extends StatelessWidget {
  final MachineModel machine;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onQr;

  const _MachineCard({
    required this.machine,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onQr,
  });

  @override
  Widget build(BuildContext context) {
    final m = machine;
    final sc = m.statusColor;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            decoration: BoxDecoration(
              color: AppDS.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: m.status == 'broken'
                      ? AppDS.red.withValues(alpha: 0.5)
                      : AppDS.border),
            ),
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: sc.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.precision_manufacturing_outlined,
                    color: sc, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Flexible(
                          child: Text(m.name,
                              style: GoogleFonts.spaceGrotesk(
                                  color: AppDS.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 8),
                        _StatusBadge(status: m.status),
                        if (m.maintenanceOverdue) ...[
                          const SizedBox(width: 6),
                          _SmallBadge(
                              label: 'Maintenance overdue',
                              color: AppDS.red),
                        ] else if (m.maintenanceDueSoon) ...[
                          const SizedBox(width: 6),
                          _SmallBadge(
                              label: 'Maintenance due soon',
                              color: AppDS.yellow),
                        ],
                      ]),
                      const SizedBox(height: 4),
                      Wrap(spacing: 14, children: [
                        if (m.brand != null || m.model != null)
                          _MetaText(
                              '${m.brand ?? ''}${m.brand != null && m.model != null ? ' · ' : ''}${m.model ?? ''}'),
                        if (m.type != null) _MetaText(m.type!),
                        if (m.locationName != null)
                          _MetaText(m.locationName!,
                              icon: Icons.place_outlined),
                        if (m.nextMaintenance != null)
                          _MetaText(
                              'Next maint: ${m.nextMaintenance!.toIso8601String().substring(0, 10)}',
                              icon: Icons.build_outlined),
                      ]),
                    ]),
              ),
              Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                    icon: const Icon(Icons.qr_code,
                        size: 18, color: AppDS.textSecondary),
                    tooltip: 'QR Code',
                    onPressed: onQr),
                IconButton(
                    icon: const Icon(Icons.edit_outlined,
                        size: 16, color: AppDS.textSecondary),
                    tooltip: 'Edit',
                    onPressed: onEdit),
                IconButton(
                    icon: const Icon(Icons.delete_outline,
                        size: 16, color: AppDS.textSecondary),
                    tooltip: 'Delete',
                    onPressed: onDelete),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
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

class _MetaText extends StatelessWidget {
  final String label;
  final IconData? icon;
  const _MetaText(this.label, {this.icon});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: AppDS.textMuted),
            const SizedBox(width: 3),
          ],
          Text(label,
              style: GoogleFonts.spaceGrotesk(
                  color: AppDS.textSecondary, fontSize: 12)),
        ],
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
                color: selected ? color : AppDS.border,
                width: selected ? 1.5 : 1),
          ),
          child: Text(label,
              style: GoogleFonts.spaceGrotesk(
                  color: selected ? color : AppDS.textSecondary,
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
        await Supabase.instance.client.from('equipment').insert(data);
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
      backgroundColor: AppDS.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(
          widget.existing != null ? 'Edit Machine' : 'Add Machine',
          style: GoogleFonts.spaceGrotesk(
              color: AppDS.textPrimary, fontWeight: FontWeight.w600)),
      content: SizedBox(
        width: 580,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _f(_nameCtrl, 'Name *',
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Required' : null),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _f(_typeCtrl, 'Type (e.g. Centrifuge)')),
                const SizedBox(width: 10),
                Expanded(child: _dd<String>(
                  label: 'Status',
                  value: _status,
                  items: MachineModel.statusOptions
                      .map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(MachineModel.statusLabel(s),
                              style: GoogleFonts.spaceGrotesk(
                                  color: AppDS.textPrimary, fontSize: 13))))
                      .toList(),
                  onChanged: (v) => setState(() => _status = v ?? 'operational'),
                )),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _f(_brandCtrl, 'Brand')),
                const SizedBox(width: 10),
                Expanded(child: _f(_modelCtrl, 'Model')),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _f(_serialCtrl, 'Serial Number')),
                const SizedBox(width: 10),
                Expanded(child: _f(_patrimonyCtrl, 'Patrimony Number')),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _dd<int?>(
                  label: 'Location',
                  value: _locationId,
                  items: [
                    DropdownMenuItem<int?>(
                        value: null,
                        child: Text('None',
                            style: GoogleFonts.spaceGrotesk(
                                color: AppDS.textMuted, fontSize: 13))),
                    ...widget.locations.map((l) => DropdownMenuItem<int?>(
                          value: (l['location_id'] as num).toInt(),
                          child: Text(l['location_name'] as String,
                              style: GoogleFonts.spaceGrotesk(
                                  color: AppDS.textPrimary, fontSize: 13)),
                        )),
                  ],
                  onChanged: (v) => setState(() => _locationId = v),
                )),
                const SizedBox(width: 10),
                Expanded(child: _f(_roomCtrl, 'Room')),
              ]),
              const SizedBox(height: 10),
              _sectionLabel('Maintenance'),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(
                    child: _dp('Last Maintenance', _lastMaintenance,
                        () => _pickDate('lastMaint'))),
                const SizedBox(width: 10),
                Expanded(
                    child: _dp('Next Maintenance', _nextMaintenance,
                        () => _pickDate('nextMaint'))),
                const SizedBox(width: 10),
                Expanded(
                    child: _f(_maintIntervalCtrl, 'Interval (days)',
                        keyboardType: TextInputType.number)),
              ]),
              const SizedBox(height: 10),
              _sectionLabel('Calibration'),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(
                    child: _dp('Last Calibration', _lastCalibration,
                        () => _pickDate('lastCal'))),
                const SizedBox(width: 10),
                Expanded(
                    child: _dp('Next Calibration', _nextCalibration,
                        () => _pickDate('nextCal'))),
                const SizedBox(width: 10),
                Expanded(
                    child: _f(_calIntervalCtrl, 'Interval (days)',
                        keyboardType: TextInputType.number)),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                    child: _dp('Purchase Date', _purchaseDate,
                        () => _pickDate('purchase'))),
                const SizedBox(width: 10),
                Expanded(
                    child: _dp('Warranty Until', _warrantyUntil,
                        () => _pickDate('warranty'))),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _f(_responsibleCtrl, 'Responsible')),
                const SizedBox(width: 10),
                Expanded(child: _f(_supplierCtrl, 'Supplier')),
              ]),
              const SizedBox(height: 10),
              _f(_manualCtrl, 'Manual Link (URL)'),
              const SizedBox(height: 10),
              _f(_notesCtrl, 'Notes', maxLines: 3),
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

  Widget _sectionLabel(String t) => Align(
        alignment: Alignment.centerLeft,
        child: Text(t,
            style: GoogleFonts.spaceGrotesk(
                color: AppDS.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6)),
      );

  Widget _f(TextEditingController ctrl, String label,
      {int maxLines = 1,
      TextInputType? keyboardType,
      String? Function(String?)? validator}) =>
      TextFormField(
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

  Widget _dd<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) =>
      InputDecorator(
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

  Widget _dp(String label, DateTime? date, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppDS.surface3,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppDS.border),
          ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.spaceGrotesk(
                        color: AppDS.textSecondary, fontSize: 11)),
                const SizedBox(height: 2),
                Text(
                    date != null
                        ? date.toIso8601String().substring(0, 10)
                        : 'Select date',
                    style: GoogleFonts.spaceGrotesk(
                        color:
                            date != null ? AppDS.textPrimary : AppDS.textMuted,
                        fontSize: 13)),
              ]),
        ),
      );
}
