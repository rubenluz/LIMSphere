// locations_page.dart - Room/location hierarchy with DB-persisted sort order.
// Display codes (R{n}, L{roomN}.{childN}) are derived from sort position.
// Widget and dialog classes in locations_widgets.dart (part).

// TODO: Assign room types:
// - Wet lab
// - Imaging room
// - Fish facility

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide LocalStorage;

import '/core/data_cache.dart';
import '/supabase/supabase_manager.dart';
import '/theme/theme.dart';
import '/theme/module_permission.dart';
import '/camera/qr_scanner/qr_code_rules.dart';
import 'detail_widgets.dart';
import 'location_model.dart';
import 'location_detail_page.dart';
import 'room_detail_page.dart';

part 'locations_widgets.dart';

String roomCode(int index) => 'R${index + 1}';
String childCode(int roomIndex, int childIndex) =>
    'L${roomIndex + 1}.${childIndex + 1}';

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
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  String _search = '';
  final _searchCtrl = TextEditingController();

  int get _locationCount => _all.where((loc) => loc.isLocation).length;

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

  // ── Data ──────────────────────────────────────────────────────────────────────

  Future<void> _applyRawRows(List<dynamic> rows) async {
    final items = rows.map<LocationModel>((r) {
      final p = (r as Map)['parent'];
      return LocationModel.fromMap({
        ...Map<String, dynamic>.from(r),
        'parent_name': p is Map ? p['location_name'] as String? : null,
      });
    }).toList();

    final rooms = items.where((l) => l.isRoom).toList();
    final roomIds = {for (final r in rooms) r.id};
    final childMap = <int, List<LocationModel>>{};
    final orphans = <LocationModel>[];

    for (final item in items) {
      if (item.isRoom) continue;
      if (item.parentId != null && roomIds.contains(item.parentId)) {
        childMap.putIfAbsent(item.parentId!, () => []).add(item);
      } else {
        orphans.add(item);
      }
    }

    rooms.sort(_bySortOrderThenName);
    for (final kids in childMap.values) {
      kids.sort(_bySortOrderThenName);
    }
    orphans.sort(_bySortOrderThenName);

    if (mounted) {
      setState(() {
        _all = items;
        _rooms = rooms;
        _childMap = childMap;
        _orphans = orphans;
        _loading = false;
      });
    }
  }

  int _bySortOrderThenName(LocationModel a, LocationModel b) {
    final ao = a.sortOrder;
    final bo = b.sortOrder;
    if (ao != null && bo != null) return ao.compareTo(bo);
    if (ao != null) return -1;
    if (bo != null) return 1;
    return a.name.compareTo(b.name);
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
      await _migrateLegacyCodes(rows as List<dynamic>);
      final refreshed = await Supabase.instance.client
          .from('storage_locations')
          .select('*, parent:location_parent_id(location_name)')
          .order('location_name');
      await DataCache.write('storage_locations', refreshed as List<dynamic>);
      if (!mounted) return;
      await _applyRawRows(refreshed);
    } catch (e) {
      if (cached == null && mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to load: $e')));
      }
    }
    try {
      final userRows = await Supabase.instance.client
          .from('users')
          .select(
            'user_id, user_email, user_name, user_phone, '
            'user_institution, user_group, user_role',
          )
          .order('user_name');
      if (!mounted) return;
      setState(() => _users = List<Map<String, dynamic>>.from(userRows));
    } catch (e) {
      debugPrint('locations: users lookup failed: $e');
    }
  }

  // One-time migration: parse legacy "R1 - Description" / "L1.1 - Description"
  // names into location_sort_order + description-only name.
  Future<void> _migrateLegacyCodes(List<dynamic> rows) async {
    final client = Supabase.instance.client;
    final prefixRe = RegExp(
      r'^([RL])(\d+)(?:\.(\d+))?\s*(?:[-·]\s*)?(.*)$',
      caseSensitive: false,
    );

    for (final raw in rows) {
      final r = Map<String, dynamic>.from(raw as Map);
      final currentSort = r['location_sort_order'];
      final name = (r['location_name'] as String? ?? '').trim();
      final match = prefixRe.firstMatch(name);
      if (match == null) continue;

      final kind = match.group(1)!.toUpperCase();
      final main = int.tryParse(match.group(2) ?? '');
      final sub = int.tryParse(match.group(3) ?? '');
      final desc = (match.group(4) ?? '').trim();
      if (main == null) continue;

      final isRoom = (r['location_type'] as String?) == LocationModel.roomType;
      final expectedSort = (kind == 'L' && sub != null) ? sub : main;
      final needsSort = currentSort == null;
      final needsName = desc != name;

      if (!needsSort && !needsName) continue;
      if (kind == 'R' && !isRoom) continue;
      if (kind == 'L' && isRoom) continue;

      final update = <String, dynamic>{};
      if (needsSort) update['location_sort_order'] = expectedSort;
      if (needsName) update['location_name'] = desc;
      if (update.isEmpty) continue;
      try {
        await client
            .from('storage_locations')
            .update(update)
            .eq('location_id', r['location_id']);
      } catch (e) {
        debugPrint(
          'locations: legacy migrate failed for ${r['location_id']}: $e',
        );
      }
    }
  }

  // Re-fetches storage_locations from the DB and writes the result to cache,
  // but does NOT call setState. Used after a reorder to keep the cache fresh
  // without rebuilding the in-flight ReorderableListView (which would crash
  // with a duplicate-GlobalKey assertion mid-animation).
  Future<void> _refreshCache() async {
    try {
      final rows = await Supabase.instance.client
          .from('storage_locations')
          .select('*, parent:location_parent_id(location_name)')
          .order('location_name');
      await DataCache.write('storage_locations', rows as List<dynamic>);
    } catch (e) {
      debugPrint('locations: _refreshCache failed: $e');
    }
  }

  Future<void> _persistOrder(List<LocationModel> items) async {
    final client = Supabase.instance.client;
    // Always rewrite every row's sort_order. The list passed in was already
    // re-stamped with sequential sortOrders by the caller, so a per-row
    // comparison against the local model would skip every update — the bug
    // that made reorder appear to work then snap back after _load().
    int ok = 0;
    final failures = <String>[];
    for (var i = 0; i < items.length; i++) {
      final loc = items[i];
      final newSort = i + 1;
      try {
        await client
            .from('storage_locations')
            .update({'location_sort_order': newSort})
            .eq('location_id', loc.id);
        ok++;
      } catch (e, st) {
        debugPrint(
          'locations: persist order failed for id=${loc.id} '
          '("${loc.name}") → $newSort: $e\n$st',
        );
        failures.add('${loc.name} (id=${loc.id}): $e');
      }
    }
    debugPrint('locations: _persistOrder updated $ok/${items.length} rows');
    if (failures.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Reorder save failed for ${failures.length} item(s):\n'
            '${failures.take(3).join('\n')}',
            style: GoogleFonts.spaceGrotesk(color: Colors.white),
          ),
          backgroundColor: AppDS.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void _reorderRooms(int oldIndex, int newIndex) {
    if (!context.requireModuleAction(ModuleAction.bulkUpdate)) return;
    debugPrint(
      'locations: _reorderRooms oldIndex=$oldIndex newIndex=$newIndex '
      'len=${_rooms.length}',
    );
    try {
      setState(() {
        if (newIndex > oldIndex) newIndex -= 1;
        final moved = _rooms.removeAt(oldIndex);
        _rooms.insert(newIndex, moved);
        _rooms = [
          for (var i = 0; i < _rooms.length; i++)
            _rooms[i].copyWith(sortOrder: i + 1),
        ];
      });
    } catch (e, st) {
      debugPrint('locations: _reorderRooms reorder threw: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Reorder failed: $e',
              style: GoogleFonts.spaceGrotesk(color: Colors.white),
            ),
            backgroundColor: AppDS.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
      return;
    }
    // Don't call _load() here — the local _rooms list is already correct, and
    // re-fetching would rebuild the ReorderableListView while it's still
    // running its drop animation, which triggers a duplicate-GlobalKey
    // assertion. Refresh the cache asynchronously instead.
    _persistOrder(_rooms)
        .then((_) {
          if (mounted) _refreshCache();
        })
        .catchError((e, st) {
          debugPrint('locations: _persistOrder unhandled error: $e\n$st');
        });
  }

  void _reorderChildren(int roomId, int oldIndex, int newIndex) {
    if (!context.requireModuleAction(ModuleAction.bulkUpdate)) return;
    debugPrint(
      'locations: _reorderChildren roomId=$roomId '
      'oldIndex=$oldIndex newIndex=$newIndex '
      'len=${_childMap[roomId]?.length}',
    );
    try {
      setState(() {
        final list = _childMap[roomId];
        if (list == null) return;
        final moved = list.removeAt(oldIndex);
        list.insert(newIndex, moved);
        _childMap[roomId] = [
          for (var i = 0; i < list.length; i++)
            list[i].copyWith(sortOrder: i + 1),
        ];
      });
    } catch (e, st) {
      debugPrint('locations: _reorderChildren reorder threw: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Reorder failed: $e',
              style: GoogleFonts.spaceGrotesk(color: Colors.white),
            ),
            backgroundColor: AppDS.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
      return;
    }
    final updated = _childMap[roomId];
    if (updated != null) {
      // See _reorderRooms for why we skip _load() here.
      _persistOrder(updated)
          .then((_) {
            if (mounted) _refreshCache();
          })
          .catchError((e, st) {
            debugPrint(
              'locations: _persistOrder (children) unhandled error: $e\n$st',
            );
          });
    }
  }

  // ── Actions ───────────────────────────────────────────────────────────────────

  void _navigate(LocationModel loc) => Navigator.push(
    context,
    modulePageRoute(
      context: context,
      child: loc.isRoom
          ? RoomDetailPage(locationId: loc.id)
          : LocationDetailPage(locationId: loc.id),
    ),
  ).then((_) => _load());

  Future<void> _showEditAllDialog(
    LocationModel room,
    String code,
    int roomIndex,
    List<LocationModel> children,
  ) async {
    if (!context.requireModuleAction(ModuleAction.bulkUpdate)) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => _EditChildrenDialog(
        room: room,
        roomCode: code,
        roomIndex: roomIndex,
        children: children,
      ),
    );
    if (ok == true) _load();
  }

  Future<void> _showDialog({
    int? defaultParentId,
    String defaultType = LocationModel.roomType,
  }) async {
    if (!context.requireModuleAction(ModuleAction.create)) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => _QuickAddLocationDialog(
        rooms: _rooms,
        childMap: _childMap,
        defaultParentId: defaultParentId,
        defaultKind: defaultType == LocationModel.roomType
            ? LocationModel.roomType
            : LocationModel.genericLocationType,
      ),
    );
    if (ok == true) _load();
  }

  Future<void> _exportCsv() async {
    if (!context.requireModuleAction(ModuleAction.export)) return;
    final buf = StringBuffer()
      ..writeln('ID,Code,Name,Type,Temperature,Capacity,Parent,Notes');
    final roomIndexById = {
      for (var i = 0; i < _rooms.length; i++) _rooms[i].id: i,
    };
    for (final room in _rooms) {
      final rIdx = roomIndexById[room.id]!;
      final code = room.code ?? roomCode(rIdx);
      buf.writeln(
        '${room.id},"$code","${room.name}","${room.type}","${room.temperature ?? ''}","${room.capacity ?? ''}","","${room.notes ?? ''}"',
      );
      final kids = _childMap[room.id] ?? [];
      for (var i = 0; i < kids.length; i++) {
        final c = kids[i];
        final ccode = c.code ?? childCode(rIdx, i);
        buf.writeln(
          '${c.id},"$ccode","${c.name}","${c.type}","${c.temperature ?? ''}","${c.capacity ?? ''}","${room.name}","${c.notes ?? ''}"',
        );
      }
    }
    for (final o in _orphans) {
      buf.writeln(
        '${o.id},"","${o.name}","${o.type}","${o.temperature ?? ''}","${o.capacity ?? ''}","","${o.notes ?? ''}"',
      );
    }
    try {
      final dir =
          await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
      final file = File(
        '${dir.path}/locations_${DateTime.now().millisecondsSinceEpoch}.csv',
      );
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
    return Column(
      children: [
        _buildToolbar(context),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _buildBody(context),
        ),
      ],
    );
  }

  Widget _buildToolbar(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: context.appSurface2,
        border: Border(bottom: BorderSide(color: context.appBorder)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
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
          Text(
            'Rooms & Locations',
            style: GoogleFonts.spaceGrotesk(
              color: context.appTextPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: SizedBox(
              height: 36,
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _search = v.toLowerCase()),
                style: GoogleFonts.spaceGrotesk(
                  color: context.appTextPrimary,
                  fontSize: 13,
                ),
                decoration: InputDecoration(
                  hintText: 'Search rooms and locations...',
                  hintStyle: GoogleFonts.spaceGrotesk(
                    color: context.appTextMuted,
                    fontSize: 13,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: context.appTextMuted,
                    size: 16,
                  ),
                  suffixIcon: _search.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.clear,
                            size: 14,
                            color: context.appTextMuted,
                          ),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _search = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: context.appSurface3,
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: context.appBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: context.appBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppDS.accent),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (!_loading) ...[
            _buildSummaryChip(
              context,
              icon: Icons.meeting_room_outlined,
              label: '${_rooms.length} room${_rooms.length == 1 ? '' : 's'}',
              color: const Color(0xFF6366F1),
            ),
            const SizedBox(width: 6),
            _buildSummaryChip(
              context,
              icon: Icons.place_outlined,
              label:
                  '$_locationCount location${_locationCount == 1 ? '' : 's'}',
              color: const Color(0xFF3B82F6),
            ),
            if (_orphans.isNotEmpty) ...[
              const SizedBox(width: 6),
              _buildSummaryChip(
                context,
                icon: Icons.link_off_outlined,
                label: '${_orphans.length} without room',
                color: AppDS.orange,
              ),
            ],
            const SizedBox(width: 8),
          ],
          Tooltip(
            message: 'Export CSV',
            child: IconButton(
              icon: Icon(
                Icons.download_outlined,
                color: context.appTextSecondary,
                size: 18,
              ),
              onPressed: _exportCsv,
            ),
          ),
          const SizedBox(width: 4),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              minimumSize: const Size(0, 36),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => _showDialog(),
            icon: const Icon(Icons.add, size: 16),
            label: Text('Add', style: GoogleFonts.spaceGrotesk(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final q = _search;

    final visibleRooms = _rooms.where((r) {
      if (q.isEmpty) return true;
      if (r.name.toLowerCase().contains(q)) return true;
      return (_childMap[r.id] ?? []).any(
        (c) =>
            c.name.toLowerCase().contains(q) ||
            (c.temperature?.toLowerCase().contains(q) ?? false),
      );
    }).toList();

    final visibleOrphans = q.isEmpty
        ? _orphans
        : _orphans
              .where(
                (o) =>
                    o.name.toLowerCase().contains(q) ||
                    (o.temperature?.toLowerCase().contains(q) ?? false),
              )
              .toList();

    if (visibleRooms.isEmpty && visibleOrphans.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.place_outlined, size: 48, color: context.appTextMuted),
            const SizedBox(height: 12),
            Text(
              q.isEmpty
                  ? 'No rooms yet.\nClick "Add" to create your first room.'
                  : 'No rooms or locations match "$_search"',
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(
                color: context.appTextMuted,
                fontSize: 15,
              ),
            ),
          ],
        ),
      );
    }

    const hPad = 16.0;
    const spacing = 12.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(hPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (visibleRooms.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Rooms',
                style: GoogleFonts.spaceGrotesk(
                  color: context.appTextPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (visibleRooms.isNotEmpty)
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              proxyDecorator: (child, _, _) => Material(
                color: Colors.transparent,
                elevation: 6,
                borderRadius: BorderRadius.circular(12),
                child: child,
              ),
              onReorderItem: (oldIndex, newIndex) {
                // The mapping below expects the legacy, pre-removal index.
                if (newIndex > oldIndex) newIndex += 1;
                debugPrint(
                  'locations: rooms onReorder old=$oldIndex '
                  'new=$newIndex visible=${visibleRooms.length} '
                  'all=${_rooms.length}',
                );
                if (q.isNotEmpty) {
                  debugPrint('locations: skip reorder — search active');
                  return;
                }
                try {
                  final movedId = visibleRooms[oldIndex].id;
                  final anchorId = newIndex >= visibleRooms.length
                      ? null
                      : visibleRooms[newIndex].id;
                  final srcIdx = _rooms.indexWhere((r) => r.id == movedId);
                  int dstIdx = anchorId == null
                      ? _rooms.length
                      : _rooms.indexWhere((r) => r.id == anchorId);
                  debugPrint(
                    'locations: movedId=$movedId anchorId=$anchorId '
                    'srcIdx=$srcIdx dstIdx=$dstIdx',
                  );
                  if (srcIdx < 0 || dstIdx < 0) {
                    debugPrint('locations: aborting — invalid index map');
                    return;
                  }
                  _reorderRooms(srcIdx, dstIdx > srcIdx ? dstIdx + 1 : dstIdx);
                } catch (e, st) {
                  debugPrint('locations: rooms onReorder threw: $e\n$st');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Reorder failed: $e',
                          style: GoogleFonts.spaceGrotesk(color: Colors.white),
                        ),
                        backgroundColor: AppDS.red,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    );
                  }
                }
              },
              children: [
                for (final room in visibleRooms)
                  Padding(
                    key: ValueKey('room-${room.id}'),
                    padding: const EdgeInsets.only(bottom: spacing),
                    child: Builder(
                      builder: (ctx) {
                        final kids = (_childMap[room.id] ?? []).where((c) {
                          if (q.isEmpty) return true;
                          return c.name.toLowerCase().contains(q) ||
                              (c.temperature?.toLowerCase().contains(q) ??
                                  false);
                        }).toList();
                        final allKids = _childMap[room.id] ?? [];
                        final childIndexById = {
                          for (var i = 0; i < allKids.length; i++)
                            allKids[i].id: i,
                        };
                        final roomIndex = _rooms.indexOf(room);
                        final visibleIndex = visibleRooms.indexOf(room);
                        return _RoomCard(
                          key: ValueKey(room.id),
                          room: room,
                          roomCode: room.code ?? roomCode(roomIndex),
                          users: _users,
                          dragIndex: q.isEmpty ? visibleIndex : null,
                          children: kids,
                          childCodes: {
                            for (final c in kids)
                              c.id:
                                  c.code ??
                                  childCode(
                                    roomIndex,
                                    childIndexById[c.id] ?? 0,
                                  ),
                          },
                          onTap: () => _navigate(room),
                          onTapChild: _navigate,
                          onAddChild: () => _showDialog(
                            defaultParentId: room.id,
                            defaultType: LocationModel.defaultLocationType,
                          ),
                          onEditAll: () => _showEditAllDialog(
                            room,
                            room.code ?? roomCode(roomIndex),
                            roomIndex,
                            allKids,
                          ),
                          onReorderChildren: q.isEmpty
                              ? (oldIdx, newIdx) =>
                                    _reorderChildren(room.id, oldIdx, newIdx)
                              : null,
                        );
                      },
                    ),
                  ),
              ],
            ),
          if (visibleOrphans.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Locations Without Room',
                  style: GoogleFonts.spaceGrotesk(
                    color: context.appTextPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                _OrphanCard(
                  key: const ValueKey('__orphans__'),
                  locations: visibleOrphans,
                  onTap: _navigate,
                  onAdd: () => _showDialog(
                    defaultType: LocationModel.defaultLocationType,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
