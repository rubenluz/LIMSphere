//QRcode is not being update to supabase, check and update the code to make sure that the QRcode is being updated to supabase when the location is being updated. Also check machines, reagents, and other tables that have QRcode to make sure they are being updated as well.

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide LocalStorage;
import '../supabase/supabase_manager.dart';
import '/core/data_cache.dart';
import '/theme/theme.dart';
import 'location_model.dart';
import 'location_detail_page.dart';

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
      MaterialPageRoute(builder: (_) => LocationDetailPage(locationId: loc.id)));

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

  Future<void> _delete(LocationModel loc) async {
    final kids = _childMap[loc.id]?.length ?? 0;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.appSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Delete "${loc.name}"?',
            style: GoogleFonts.spaceGrotesk(color: ctx.appTextPrimary)),
        content: Text(
          kids > 0
              ? 'This room has $kids child location(s) that will become unassigned.'
              : 'This cannot be undone.',
          style: GoogleFonts.spaceGrotesk(color: ctx.appTextSecondary),
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
    if (ok != true) return;
    try {
      await Supabase.instance.client
          .from('storage_locations')
          .delete()
          .eq('location_id', loc.id);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }

  void _showQr(LocationModel loc) {
    final ref = SupabaseManager.projectRef ?? 'local';
    final data = 'bluelims://$ref/location/${loc.id}';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.appSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('QR — ${loc.name}',
            style: GoogleFonts.spaceGrotesk(color: ctx.appTextPrimary)),
        content: SizedBox(
          width: 260,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                color: Colors.white,
                padding: const EdgeInsets.all(12),
                child: QrImageView(data: data, size: 200)),
            const SizedBox(height: 12),
            Text(data,
                style:
                    GoogleFonts.spaceGrotesk(color: ctx.appTextMuted, fontSize: 11)),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: data));
              if (context.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Link copied')));
              }
            },
            child:
                Text('Copy Link', style: GoogleFonts.spaceGrotesk(color: AppDS.accent)),
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

    // Group rooms into rows of 3 (see _buildRoomCard below)
    const cols = 3;
    const hPad = 16.0;
    const spacing = 12.0;
    final rows = <List<LocationModel>>[];
    for (var i = 0; i < visibleRooms.length; i += cols) {
      rows.add(visibleRooms.sublist(
          i, (i + cols).clamp(0, visibleRooms.length)));
    }

    Widget buildRoomCard(LocationModel room) {
      final kids = (_childMap[room.id] ?? []).where((c) {
        if (q.isEmpty) return true;
        return c.name.toLowerCase().contains(q) ||
            (c.temperature?.toLowerCase().contains(q) ?? false);
      }).toList();
      return _RoomCard(
        key: ValueKey(room.id),
        room: room,
        children: kids,
        onDelete: () => _delete(room),
        onQr: () => _showQr(room),
        onTap: () => _navigate(room),
        onDeleteChild: _delete,
        onQrChild: _showQr,
        onTapChild: _navigate,
        onAddChild: () =>
            _showDialog(defaultParentId: room.id, defaultType: 'freezer'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(hPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...rows.map((rowRooms) => Padding(
            padding: const EdgeInsets.only(bottom: spacing),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (int j = 0; j < cols; j++) ...[
                    if (j > 0) const SizedBox(width: spacing),
                    Expanded(
                      child: j < rowRooms.length
                          ? buildRoomCard(rowRooms[j])
                          : const SizedBox(),
                    ),
                  ],
                ],
              ),
            ),
          )),
          if (visibleOrphans.isNotEmpty)
            _OrphanCard(
              key: const ValueKey('__orphans__'),
              locations: visibleOrphans,
              onDelete: _delete,
              onQr: _showQr,
              onTap: _navigate,
              onAdd: () => _showDialog(defaultType: 'shelf'),
            ),
        ],
      ),
    );
  }
}

// ─── Room Card ──────────────────────────────────────────────────────────────────
class _RoomCard extends StatelessWidget {
  final LocationModel room;
  final List<LocationModel> children;
  final VoidCallback onDelete;
  final VoidCallback onQr;
  final VoidCallback onTap;
  final void Function(LocationModel) onDeleteChild;
  final void Function(LocationModel) onQrChild;
  final void Function(LocationModel) onTapChild;
  final VoidCallback onAddChild;

  const _RoomCard({
    required super.key,
    required this.room,
    required this.children,
    required this.onDelete,
    required this.onQr,
    required this.onTap,
    required this.onDeleteChild,
    required this.onQrChild,
    required this.onTapChild,
    required this.onAddChild,
  });

  static const _roomAccent = Color(0xFF6366F1);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildHeader(context),
        if (children.isNotEmpty) ...[
          Divider(height: 1, color: context.appBorder),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: children
                  .map((c) => _ChildTile(
                        loc: c,
                        onDelete: () => onDeleteChild(c),
                        onQr: () => onQrChild(c),
                        onTap: () => onTapChild(c),
                      ))
                  .toList(),
            ),
          ),
        ],
        _buildFooter(context),
      ]),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appSurface2,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
      child: Row(children: [
        // Room icon
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _roomAccent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.meeting_room_outlined,
              color: _roomAccent, size: 16),
        ),
        const SizedBox(width: 10),
        // Name + meta — tappable to open detail
        Expanded(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(room.name,
                    style: GoogleFonts.spaceGrotesk(
                        color: context.appTextPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                if (room.temperature != null || room.capacity != null)
                  Row(children: [
                    if (room.temperature != null) ...[
                      Icon(Icons.thermostat_outlined,
                          size: 11, color: context.appTextMuted),
                      const SizedBox(width: 2),
                      Text(room.temperature!,
                          style: GoogleFonts.spaceGrotesk(
                              color: context.appTextMuted, fontSize: 11)),
                      const SizedBox(width: 8),
                    ],
                    if (room.capacity != null) ...[
                      Icon(Icons.storage_outlined,
                          size: 11, color: context.appTextMuted),
                      const SizedBox(width: 2),
                      Text('Cap: ${room.capacity}',
                          style: GoogleFonts.spaceGrotesk(
                              color: context.appTextMuted, fontSize: 11)),
                    ],
                  ]),
              ],
            ),
          ),
        ),
        // Children count badge
        if (children.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: _roomAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('${children.length}',
                style: GoogleFonts.spaceGrotesk(
                    color: _roomAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 4),
        ],
        _Btn(Icons.qr_code, 'QR Code', onQr),
        _Btn(Icons.delete_outline, 'Delete', onDelete),
        const SizedBox(width: 4),
      ]),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onAddChild,
        borderRadius:
            const BorderRadius.vertical(bottom: Radius.circular(12)),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: context.appBorder)),
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(12)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.add, size: 13, color: context.appTextMuted),
            const SizedBox(width: 4),
            Text('Add location to room',
                style: GoogleFonts.spaceGrotesk(
                    color: context.appTextMuted, fontSize: 12)),
          ]),
        ),
      ),
    );
  }
}

// ─── Child Tile ─────────────────────────────────────────────────────────────────
class _ChildTile extends StatelessWidget {
  final LocationModel loc;
  final VoidCallback onDelete;
  final VoidCallback onQr;
  final VoidCallback onTap;

  const _ChildTile({
    required this.loc,
    required this.onDelete,
    required this.onQr,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = LocationModel.typeAccent(loc.type);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
          decoration: BoxDecoration(
            color: context.appSurface3,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: context.appBorder),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(LocationModel.typeIcon(loc.type), color: accent, size: 16),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(loc.name,
                    style: GoogleFonts.spaceGrotesk(
                        color: context.appTextPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
                if (loc.temperature != null)
                  Text(loc.temperature!,
                      style: GoogleFonts.spaceGrotesk(
                          color: context.appTextMuted, fontSize: 11)),
              ],
            ),
            const SizedBox(width: 2),
            _Btn(Icons.qr_code, 'QR', onQr, size: 14),
            _Btn(Icons.delete_outline, 'Delete', onDelete, size: 14),
          ]),
        ),
      ),
    );
  }
}

// ─── Orphan Card ────────────────────────────────────────────────────────────────
class _OrphanCard extends StatelessWidget {
  final List<LocationModel> locations;
  final void Function(LocationModel) onDelete;
  final void Function(LocationModel) onQr;
  final void Function(LocationModel) onTap;
  final VoidCallback onAdd;

  const _OrphanCard({
    required super.key,
    required this.locations,
    required this.onDelete,
    required this.onQr,
    required this.onTap,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          decoration: BoxDecoration(
            color: context.appSurface2,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            Icon(Icons.inbox_outlined, color: context.appTextMuted, size: 16),
            const SizedBox(width: 8),
            Text('Unassigned',
                style: GoogleFonts.spaceGrotesk(
                    color: context.appTextSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
            const Spacer(),
            Text(
                '${locations.length} location${locations.length == 1 ? '' : 's'} not in a room',
                style: GoogleFonts.spaceGrotesk(
                    color: context.appTextMuted, fontSize: 11)),
          ]),
        ),
        Divider(height: 1, color: context.appBorder),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: locations
                .map((l) => _ChildTile(
                      loc: l,
                      onDelete: () => onDelete(l),
                      onQr: () => onQr(l),
                      onTap: () => onTap(l),
                    ))
                .toList(),
          ),
        ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onAdd,
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(12)),
            child: Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: context.appBorder)),
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(12)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add, size: 13, color: context.appTextMuted),
                const SizedBox(width: 4),
                Text('Add unassigned location',
                    style: GoogleFonts.spaceGrotesk(
                        color: context.appTextMuted, fontSize: 12)),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

// ─── Small icon button ───────────────────────────────────────────────────────────
class _Btn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final double size;

  const _Btn(this.icon, this.tooltip, this.onPressed, {this.size = 16});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: size, color: context.appTextSecondary),
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(4),
      constraints:
          BoxConstraints(minWidth: size + 10, minHeight: size + 10),
    );
  }
}

// ─── Add/Edit Form Dialog ────────────────────────────────────────────────────────
class _LocationFormDialog extends StatefulWidget {
  final LocationModel? existing;
  final List<LocationModel> allLocations;
  final int? defaultParentId;
  final String defaultType;

  const _LocationFormDialog({
    this.existing,
    required this.allLocations,
    this.defaultParentId,
    this.defaultType = 'room',
  });

  @override
  State<_LocationFormDialog> createState() => _LocationFormDialogState();
}

class _LocationFormDialogState extends State<_LocationFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _tempCtrl;
  late final TextEditingController _capCtrl;
  late final TextEditingController _notesCtrl;
  late String _type;
  late int? _parentId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _tempCtrl = TextEditingController(text: e?.temperature ?? '');
    _capCtrl = TextEditingController(
        text: e?.capacity != null ? e!.capacity.toString() : '');
    _notesCtrl = TextEditingController(text: e?.notes ?? '');
    _type = e?.type ?? widget.defaultType;
    _parentId = e?.parentId ?? widget.defaultParentId;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _tempCtrl.dispose();
    _capCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final data = {
        'location_name': _nameCtrl.text.trim(),
        'location_type': _type,
        if (_tempCtrl.text.isNotEmpty)
          'location_temperature': _tempCtrl.text.trim(),
        if (_capCtrl.text.isNotEmpty)
          'location_capacity': int.tryParse(_capCtrl.text.trim()),
        if (_parentId != null) 'location_parent_id': _parentId,
        if (_notesCtrl.text.isNotEmpty)
          'location_notes': _notesCtrl.text.trim(),
      };
      if (widget.existing != null) {
        await Supabase.instance.client
            .from('storage_locations')
            .update(data)
            .eq('location_id', widget.existing!.id);
      } else {
        await Supabase.instance.client
            .from('storage_locations')
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
    final isEdit = widget.existing != null;
    final parentChoices = widget.allLocations
        .where((l) => widget.existing == null || l.id != widget.existing!.id)
        .toList();

    return AlertDialog(
      backgroundColor: context.appSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(isEdit ? 'Edit Location' : 'Add Location',
          style: GoogleFonts.spaceGrotesk(
              color: context.appTextPrimary, fontWeight: FontWeight.w600)),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _DarkField(
                controller: _nameCtrl,
                label: 'Name *',
                validator: (v) =>
                    v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              _DarkDropdown<String>(
                label: 'Type',
                value: _type,
                items: LocationModel.typeOptions
                    .map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(LocationModel.typeLabel(t),
                              style: GoogleFonts.spaceGrotesk(
                                  color: context.appTextPrimary, fontSize: 13)),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _type = v ?? 'room'),
              ),
              const SizedBox(height: 12),
              _DarkField(
                  controller: _tempCtrl,
                  label: 'Temperature (e.g. -80°C)'),
              const SizedBox(height: 12),
              _DarkField(
                controller: _capCtrl,
                label: 'Capacity',
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v != null && v.isNotEmpty && int.tryParse(v) == null) {
                    return 'Must be a number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _DarkDropdown<int?>(
                label: 'Parent Room',
                value: _parentId,
                items: [
                  DropdownMenuItem<int?>(
                    value: null,
                    child: Text('None',
                        style: GoogleFonts.spaceGrotesk(
                            color: context.appTextMuted, fontSize: 13)),
                  ),
                  ...parentChoices.map((l) => DropdownMenuItem<int?>(
                        value: l.id,
                        child: Text(l.name,
                            style: GoogleFonts.spaceGrotesk(
                                color: context.appTextPrimary, fontSize: 13)),
                      )),
                ],
                onChanged: (v) => setState(() => _parentId = v),
              ),
              const SizedBox(height: 12),
              _DarkField(
                  controller: _notesCtrl, label: 'Notes', maxLines: 2),
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
            backgroundColor: const Color(0xFF6366F1),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(isEdit ? 'Save' : 'Create',
                  style: GoogleFonts.spaceGrotesk()),
        ),
      ],
    );
  }
}

// ─── Shared dark form widgets ────────────────────────────────────────────────────
class _DarkField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _DarkField({
    required this.controller,
    required this.label,
    this.maxLines = 1,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
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
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppDS.red)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}

class _DarkDropdown<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final void Function(T?) onChanged;

  const _DarkDropdown({
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
}
