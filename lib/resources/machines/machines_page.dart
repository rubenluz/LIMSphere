// machines_page.dart - Machine/equipment registry: cards with specs, status,
// maintenance notes, QR codes.
// Widget and dialog classes in machines_widgets.dart (part).

import 'package:flutter/material.dart';
import '/theme/module_permission.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide LocalStorage;
import '/core/data_cache.dart';
import '/theme/theme.dart';
import 'machine_model.dart';
import 'machine_detail_page.dart';
import '../reservations/reservations_page.dart';

part 'machines_widgets.dart';

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

  List<MachineModel> _machinesFromRaw(List<dynamic> raw) => raw.map<MachineModel>((r) {
    final locData = (r as Map)['location'];
    final locName = locData is Map ? locData['location_name'] as String? : null;
    return MachineModel.fromMap({...Map<String, dynamic>.from(r), 'location_name': locName});
  }).toList();

  Future<void> _load() async {
    final cached = await DataCache.read('equipment');
    if (cached != null && mounted) {
      setState(() { _all = _machinesFromRaw(cached); _loading = false; _applyFilters(); });
    } else {
      setState(() => _loading = true);
    }
    try {
      final rows = await Supabase.instance.client
          .from('equipment')
          .select('*, location:equipment_location_id(location_name)')
          .order('equipment_name');
      await DataCache.write('equipment', rows as List<dynamic>);
      if (!mounted) return;
      setState(() { _all = _machinesFromRaw(rows); _loading = false; _applyFilters(); });
    } catch (e) {
      if (cached == null && mounted) {
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
    if (!context.canEditModule) { context.warnReadOnly(); return; }
    final locations = await _loadLocations();
    if (!mounted) return;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) =>
          _MachineFormDialog(existing: existing, locations: locations),
    );
    if (result == true) _load();
  }


  Widget _hdrText(BuildContext context, String t) => Text(t,
      style: GoogleFonts.spaceGrotesk(
          color: context.appHeaderText,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5));

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
        decoration: BoxDecoration(
          color: context.appSurface2,
          border: Border(bottom: BorderSide(color: context.appBorder)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          const Icon(Icons.precision_manufacturing_outlined,
              color: Color(0xFF14B8A6), size: 18),
          const SizedBox(width: 8),
          Text('Machines',
              style: GoogleFonts.spaceGrotesk(
                  color: context.appTextPrimary,
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
                    color: context.appTextPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search machines...',
                  hintStyle: GoogleFonts.spaceGrotesk(
                      color: context.appTextMuted, fontSize: 13),
                  prefixIcon: Icon(Icons.search,
                      color: context.appTextMuted, size: 16),
                  suffixIcon: _search.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear,
                              size: 14, color: context.appTextMuted),
                          onPressed: () {
                            _searchCtrl.clear();
                            _search = '';
                            _applyFilters();
                          })
                      : null,
                  filled: true,
                  fillColor: context.appSurface3,
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: context.appBorder)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: context.appBorder)),
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
              icon: Icon(Icons.download_outlined,
                  color: context.appTextSecondary, size: 18),
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
        decoration: BoxDecoration(
          color: context.appBg,
          border: Border(bottom: BorderSide(color: context.appBorder)),
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

      // ── Column header ─────────────────────────────────────────────────────────
      Container(
        height: 32,
        decoration: BoxDecoration(
          color: context.appHeaderBg,
          border: Border(bottom: BorderSide(color: context.appBorder)),
        ),
        padding: const EdgeInsets.only(left: 19, right: 16),
        child: Row(children: [
          const SizedBox(width: 68), // view detail + quick reservation btns
          Expanded(flex: 5, child: _hdrText(context, 'NAME / STATUS')),
          Expanded(flex: 3, child: _hdrText(context, 'TYPE / BRAND')),
          Expanded(flex: 2, child: _hdrText(context, 'LOCATION')),
          Expanded(flex: 2, child: _hdrText(context, 'NEXT MAINT')),
          const SizedBox(width: 40),
        ]),
      ),
      // ── Body ─────────────────────────────────────────────────────────────────
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _filtered.isEmpty
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.precision_manufacturing_outlined,
                          size: 48, color: context.appTextMuted),
                      const SizedBox(height: 12),
                      Text('No machines found',
                          style: GoogleFonts.spaceGrotesk(
                              color: context.appTextMuted, fontSize: 15)),
                    ]),
                  )
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: _filtered.length,
                    itemBuilder: (ctx, i) {
                      final m = _filtered[i];
                      return _MachineRow(
                        machine: m,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  MachineDetailPage(machineId: m.id)),
                        ).then((_) => _load()),
                        onDetail: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  MachineDetailPage(machineId: m.id)),
                        ).then((_) => _load()),
                        onReserve: () => showMachineQuickReservationDialog(
                          context,
                          machineId: m.id,
                          machineName: m.name,
                        ),
                      );
                    },
                  ),
      ),
    ]);
  }
}

