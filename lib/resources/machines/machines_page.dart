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
import '/fish_facility/shared_widgets.dart';
import '/supabase/supabase_manager.dart';
import '/theme/theme.dart';
import '/theme/grid_widgets.dart';
import '../../camera/qr_scanner/qr_code_rules.dart';
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
  String _statusFilter = 'all';
  final _searchCtrl = TextEditingController();
  String _sortKey = 'name';
  bool _sortAsc = true;

  final _vertCtrl  = ScrollController();
  final _horizCtrl = ScrollController();
  final _hOffset   = ValueNotifier<double>(0);
  final _vOffset   = ValueNotifier<double>(0);

  static const _cols = [
    ('name',        'Name',        180.0),
    ('status',      'Status',      110.0),
    ('type',        'Type',        130.0),
    ('brand',       'Brand',       120.0),
    ('model',       'Model',       120.0),
    ('serial',      'Serial No.',  120.0),
    ('location',    'Location',    140.0),
    ('room',        'Room',         90.0),
    ('responsible', 'Responsible', 130.0),
    ('nextMaint',   'Next Maint.', 110.0),
    ('nextCal',     'Next Cal.',   110.0),
  ];

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _vertCtrl.dispose();
    _horizCtrl.dispose();
    _hOffset.dispose();
    _vOffset.dispose();
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
    final q = _searchCtrl.text.toLowerCase();
    var d = _all.where((m) {
      if (_statusFilter != 'all' && m.status != _statusFilter) return false;
      if (q.isEmpty) return true;
      return m.name.toLowerCase().contains(q) ||
          (m.brand?.toLowerCase().contains(q) ?? false) ||
          (m.model?.toLowerCase().contains(q) ?? false) ||
          (m.type?.toLowerCase().contains(q) ?? false) ||
          (m.serialNumber?.toLowerCase().contains(q) ?? false) ||
          (m.locationName?.toLowerCase().contains(q) ?? false);
    }).toList();
    d.sort((a, b) {
      dynamic av, bv;
      switch (_sortKey) {
        case 'name':        av = a.name;                  bv = b.name;
        case 'status':      av = a.status;                bv = b.status;
        case 'type':        av = a.type ?? '';             bv = b.type ?? '';
        case 'brand':       av = a.brand ?? '';            bv = b.brand ?? '';
        case 'model':       av = a.model ?? '';            bv = b.model ?? '';
        case 'serial':      av = a.serialNumber ?? '';     bv = b.serialNumber ?? '';
        case 'location':    av = a.locationName ?? '';     bv = b.locationName ?? '';
        case 'room':        av = a.room ?? '';             bv = b.room ?? '';
        case 'responsible': av = a.responsible ?? '';      bv = b.responsible ?? '';
        case 'nextMaint':   av = a.nextMaintenance?.millisecondsSinceEpoch ?? 0;
                            bv = b.nextMaintenance?.millisecondsSinceEpoch ?? 0;
        case 'nextCal':     av = a.nextCalibration?.millisecondsSinceEpoch ?? 0;
                            bv = b.nextCalibration?.millisecondsSinceEpoch ?? 0;
        default: av = a.name; bv = b.name;
      }
      int c = (av is num && bv is num)
          ? av.compareTo(bv)
          : av.toString().compareTo(bv.toString());
      return _sortAsc ? c : -c;
    });
    setState(() => _filtered = d);
  }

  void _sort(String key) {
    setState(() {
      if (_sortKey == key) { _sortAsc = !_sortAsc; }
      else { _sortKey = key; _sortAsc = true; }
    });
    _applyFilters();
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
    final tableWidth = _cols.fold(0.0, (s, c) => s + c.$3) + 56;

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
          if (MediaQuery.of(context).size.width < 700) ...[
            IconButton(
              icon: const Icon(Icons.menu_rounded, size: 20),
              color: context.appTextSecondary,
              tooltip: 'Menu',
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ],
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
              child: AppSearchBar(
                  controller: _searchCtrl,
                  hint: 'Search machines\u2026',
                  onClear: _applyFilters),
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

      Container(height: 1, color: context.appBorder),

      // ── Table ─────────────────────────────────────────────────────────────────
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
                : Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                    child: Column(children: [
                      Expanded(
                        child: Row(children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: context.appSurface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: context.appBorder),
                                boxShadow: [BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2))],
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: NotificationListener<ScrollNotification>(
                                onNotification: (n) {
                                  if (n is ScrollUpdateNotification) {
                                    if (n.metrics.axis == Axis.horizontal) {
                                      _hOffset.value = _horizCtrl.hasClients
                                          ? _horizCtrl.offset : 0.0;
                                    } else if (n.metrics.axis == Axis.vertical) {
                                      _vOffset.value = _vertCtrl.hasClients
                                          ? _vertCtrl.offset : 0.0;
                                    }
                                  }
                                  return false;
                                },
                                child: SingleChildScrollView(
                                  controller: _horizCtrl,
                                  scrollDirection: Axis.horizontal,
                                  child: SizedBox(
                                    width: tableWidth,
                                    child: Column(children: [
                                      // Sticky header
                                      Container(
                                        height: AppDS.tableHeaderH,
                                        color: context.appHeaderBg,
                                        child: Row(children: [
                                          const SizedBox(width: 56),
                                          ..._cols.map((c) => SizedBox(
                                            width: c.$3,
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 6),
                                              child: SortHeader(
                                                label: c.$2,
                                                columnKey: c.$1,
                                                sortKey: _sortKey,
                                                sortAsc: _sortAsc,
                                                onSort: _sort),
                                            ),
                                          )),
                                        ]),
                                      ),
                                      Container(height: 1, color: context.appBorder),
                                      // Rows
                                      Expanded(
                                        child: ListView.builder(
                                          controller: _vertCtrl,
                                          itemCount: _filtered.length,
                                          itemExtent: AppDS.tableRowH,
                                          itemBuilder: (_, i) {
                                            final m = _filtered[i];
                                            return KeyedSubtree(
                                              key: ValueKey(m.id),
                                              child: _buildRow(m, i),
                                            );
                                          },
                                        ),
                                      ),
                                    ]),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          AppVerticalThumb(
                            contentLength: _filtered.length * AppDS.tableRowH,
                            topPadding: AppDS.tableHeaderH,
                            offset: _vOffset,
                            onScrollTo: (y) {
                              final max = _vertCtrl.hasClients
                                  ? _vertCtrl.position.maxScrollExtent : 0.0;
                              final clamped = y.clamp(0.0, max);
                              _vertCtrl.jumpTo(clamped);
                              _vOffset.value = clamped;
                            },
                          ),
                        ]),
                      ),
                      const SizedBox(height: 4),
                      AppHorizontalThumb(
                        contentWidth: tableWidth,
                        offset: _hOffset,
                        onScrollTo: (x) {
                          final max = _horizCtrl.hasClients
                              ? _horizCtrl.position.maxScrollExtent : 0.0;
                          final clamped = x.clamp(0.0, max);
                          _horizCtrl.jumpTo(clamped);
                          _hOffset.value = clamped;
                        },
                      ),
                    ]),
                  ),
      ),
    ]);
  }

  // ── Row builder ─────────────────────────────────────────────────────────────
  Widget _buildRow(MachineModel m, int rowIndex) {
    final rowBg = rowIndex.isEven ? context.appSurface : context.appSurface2;
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => MachineDetailPage(machineId: m.id)),
      ).then((_) => _load()),
      child: Container(
        decoration: BoxDecoration(
          color: rowBg,
          border: Border(bottom: BorderSide(color: context.appBorder, width: 1)),
        ),
        child: Row(children: [
          SizedBox(
            width: 28,
            child: AppIconButton(
              icon: Icons.open_in_new, tooltip: 'Open detail',
              color: AppDS.textMuted,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => MachineDetailPage(machineId: m.id)),
              ).then((_) => _load()),
            ),
          ),
          SizedBox(
            width: 28,
            child: AppIconButton(
              icon: Icons.event_available_outlined, tooltip: 'Quick Reservation',
              color: AppDS.textMuted,
              onPressed: () => showMachineQuickReservationDialog(
                context, machineId: m.id, machineName: m.name),
            ),
          ),
          _textCell(m.name, 180, bold: true),
          _statusCell(m, 110),
          _textCell(m.type, 130),
          _textCell(m.brand, 120),
          _textCell(m.model, 120),
          _textCell(m.serialNumber, 120, mono: true),
          _textCell(m.locationName, 140),
          _textCell(m.room, 90),
          _textCell(m.responsible, 130),
          _maintDateCell(m.nextMaintenance, 110,
              overdue: m.maintenanceOverdue, soon: m.maintenanceDueSoon),
          _maintDateCell(m.nextCalibration, 110),
        ]),
      ),
    );
  }

  Widget _textCell(String? value, double width,
      {bool mono = false, bool bold = false}) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Text(
          value ?? '\u2014',
          overflow: TextOverflow.ellipsis,
          style: mono
              ? GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  color: value != null
                      ? context.appTextPrimary : context.appTextMuted)
              : GoogleFonts.spaceGrotesk(
                  fontSize: 12.5,
                  color: value != null
                      ? context.appTextPrimary : context.appTextMuted,
                  fontWeight: bold ? FontWeight.w600 : FontWeight.normal),
        ),
      ),
    );
  }

  Widget _statusCell(MachineModel m, double width) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: _StatusBadge(status: m.status),
      ),
    );
  }

  Widget _maintDateCell(DateTime? date, double width,
      {bool overdue = false, bool soon = false}) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Text(
          date != null ? date.toIso8601String().substring(0, 10) : '\u2014',
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 12,
            color: overdue
                ? AppDS.red
                : soon
                    ? AppDS.yellow
                    : date != null
                        ? context.appTextPrimary
                        : context.appTextMuted,
          ),
        ),
      ),
    );
  }
}

