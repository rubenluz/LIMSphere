// locations_page.dart - Location/room hierarchy: rooms -> sub-locations tree,
// QR code generation, CSV export.
// Widget and dialog classes in locations_widgets.dart (part).


import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide LocalStorage;
import '/core/data_cache.dart';
import '/supabase/supabase_manager.dart';
import '/theme/theme.dart';
import '../camera/qr_scanner/qr_code_rules.dart';
import 'location_model.dart';
import 'location_detail_page.dart';

part 'locations_widgets.dart';

// ─── Page ───────────────────────────────────────────────────────────────────────
class LocationsPage extends StatefulWidget {
  const LocationsPage({super.key});
  @override
  State<LocationsPage> createState() => _LocationsPageState();
}

class _LocationsPageState extends State<LocationsPage> {
  List<LocationModel> _all = [];
  List<LocationModel> _rooms = [];
  Map<int, List<LocationModel>> _childMap = {};
  List<LocationModel> _orphans = [];
  List<int> _roomOrder = [];
  bool _loading = true;
  String _search = '';
  final _searchCtrl = TextEditingController();

  static const _orderKey = 'locations_room_order_v1';

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  // ── Data ──────────────────────────────────────────────────────────────────────

  Future<void> _applyRawRows(List<dynamic> rows) async {
    final items = rows.map<LocationModel>((r) {
      final p = (r as Map)['parent'];
      return LocationModel.fromMap({
        ...Map<String, dynamic>.from(r),
        'parent_name': p is Map ? p['location_name'] as String? : null,
      });
    }).toList();

    final rooms = items.where((l) => l.type == 'room').toList();
    final roomIds = {for (final r in rooms) r.id};
    final childMap = <int, List<LocationModel>>{};
    final orphans = <LocationModel>[];

    for (final item in items) {
      if (item.type == 'room') continue;
      if (item.parentId != null && roomIds.contains(item.parentId)) {
        childMap.putIfAbsent(item.parentId!, () => []).add(item);
      } else {
        orphans.add(item);
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final savedJson = prefs.getString(_orderKey);
    List<int> order;
    if (savedJson != null) {
      try {
        final saved = List<int>.from(jsonDecode(savedJson));
        order = saved.where(roomIds.contains).toList();
        final fresh = rooms
            .where((r) => !order.contains(r.id))
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
        order.addAll(fresh.map((r) => r.id));
      } catch (_) {
        order = _alpha(rooms);
      }
    } else {
      order = _alpha(rooms);
    }

    if (mounted) {
      setState(() {
        _all = items;
        _rooms = rooms;
        _childMap = childMap;
        _orphans = orphans;
        _roomOrder = order;
        _loading = false;
      });
    }
  }

  Future<void> _load() async {
    final cached = await DataCache.read('storage_locations');
    if (cached != null) {
      await _applyRawRows(cached);
    } else if (mounted) {
      setState(() => _loading = true);
    }
    try {
      final rows = await Supabase.instance.client
          .from('storage_locations')
          .select('*, parent:location_parent_id(location_name)')
          .order('location_name');
      await DataCache.write('storage_locations', rows as List<dynamic>);
      if (!mounted) return;
      await _applyRawRows(rows);
    } catch (e) {
      if (cached == null && mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to load: $e')));
      }
    }
  }

  List<int> _alpha(List<LocationModel> rooms) => rooms
      .map((r) => r.id)
      .toList()
    ..sort((a, b) {
      final ra = rooms.firstWhere((r) => r.id == a);
      final rb = rooms.firstWhere((r) => r.id == b);
      return ra.name.compareTo(rb.name);
    });

  // ── Actions ───────────────────────────────────────────────────────────────────

  void _navigate(LocationModel loc) => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LocationDetailPage(locationId: loc.id)))
      .then((_) => _load());

  Future<void> _showDialog({
    LocationModel? existing,
    int? defaultParentId,
    String defaultType = 'room',
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => _LocationFormDialog(
        existing: existing,
        allLocations: _all,
        defaultParentId: defaultParentId,
        defaultType: defaultType,
      ),
    );
    if (ok == true) _load();
  }

  Future<void> _exportCsv() async {
    final buf = StringBuffer()
      ..writeln('ID,Name,Type,Temperature,Capacity,Parent,Notes');
    for (final loc in _all) {
      buf.writeln(
          '${loc.id},"${loc.name}","${loc.type}","${loc.temperature ?? ''}","${loc.capacity ?? ''}","${loc.parentName ?? ''}","${loc.notes ?? ''}"');
    }
    try {
      final dir = await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
      final file = File(
          '${dir.path}/locations_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(buf.toString());
      await OpenFilex.open(file.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _buildToolbar(context),
      Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _buildBody(context)),
    ]);
  }

  Widget _buildToolbar(BuildContext context) {
    return Container(
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
        const Icon(Icons.place_outlined, color: Color(0xFF6366F1), size: 18),
        const SizedBox(width: 8),
        Text('Locations',
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
              onChanged: (v) => setState(() => _search = v.toLowerCase()),
              style:
                  GoogleFonts.spaceGrotesk(color: context.appTextPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search locations...',
                hintStyle:
                    GoogleFonts.spaceGrotesk(color: context.appTextMuted, fontSize: 13),
                prefixIcon:
                    Icon(Icons.search, color: context.appTextMuted, size: 16),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear,
                            size: 14, color: context.appTextMuted),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _search = '');
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
            backgroundColor: const Color(0xFF6366F1),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
            minimumSize: const Size(0, 36),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () => _showDialog(),
          icon: const Icon(Icons.add, size: 16),
          label: Text('Add Room', style: GoogleFonts.spaceGrotesk(fontSize: 13)),
        ),
      ]),
    );
  }

  Widget _buildBody(BuildContext context) {
    final q = _search;

    final visibleRooms = _roomOrder
        .where((id) => _rooms.any((r) => r.id == id))
        .map((id) => _rooms.firstWhere((r) => r.id == id))
        .where((r) {
          if (q.isEmpty) return true;
          if (r.name.toLowerCase().contains(q)) return true;
          return (_childMap[r.id] ?? []).any((c) =>
              c.name.toLowerCase().contains(q) ||
              (c.temperature?.toLowerCase().contains(q) ?? false));
        })
        .toList();

    final visibleOrphans = q.isEmpty
        ? _orphans
        : _orphans
            .where((o) =>
                o.name.toLowerCase().contains(q) ||
                (o.temperature?.toLowerCase().contains(q) ?? false))
            .toList();

    if (visibleRooms.isEmpty && visibleOrphans.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.place_outlined, size: 48, color: context.appTextMuted),
          const SizedBox(height: 12),
          Text(
            q.isEmpty
                ? 'No rooms yet.\nClick "Add Room" to get started.'
                : 'No locations match "$_search"',
            textAlign: TextAlign.center,
            style: GoogleFonts.spaceGrotesk(color: context.appTextMuted, fontSize: 15),
          ),
        ]),
      );
    }

    const hPad = 16.0;
    const spacing = 12.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(hPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...visibleRooms.map((room) {
            final kids = (_childMap[room.id] ?? []).where((c) {
              if (q.isEmpty) return true;
              return c.name.toLowerCase().contains(q) ||
                  (c.temperature?.toLowerCase().contains(q) ?? false);
            }).toList();
            return Padding(
              padding: const EdgeInsets.only(bottom: spacing),
              child: _RoomCard(
                key: ValueKey(room.id),
                room: room,
                children: kids,
                onTap: () => _navigate(room),
                onTapChild: _navigate,
                onAddChild: () =>
                    _showDialog(defaultParentId: room.id, defaultType: 'freezer'),
              ),
            );
          }),
          if (visibleOrphans.isNotEmpty)
            _OrphanCard(
              key: const ValueKey('__orphans__'),
              locations: visibleOrphans,
              onTap: _navigate,
              onAdd: () => _showDialog(defaultType: 'shelf'),
            ),
        ],
      ),
    );
  }
}

