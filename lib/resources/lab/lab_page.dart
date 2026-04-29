// lab_page.dart - 2D top-down lab floor-plan viewer.
// First cut: lays rooms out in a default grid (sort_order based) when no
// per-room geometry is stored yet. Each room is a tappable rectangle that
// reveals its sub-locations in a right-hand panel. The Builder page (TODO)
// will replace the default grid with hand-placed shapes via a JSONB column
// on storage_locations.
//
// Embedded in MenuPage's content area (Column, no Scaffold). Permission
// gated through the resources module's `user_table_resources` column;
// the "Open in Builder" entry only appears when canEditModule is true.

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide LocalStorage;

import '/theme/theme.dart';
import '/theme/module_permission.dart';
import '../locations/detail_widgets.dart';
import '../locations/location_detail_page.dart';
import '../locations/location_model.dart';
import '../locations/room_detail_page.dart';
import 'lab_builder_page.dart';

// Default tile dimensions when a room has no stored layout.
const double _kDefaultRoomW = 200;
const double _kDefaultRoomH = 130;
const double _kDefaultGap   = 24;
const int    _kDefaultCols  = 4;
const double _kMinCanvasW = 800;
const double _kMinCanvasH = 600;
const double _kViewportFitPadding = 40;
const double _kMinViewerScale = 0.01;

class LabPage extends StatefulWidget {
  const LabPage({super.key});

  @override
  State<LabPage> createState() => _LabPageState();
}

class _LabPageState extends State<LabPage> {
  List<LocationModel> _rooms = [];
  Map<int, List<LocationModel>> _childMap = {};
  Map<int, LocationModel> _locById = {};
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _reagents = [];
  List<_Decor> _decors = [];
  List<_CanvasLocationView> _locations = [];
  // location_id (sub-location OR room) → containing room id.
  Map<int, int> _locToRoom = {};
  Map<int, _RoomGeom> _geom = {};
  Size? _backgroundSize;
  int? _selectedRoomId;
  _RoomPanelMode _roomPanelMode = _RoomPanelMode.locations;
  _ReagentSort _reagentSort = _ReagentSort.code;
  bool _reagentSortDescending = false;
  bool _showLocations = false;
  bool _loading = true;
  String _search = '';
  final _searchCtrl = TextEditingController();
  final _viewerCtrl = TransformationController();
  Size? _lastAutoFitViewport;
  Rect? _lastAutoFitBounds;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _viewerCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        Supabase.instance.client
            .from('storage_locations')
            .select('*, parent:location_parent_id(location_name)')
            .order('location_sort_order'),
        Supabase.instance.client
            .from('users')
            .select('user_id, user_email, user_name, user_phone, '
                'user_institution, user_group, user_role')
            .order('user_name'),
        Supabase.instance.client
            .from('reagents')
            .select('reagent_id, reagent_code, reagent_name, '
                'reagent_location_id')
            .order('reagent_code'),
        Supabase.instance.client
            .from('app_meta')
            .select('meta_settings')
            .eq('meta_initialized', true)
            .limit(1)
            .maybeSingle(),
      ]);
      final locRows     = results[0] as List<dynamic>;
      final userRows    = results[1] as List<dynamic>;
      final reagentRows = results[2] as List<dynamic>;
      final metaRowRaw  = results[3];

      final items = locRows.map<LocationModel>((r) {
        final p = (r as Map)['parent'];
        return LocationModel.fromMap({
          ...Map<String, dynamic>.from(r),
          'parent_name': p is Map ? p['location_name'] as String? : null,
        });
      }).toList();
      final layoutById = <int, dynamic>{
        for (final row in locRows)
          if ((row as Map)['location_id'] != null)
            (row['location_id'] as num).toInt(): row['location_layout'],
      };
      final locById = {for (final item in items) item.id: item};

      final rooms = items.where((l) => l.isRoom).toList()
        ..sort(_bySortThenName);
      final roomIds = {for (final r in rooms) r.id};
      final children = <int, List<LocationModel>>{};
      for (final l in items) {
        if (l.isRoom) continue;
        if (l.parentId != null && roomIds.contains(l.parentId)) {
          children.putIfAbsent(l.parentId!, () => []).add(l);
        }
      }
      for (final list in children.values) {
        list.sort(_bySortThenName);
      }

      // Build geometry: prefer stored layout (JSONB column on the room row,
      // not yet wired through the model — read raw), fall back to a grid
      // derived from sort order so the page is usable today.
      final geom = <int, _RoomGeom>{};
      for (var i = 0; i < rooms.length; i++) {
        final room = rooms[i];
        final raw = layoutById[room.id];
        final parsed = _RoomGeom.tryParse(raw);
        geom[room.id] = parsed ?? _gridFallback(i);
      }

      final locationShapes = <_CanvasLocationView>[];
      for (final room in rooms) {
        for (final loc in (children[room.id] ?? const <LocationModel>[])) {
          final parsed = _RoomGeom.tryParse(layoutById[loc.id]);
          if (parsed == null) continue;
          locationShapes.add(_CanvasLocationView(
            id: loc.id,
            parentRoomId: room.id,
            name: stripLocationCodePrefix(loc.name),
            type: loc.type,
            geom: parsed,
          ));
        }
      }

      final decors = <_Decor>[];
      Size? backgroundSize;
      if (metaRowRaw is Map) {
        final meta = Map<String, dynamic>.from(metaRowRaw);
        final settingsRaw = meta['meta_settings'];
        Map<String, dynamic> settings = {};
        if (settingsRaw is Map) {
          settings = Map<String, dynamic>.from(settingsRaw);
        } else if (settingsRaw is String) {
          try {
            final decoded = jsonDecode(settingsRaw);
            if (decoded is Map) settings = Map<String, dynamic>.from(decoded);
          } catch (_) {/* keep empty */}
        }
        final layout = settings['lab_layout'];
        if (layout is Map) {
          backgroundSize = _parseCanvasSize(layout['canvas_size']);
          final list = layout['decorations'];
          if (list is List) {
            for (final item in list) {
              final decor = _Decor.tryParse(item);
              if (decor != null) decors.add(decor);
            }
          }
        }
      }

      // Build location-id → room-id index so reagent searches can resolve
      // a sub-location back to the room that gets highlighted on the map.
      final locToRoom = <int, int>{};
      for (final room in rooms) {
        locToRoom[room.id] = room.id;
        for (final c in (children[room.id] ?? const [])) {
          locToRoom[c.id] = room.id;
        }
      }

      if (!mounted) return;
      setState(() {
        _rooms = rooms;
        _childMap = children;
        _locById = locById;
        _users = List<Map<String, dynamic>>.from(userRows);
        _reagents = List<Map<String, dynamic>>.from(reagentRows);
        _decors = decors;
        _locations = locationShapes;
        _locToRoom = locToRoom;
        _geom = geom;
        _backgroundSize = backgroundSize;
        _lastAutoFitViewport = null;
        _lastAutoFitBounds = null;
        _loading = false;
        if (_selectedRoomId != null && !roomIds.contains(_selectedRoomId)) {
          _selectedRoomId = null;
        }
      });
    } catch (e) {
      debugPrint('lab_page: load failed: $e');
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to load lab layout: $e',
            style: GoogleFonts.spaceGrotesk(color: Colors.white)),
        backgroundColor: AppDS.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ));
    }
  }

  int _bySortThenName(LocationModel a, LocationModel b) {
    final ao = a.sortOrder, bo = b.sortOrder;
    if (ao != null && bo != null) return ao.compareTo(bo);
    if (ao != null) return -1;
    if (bo != null) return 1;
    return a.name.compareTo(b.name);
  }

  _RoomGeom _gridFallback(int idx) {
    final col = idx % _kDefaultCols;
    final row = idx ~/ _kDefaultCols;
    return _RoomGeom(
      x: col * (_kDefaultRoomW + _kDefaultGap) + _kDefaultGap,
      y: row * (_kDefaultRoomH + _kDefaultGap) + _kDefaultGap,
      w: _kDefaultRoomW,
      h: _kDefaultRoomH,
    );
  }

  Size? _parseCanvasSize(dynamic raw) {
    if (raw == null) return null;
    try {
      final map = raw is String ? jsonDecode(raw) : raw;
      if (map is! Map) return null;
      final width = ((map['width'] ?? map['w']) as num?)?.toDouble();
      final height = ((map['height'] ?? map['h']) as num?)?.toDouble();
      if (width == null || height == null || width <= 0 || height <= 0) {
        return null;
      }
      return Size(width, height);
    } catch (_) {
      return null;
    }
  }

  Rect? get _occupiedBounds {
    if (_geom.isEmpty && _decors.isEmpty && _locations.isEmpty) return null;
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = 0;
    double maxY = 0;

    void include(_RoomGeom geom) {
      minX = math.min(minX, geom.x);
      minY = math.min(minY, geom.y);
      maxX = math.max(maxX, geom.x + geom.w);
      maxY = math.max(maxY, geom.y + geom.h);
    }

    for (final g in _geom.values) {
      include(g);
    }
    for (final loc in _locations) {
      include(loc.geom);
    }
    for (final decor in _decors) {
      include(_RoomGeom(x: decor.x, y: decor.y, w: decor.w, h: decor.h));
    }

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  Size get _canvasSize {
    final occupied = _occupiedBounds;
    final fallback = occupied == null
        ? const Size(_kMinCanvasW, _kMinCanvasH)
        : Size(
            math.max(_kMinCanvasW, occupied.right + _kDefaultGap),
            math.max(_kMinCanvasH, occupied.bottom + _kDefaultGap),
          );
    final background = _backgroundSize;
    if (background == null) return fallback;
    return Size(
      math.max(background.width, fallback.width),
      math.max(background.height, fallback.height),
    );
  }

  Rect get _fitBounds {
    final background = _backgroundSize;
    if (background != null) {
      final canvas = _canvasSize;
      return Offset.zero & canvas;
    }
    return _occupiedBounds ?? (Offset.zero & _canvasSize);
  }

  void _scheduleAutoFit(Size viewport) {
    if (viewport.width <= 0 || viewport.height <= 0) return;
    final target = _fitBounds;
    if (_lastAutoFitViewport == viewport && _lastAutoFitBounds == target) {
      return;
    }
    _lastAutoFitViewport = viewport;
    _lastAutoFitBounds = target;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _applyAutoFit(viewport, target);
    });
  }

  void _applyAutoFit(Size viewport, Rect target) {
    final paddedWidth = math.max(1.0, viewport.width - _kViewportFitPadding * 2);
    final paddedHeight =
        math.max(1.0, viewport.height - _kViewportFitPadding * 2);
    final scaleX = paddedWidth / math.max(target.width, 1.0);
    final scaleY = paddedHeight / math.max(target.height, 1.0);
    final scale =
        math.min(scaleX, scaleY).clamp(_kMinViewerScale, 4.0).toDouble();
    final dx =
        ((viewport.width - target.width * scale) / 2 - target.left * scale)
            .toDouble();
    final dy =
        ((viewport.height - target.height * scale) / 2 - target.top * scale)
            .toDouble();
    final matrix = Matrix4.identity()..scale(scale);
    matrix.setTranslationRaw(dx, dy, 0);
    _viewerCtrl.value = matrix;
  }

  LocationModel? get _selectedRoom {
    final id = _selectedRoomId;
    if (id == null) return null;
    for (final r in _rooms) {
      if (r.id == id) return r;
    }
    return null;
  }

  List<Map<String, dynamic>> _reagentsInRoom(int roomId) {
    return _sortReagents(_reagents.where((r) {
      final locId = r['reagent_location_id'];
      if (locId is! num) return false;
      return _locToRoom[locId.toInt()] == roomId;
    }).toList());
  }

  List<Map<String, dynamic>> _sortReagents(List<Map<String, dynamic>> reagents) {
    final out = List<Map<String, dynamic>>.from(reagents);
    out.sort((a, b) {
      final codeA = ((a['reagent_code'] as String?) ?? '').trim().toLowerCase();
      final codeB = ((b['reagent_code'] as String?) ?? '').trim().toLowerCase();
      final nameA = ((a['reagent_name'] as String?) ?? '').trim().toLowerCase();
      final nameB = ((b['reagent_name'] as String?) ?? '').trim().toLowerCase();
      final primary = switch (_reagentSort) {
        _ReagentSort.code => codeA.compareTo(codeB),
        _ReagentSort.name => nameA.compareTo(nameB),
      };
      if (primary != 0) {
        return _reagentSortDescending ? -primary : primary;
      }
      final secondary = switch (_reagentSort) {
        _ReagentSort.code => nameA.compareTo(nameB),
        _ReagentSort.name => codeA.compareTo(codeB),
      };
      if (secondary != 0) {
        return _reagentSortDescending ? -secondary : secondary;
      }
      final idA = (a['reagent_id'] as num?)?.toInt() ?? 0;
      final idB = (b['reagent_id'] as num?)?.toInt() ?? 0;
      final fallback = idA.compareTo(idB);
      return _reagentSortDescending ? -fallback : fallback;
    });
    return out;
  }

  String _reagentLocationLabel(Map<String, dynamic> reagent, int roomId) {
    final locId = reagent['reagent_location_id'];
    if (locId is! num) return 'No location assigned';
    final id = locId.toInt();
    if (id == roomId) return 'Stored directly in room';
    final loc = _locById[id];
    if (loc == null) return 'Sub-location';
    final name = stripLocationCodePrefix(loc.name);
    if (name.isNotEmpty) return name;
    return LocationModel.typeLabel(loc.type);
  }

  bool _matchesSearch(LocationModel room) {
    if (_search.isEmpty) return true;
    return _searchRoomHits.contains(room.id);
  }

  /// Reagents whose code or name contain the current search query. Empty
  /// list when the search field is blank.
  List<Map<String, dynamic>> get _matchingReagents {
    if (_search.isEmpty) return const [];
    final q = _search;
    return _reagents.where((r) {
      final code = (r['reagent_code'] as String?)?.toLowerCase() ?? '';
      final name = (r['reagent_name'] as String?)?.toLowerCase() ?? '';
      return code.contains(q) || name.contains(q);
    }).toList();
  }

  /// Union of room IDs that should light up for the current search:
  /// rooms whose own name/code/sub-location names match, plus rooms that
  /// contain a matching reagent (resolved via _locToRoom).
  Set<int> get _searchRoomHits {
    if (_search.isEmpty) return const {};
    final q = _search;
    final hits = <int>{};
    for (final room in _rooms) {
      if (room.name.toLowerCase().contains(q)) {
        hits.add(room.id);
        continue;
      }
      if (_roomCodeFor(room).toLowerCase().contains(q)) {
        hits.add(room.id);
        continue;
      }
      final kids = _childMap[room.id] ?? const [];
      if (kids.any((c) => c.name.toLowerCase().contains(q))) {
        hits.add(room.id);
      }
    }
    for (final r in _matchingReagents) {
      final locId = r['reagent_location_id'] != null
          ? (r['reagent_location_id'] as num).toInt()
          : null;
      if (locId == null) continue;
      final roomId = _locToRoom[locId];
      if (roomId != null) hits.add(roomId);
    }
    return hits;
  }

  String _roomCodeFor(LocationModel room) {
    final idx = _rooms.indexWhere((r) => r.id == room.id);
    return idx >= 0 ? 'R${idx + 1}' : '';
  }

  void _openRoomDetail(LocationModel room) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RoomDetailPage(locationId: room.id)),
    );
    if (mounted) _load();
  }

  void _openLocationDetail(LocationModel loc) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LocationDetailPage(locationId: loc.id)),
    );
    if (mounted) _load();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _buildToolbar(context),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _rooms.isEmpty
                ? _buildEmptyState(context)
                : _buildBody(context),
      ),
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
        if (MediaQuery.of(context).size.width < 700)
          IconButton(
            icon: const Icon(Icons.menu_rounded, size: 20),
            color: context.appTextSecondary,
            tooltip: 'Menu',
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        const Icon(Icons.map_outlined, color: AppDS.accent, size: 18),
        const SizedBox(width: 8),
        Text('Lab Map',
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
              onChanged: (v) =>
                  setState(() => _search = v.trim().toLowerCase()),
              style: GoogleFonts.spaceGrotesk(
                  color: context.appTextPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search rooms…',
                hintStyle: GoogleFonts.spaceGrotesk(
                    color: context.appTextMuted, fontSize: 13),
                prefixIcon:
                    Icon(Icons.search, color: context.appTextMuted, size: 16),
                suffixIcon: _search.isEmpty
                    ? null
                    : IconButton(
                        icon: Icon(Icons.clear,
                            size: 14, color: context.appTextMuted),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _search = '');
                        },
                      ),
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
        OutlinedButton.icon(
          onPressed: () => setState(() => _showLocations = !_showLocations),
          icon: Icon(
            _showLocations
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            size: 14,
          ),
          label: Text(_showLocations ? 'Hide locations' : 'Show locations'),
          style: OutlinedButton.styleFrom(
            foregroundColor:
                _showLocations ? context.appTextSecondary : AppDS.accent,
            side: BorderSide(
              color: _showLocations
                  ? context.appBorder
                  : AppDS.accent.withValues(alpha: 0.5),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            minimumSize: const Size(0, 36),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
            textStyle: GoogleFonts.spaceGrotesk(fontSize: 13),
          ),
        ),
        const SizedBox(width: 8),
        if (context.canEditModule)
          OutlinedButton.icon(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LabBuilderPage()),
              );
              // Builder may have moved/resized rooms — refresh so the map
              // reflects the new layout.
              if (mounted) _load();
            },
            icon: const Icon(Icons.edit_outlined, size: 14),
            label: const Text('Open in Builder'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppDS.accent,
              side: BorderSide(color: AppDS.accent.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(0, 36),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              textStyle: GoogleFonts.spaceGrotesk(fontSize: 13),
            ),
          ),
      ]),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.map_outlined, size: 56, color: context.appTextMuted),
        const SizedBox(height: 12),
        Text('No rooms to display.',
            style: GoogleFonts.spaceGrotesk(
                color: context.appTextSecondary, fontSize: 15)),
        const SizedBox(height: 4),
        Text(
          'Add rooms in Rooms & Locations first — they will appear here.',
          style: GoogleFonts.spaceGrotesk(
              color: context.appTextMuted, fontSize: 12),
        ),
      ]),
    );
  }

  Widget _buildBody(BuildContext context) {
    return LayoutBuilder(builder: (ctx, constraints) {
      final w = constraints.maxWidth;
      final canvas = _buildCanvas(context);
      final panel = _buildPanel(context);
      // Below 700 px of *content* width, stack vertically — phones and
      // narrow split-screen.
      if (w < 700) {
        return Column(children: [
          Expanded(flex: 3, child: canvas),
          SizedBox(
            height: 280,
            child: Container(
              decoration: BoxDecoration(
                color: context.appSurface,
                border: Border(top: BorderSide(color: context.appBorder)),
              ),
              child: panel,
            ),
          ),
        ]);
      }
      // Map gets at least half the width; panel prefers 340 px but is
      // capped so the canvas never drops below 50 % of the row.
      final panelW = math.min(340.0, w * 0.5);
      return Row(children: [
        Expanded(child: canvas),
        SizedBox(
          width: panelW,
          child: Container(
            decoration: BoxDecoration(
              color: context.appSurface,
              border: Border(left: BorderSide(color: context.appBorder)),
            ),
            child: panel,
          ),
        ),
      ]);
    });
  }

  Widget _buildCanvas(BuildContext context) {
    final size = _canvasSize;
    return LayoutBuilder(
      builder: (ctx, constraints) {
        _scheduleAutoFit(Size(constraints.maxWidth, constraints.maxHeight));
        return Container(
          color: context.appBg,
          child: InteractiveViewer(
            transformationController: _viewerCtrl,
            minScale: _kMinViewerScale,
            maxScale: 4,
            boundaryMargin: const EdgeInsets.all(400),
            constrained: false,
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: Stack(children: [
                // Background grid
                Positioned.fill(
                  child: CustomPaint(painter: _GridPainter(context.appBorder)),
                ),
                for (final decor in _decors.where(_isBackgroundDecor))
                  _buildDecorShape(context, decor),
                for (final room in _rooms) _buildRoomShape(context, room),
                if (_showLocations)
                  for (final loc in _locations) _buildLocationShape(context, loc),
                for (final decor in _decors.where((d) => !_isBackgroundDecor(d)))
                  _buildDecorShape(context, decor),
              ]),
            ),
          ),
        );
      },
    );
  }

  bool _isBackgroundDecor(_Decor decor) => decor.kind == _DecorKind.corridor;

  Widget _buildLocationShape(BuildContext context, _CanvasLocationView loc) {
    final accent = LocationModel.typeAccent(loc.type);
    final icon = LocationModel.typeIcon(loc.type);
    final displayName =
        loc.name.trim().isEmpty ? LocationModel.typeLabel(loc.type) : loc.name;
    final location = _locById[loc.id];
    final dimmed =
        _search.isNotEmpty && !_searchRoomHits.contains(loc.parentRoomId);
    return Positioned(
      left: loc.geom.x,
      top: loc.geom.y,
      width: loc.geom.w,
      height: loc.geom.h,
      child: Opacity(
        opacity: dimmed ? 0.35 : 1,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => _selectedRoomId = loc.parentRoomId),
            onDoubleTap: location == null ? null : () => _openLocationDetail(location),
            child: Container(
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: accent.withValues(alpha: 0.75),
                  width: 1.2,
                ),
              ),
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(icon, size: 13, color: accent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        LocationModel.typeLabel(loc.type),
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.jetBrainsMono(
                          color: accent,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Text(
                      displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.spaceGrotesk(
                        color: context.appTextPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDecorShape(BuildContext context, _Decor decor) {
    final accent = switch (decor.kind) {
      _DecorKind.wall => const Color(0xFF64748B),
      _DecorKind.door => const Color(0xFFF97316),
      _DecorKind.corridor => const Color(0xFFB08968),
      _DecorKind.bathroom => const Color(0xFF38BDF8),
    };
    final fillAlpha = switch (decor.kind) {
      _DecorKind.wall => 0.7,
      _DecorKind.door => 0.78,
      _DecorKind.corridor => 0.16,
      _DecorKind.bathroom => 0.18,
    };
    final icon = switch (decor.kind) {
      _DecorKind.wall => null,
      _DecorKind.door => null,
      _DecorKind.corridor => null,
      _DecorKind.bathroom => Icons.wc,
    };

    return Positioned(
      left: decor.x,
      top: decor.y,
      width: decor.w,
      height: decor.h,
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            color: accent.withValues(alpha: fillAlpha),
            borderRadius: BorderRadius.circular(switch (decor.kind) {
              _DecorKind.wall => 2,
              _DecorKind.door => 999,
              _DecorKind.corridor => 14,
              _DecorKind.bathroom => 6,
            }),
            border: Border.all(
              color: accent.withValues(alpha: 0.7),
              width: decor.kind == _DecorKind.corridor ? 1.4 : 1.2,
            ),
          ),
          alignment: Alignment.center,
          child: icon == null
              ? (decor.kind == _DecorKind.corridor && decor.h > 34
                  ? Text(
                      decor.label ?? 'Corridor',
                      style: GoogleFonts.spaceGrotesk(
                        color: accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : null)
              : (decor.kind == _DecorKind.bathroom
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon,
                            size: math.min(28, decor.h * 0.4), color: accent),
                        if (decor.h > 60)
                          Text(
                            decor.label ?? 'Bathroom',
                            style: GoogleFonts.spaceGrotesk(
                              color: accent,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    )
                  : Icon(
                      icon,
                      size: math.min(decor.w, decor.h) * 0.6,
                      color: accent,
                    )),
        ),
      ),
    );
  }

  Widget _buildRoomShape(BuildContext context, LocationModel room) {
    final g = _geom[room.id];
    if (g == null) return const SizedBox.shrink();
    final selected = room.id == _selectedRoomId;
    final matched = _matchesSearch(room);
    final accent = LocationModel.typeAccent(LocationModel.roomType);
    final code = _roomCodeFor(room);
    final desc = stripLocationCodePrefix(room.name);
    final dimmed = _search.isNotEmpty && !matched;
    final reagentCount = _reagentsInRoom(room.id).length;

    return Positioned(
      left: g.x,
      top: g.y,
      width: g.w,
      height: g.h,
      child: Opacity(
        opacity: dimmed ? 0.35 : 1,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => _selectedRoomId = room.id),
            onDoubleTap: () => _openRoomDetail(room),
            child: Container(
              decoration: BoxDecoration(
                color: accent.withValues(alpha: selected ? 0.22 : 0.10),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected
                      ? accent
                      : accent.withValues(alpha: 0.6),
                  width: selected ? 2.5 : 1.4,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.35),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(
                      LocationModel.typeIcon(LocationModel.roomType),
                      size: 14,
                      color: accent,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      code,
                      style: GoogleFonts.jetBrainsMono(
                        color: accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Text(
                      desc.isEmpty ? '—' : desc,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.spaceGrotesk(
                        color: context.appTextPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Row(children: [
                    Icon(Icons.location_on_outlined,
                        size: 11, color: context.appTextMuted),
                    const SizedBox(width: 2),
                    Text(
                      '${(_childMap[room.id] ?? const []).length}',
                      style: GoogleFonts.jetBrainsMono(
                          color: context.appTextMuted, fontSize: 10),
                    ),
                    const SizedBox(width: 10),
                    Icon(Icons.science_outlined,
                        size: 11, color: context.appTextMuted),
                    const SizedBox(width: 2),
                    Text(
                      '$reagentCount',
                      style: GoogleFonts.jetBrainsMono(
                          color: context.appTextMuted, fontSize: 10),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPanel(BuildContext context) {
    final room = _selectedRoom;
    final reagentHits = _matchingReagents;
    if (room == null) {
      // No room selected — when search is active, show the reagent hits so
      // the user can pick one and jump to its room. Otherwise the empty
      // hint.
      if (_search.isNotEmpty && reagentHits.isNotEmpty) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _buildReagentHits(context, reagentHits),
          ],
        );
      }
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.touch_app_outlined,
                size: 36, color: context.appTextMuted),
            const SizedBox(height: 10),
            Text('Tap a room on the map',
                style: GoogleFonts.spaceGrotesk(
                    color: context.appTextSecondary, fontSize: 13)),
            const SizedBox(height: 2),
            Text('Double-tap to open its detail page.',
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceGrotesk(
                    color: context.appTextMuted, fontSize: 11)),
          ]),
        ),
      );
    }
    final code = _roomCodeFor(room);
    final desc = stripLocationCodePrefix(room.name);
    final kids = _childMap[room.id] ?? const [];
    final roomReagents = _reagentsInRoom(room.id);
    final accent = LocationModel.typeAccent(LocationModel.roomType);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(code,
                style: GoogleFonts.jetBrainsMono(
                    color: accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              desc.isEmpty ? '—' : desc,
              style: GoogleFonts.spaceGrotesk(
                  color: context.appTextPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            tooltip: 'Open room',
            icon: Icon(Icons.open_in_new,
                size: 16, color: context.appTextSecondary),
            onPressed: () => _openRoomDetail(room),
          ),
        ]),
        if (room.responsible != null && room.responsible!.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          DetailResponsibleChips(raw: room.responsible, users: _users),
        ],
        const SizedBox(height: 16),
        _buildRoomPanelSwitch(context),
        if (_roomPanelMode == _RoomPanelMode.reagents &&
            roomReagents.isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildReagentSortSwitch(context),
        ],
        const SizedBox(height: 14),
        Text(
            _roomPanelMode == _RoomPanelMode.locations
                ? 'SUB-LOCATIONS  (${kids.length})'
                : 'REAGENTS IN ROOM  (${roomReagents.length})',
            style: GoogleFonts.spaceGrotesk(
                color: context.appTextMuted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8)),
        const SizedBox(height: 6),
        if (_roomPanelMode == _RoomPanelMode.locations && kids.isEmpty)
          Text('No sub-locations in this room yet.',
              style: GoogleFonts.spaceGrotesk(
                  color: context.appTextMuted, fontSize: 12))
        else if (_roomPanelMode == _RoomPanelMode.reagents &&
            roomReagents.isEmpty)
          Text('No reagents are assigned to this room yet.',
              style: GoogleFonts.spaceGrotesk(
                  color: context.appTextMuted, fontSize: 12))
        else if (_roomPanelMode == _RoomPanelMode.locations)
          ..._buildGroupedChildren(context, room, kids)
        else
          ..._buildRoomReagentTiles(context, room, roomReagents),
      ],
    );
  }

  Widget _buildRoomPanelSwitch(BuildContext context) {
    return SegmentedButton<_RoomPanelMode>(
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        textStyle: WidgetStateProperty.all(
          GoogleFonts.spaceGrotesk(fontSize: 11, fontWeight: FontWeight.w600),
        ),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 10),
        ),
      ),
      segments: const [
        ButtonSegment<_RoomPanelMode>(
          value: _RoomPanelMode.locations,
          icon: Icon(Icons.location_on_outlined, size: 14),
          label: Text('Locations'),
        ),
        ButtonSegment<_RoomPanelMode>(
          value: _RoomPanelMode.reagents,
          icon: Icon(Icons.science_outlined, size: 14),
          label: Text('Reagents'),
        ),
      ],
      selected: {_roomPanelMode},
      onSelectionChanged: (selection) {
        setState(() => _roomPanelMode = selection.first);
      },
    );
  }

  Widget _buildReagentSortSwitch(BuildContext context) {
    Widget sortButton({
      required _ReagentSort value,
      required IconData icon,
      required String tooltip,
    }) {
      final selected = _reagentSort == value;
      return Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: () => setState(() => _reagentSort = value),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: selected
                  ? AppDS.accent.withValues(alpha: 0.18)
                  : context.appSurface2,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected ? AppDS.accent : context.appBorder,
                width: selected ? 1.4 : 1,
              ),
            ),
            child: Icon(
              icon,
              size: 16,
              color: selected ? AppDS.accent : context.appTextSecondary,
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        sortButton(
          value: _ReagentSort.code,
          icon: Icons.tag_outlined,
          tooltip: 'Sort by code',
        ),
        const SizedBox(width: 8),
        sortButton(
          value: _ReagentSort.name,
          icon: Icons.sort_by_alpha_outlined,
          tooltip: 'Sort by name',
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: _reagentSortDescending
              ? 'Descending order'
              : 'Ascending order',
          child: InkWell(
            onTap: () => setState(
              () => _reagentSortDescending = !_reagentSortDescending,
            ),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: context.appSurface2,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.appBorder),
              ),
              child: Icon(
                _reagentSortDescending
                    ? Icons.arrow_downward_rounded
                    : Icons.arrow_upward_rounded,
                size: 16,
                color: context.appTextSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildRoomReagentTiles(BuildContext context, LocationModel room,
      List<Map<String, dynamic>> reagents) {
    return [
      for (final r in reagents)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: context.appSurface2,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: context.appBorder),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.water_drop_outlined,
                    size: 13, color: AppDS.orange),
                const SizedBox(width: 8),
                SizedBox(
                  width: 60,
                  child: Text(
                    (r['reagent_code'] as String?) ?? '-',
                    style: GoogleFonts.jetBrainsMono(
                        color: context.appTextMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        (r['reagent_name'] as String?) ?? '-',
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.spaceGrotesk(
                            color: context.appTextPrimary, fontSize: 12),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _reagentLocationLabel(r, room.id),
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.spaceGrotesk(
                            color: context.appTextMuted, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
    ];
  }

  Widget _buildReagentHits(
      BuildContext context, List<Map<String, dynamic>> hits,
      {bool scoped = false}) {
    if (hits.isEmpty) {
      return scoped
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No reagents match "${_searchCtrl.text}".',
                style: GoogleFonts.spaceGrotesk(
                    color: context.appTextMuted, fontSize: 12),
              ),
            );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          scoped
              ? 'MATCHING REAGENTS HERE  (${hits.length})'
              : 'REAGENTS FOUND  (${hits.length})',
          style: GoogleFonts.spaceGrotesk(
              color: context.appTextMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8),
        ),
        const SizedBox(height: 6),
        for (final r in hits.take(20))
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () {
                  final locId = r['reagent_location_id'] != null
                      ? (r['reagent_location_id'] as num).toInt()
                      : null;
                  if (locId == null) return;
                  final roomId = _locToRoom[locId];
                  if (roomId != null) {
                    setState(() => _selectedRoomId = roomId);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: context.appSurface2,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: context.appBorder),
                  ),
                  child: Row(children: [
                    Icon(Icons.water_drop_outlined,
                        size: 13, color: AppDS.orange),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 60,
                      child: Text(
                        (r['reagent_code'] as String?) ?? '—',
                        style: GoogleFonts.jetBrainsMono(
                            color: context.appTextMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        (r['reagent_name'] as String?) ?? '—',
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.spaceGrotesk(
                            color: context.appTextPrimary, fontSize: 12),
                      ),
                    ),
                    if (!scoped) ...[
                      const SizedBox(width: 6),
                      _roomBadge(context, r),
                    ],
                  ]),
                ),
              ),
            ),
          ),
        if (hits.length > 20)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '+${hits.length - 20} more — refine your search to narrow down.',
              style: GoogleFonts.spaceGrotesk(
                  color: context.appTextMuted, fontSize: 11),
            ),
          ),
      ],
    );
  }

  Widget _roomBadge(BuildContext context, Map<String, dynamic> reagent) {
    final locId = reagent['reagent_location_id'] != null
        ? (reagent['reagent_location_id'] as num).toInt()
        : null;
    final roomId = locId == null ? null : _locToRoom[locId];
    if (roomId == null) {
      return Text('—',
          style: GoogleFonts.jetBrainsMono(
              color: context.appTextMuted, fontSize: 10));
    }
    final idx = _rooms.indexWhere((r) => r.id == roomId);
    if (idx < 0) return const SizedBox.shrink();
    final accent = LocationModel.typeAccent(LocationModel.roomType);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'R${idx + 1}',
        style: GoogleFonts.jetBrainsMono(
            color: accent, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }

  List<Widget> _buildGroupedChildren(
      BuildContext context, LocationModel room, List<LocationModel> kids) {
    final roomIdx = _rooms.indexWhere((r) => r.id == room.id);
    final byType = <String, List<LocationModel>>{};
    for (final c in kids) {
      byType.putIfAbsent(c.type, () => []).add(c);
    }
    final groups = <(String, List<String>)>[
      ...LocationModel.locationSubtypeGroups,
      ('Other', [for (final t in byType.keys)
        if (!LocationModel.locationSubtypeGroups
            .any((g) => g.$2.contains(t))) t]),
    ];

    final out = <Widget>[];
    for (final group in groups) {
      final inGroup = <LocationModel>[];
      for (final t in group.$2) {
        inGroup.addAll(byType[t] ?? const []);
      }
      if (inGroup.isEmpty) continue;
      out.add(Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 4),
        child: Text(group.$1.toUpperCase(),
            style: GoogleFonts.spaceGrotesk(
                color: context.appTextMuted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8)),
      ));
      for (final c in inGroup) {
        final idx = (_childMap[room.id] ?? const []).indexOf(c);
        final code = idx < 0 ? '' : 'L${roomIdx + 1}.${idx + 1}';
        out.add(_buildChildTile(context, c, code));
      }
    }
    return out;
  }

  Widget _buildChildTile(
      BuildContext context, LocationModel loc, String code) {
    final accent = LocationModel.typeAccent(loc.type);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => _openLocationDetail(loc),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: context.appSurface2,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: context.appBorder),
            ),
            child: Row(children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(LocationModel.typeIcon(loc.type),
                    color: accent, size: 13),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 52,
                child: Text(code,
                    style: GoogleFonts.jetBrainsMono(
                        color: context.appTextMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      stripLocationCodePrefix(loc.name).isEmpty
                          ? LocationModel.typeLabel(loc.type)
                          : stripLocationCodePrefix(loc.name),
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.spaceGrotesk(
                          color: context.appTextPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500),
                    ),
                    if (loc.temperature != null)
                      Text(loc.temperature!,
                          style: GoogleFonts.spaceGrotesk(
                              color: context.appTextMuted, fontSize: 10)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  size: 14, color: context.appTextMuted),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─── Geometry ────────────────────────────────────────────────────────────────
enum _RoomPanelMode { locations, reagents }

enum _ReagentSort { code, name }

enum _DecorKind { wall, door, corridor, bathroom }

class _Decor {
  final String id;
  final _DecorKind kind;
  final double x, y, w, h;
  final String? label;

  const _Decor({
    required this.id,
    required this.kind,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    this.label,
  });

  static _Decor? tryParse(dynamic raw) {
    if (raw is! Map) return null;
    final id = raw['id'] as String?;
    final kind = _DecorKindParser.parse(raw['kind'] as String?);
    final x = (raw['x'] as num?)?.toDouble();
    final y = (raw['y'] as num?)?.toDouble();
    final w = (raw['w'] as num?)?.toDouble();
    final h = (raw['h'] as num?)?.toDouble();
    if (id == null || kind == null || x == null || y == null || w == null ||
        h == null) {
      return null;
    }
    return _Decor(
      id: id,
      kind: kind,
      x: x,
      y: y,
      w: w,
      h: h,
      label: raw['label'] as String?,
    );
  }
}

class _DecorKindParser {
  static _DecorKind? parse(String? raw) => switch (raw) {
        'wall' => _DecorKind.wall,
        'door' => _DecorKind.door,
        'corridor' => _DecorKind.corridor,
        'bathroom' => _DecorKind.bathroom,
        _ => null,
      };
}

class _CanvasLocationView {
  final int id;
  final int parentRoomId;
  final String name;
  final String type;
  final _RoomGeom geom;

  const _CanvasLocationView({
    required this.id,
    required this.parentRoomId,
    required this.name,
    required this.type,
    required this.geom,
  });
}

class _RoomGeom {
  final double x, y, w, h;
  const _RoomGeom({required this.x, required this.y, required this.w, required this.h});

  static _RoomGeom? tryParse(dynamic raw) {
    if (raw == null) return null;
    try {
      final map = raw is String ? jsonDecode(raw) : raw;
      if (map is! Map) return null;
      final x = (map['x'] as num?)?.toDouble();
      final y = (map['y'] as num?)?.toDouble();
      final w = (map['w'] as num?)?.toDouble();
      final h = (map['h'] as num?)?.toDouble();
      if (x == null || y == null || w == null || h == null) return null;
      return _RoomGeom(x: x, y: y, w: w, h: h);
    } catch (_) {
      return null;
    }
  }
}

// ─── Background grid painter ────────────────────────────────────────────────
class _GridPainter extends CustomPainter {
  final Color color;
  const _GridPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    const step = 40.0;
    final paint = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..strokeWidth = 0.5;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) => old.color != color;
}
