// lab_builder_page.dart - Floor-plan editor.
// First cut: place existing rooms on a 2D canvas (drag to move, corner
// handle to resize, snap-to-grid optional). Save writes each modified
// room's geometry to `storage_locations.location_layout` (JSONB) — the
// same column LabPage reads to render the map.
//
// Pushed via Navigator from LabPage with its own Scaffold + AppBar.
// Admin-only: entry guarded by `context.canEditModule` at the call site,
// and we re-check here on save so a stale link can't bypass it.

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide LocalStorage;

import '/camera/qr_scanner/qr_code_rules.dart';
import '/supabase/supabase_manager.dart';
import '/theme/theme.dart';
import '/theme/module_permission.dart';
import '../locations/detail_widgets.dart';
import '../locations/location_detail_page.dart';
import '../locations/location_model.dart';

const double _kDefaultRoomW = 200;
const double _kDefaultRoomH = 130;
const double _kDefaultGap = 24;
const int _kDefaultCols = 4;
const double _kGridStep = 20;
const double _kHandleSize = 14;
const double _kMinRoomSize = 80;
const double _kMinDecorSize = 16;
const double _kMinLocationSize = 28;
const double _kMinCanvasW = 800;
const double _kMinCanvasH = 600;

enum _Tool { select, wall, door, corridor, bathroom }

enum _DecorKind { wall, door, corridor, bathroom }

extension on _DecorKind {
  String get id => switch (this) {
    _DecorKind.wall => 'wall',
    _DecorKind.door => 'door',
    _DecorKind.corridor => 'corridor',
    _DecorKind.bathroom => 'bathroom',
  };
}

enum _Size { small, medium, large }

extension on _Size {
  String get label => switch (this) {
    _Size.small => 'Small',
    _Size.medium => 'Medium',
    _Size.large => 'Large',
  };
}

// Default placement footprints per kind & size, in canvas units.
const Map<_DecorKind, Map<_Size, Size>> _kDefaultDecorSizes = {
  _DecorKind.wall: {
    _Size.small: Size(120, 12),
    _Size.medium: Size(220, 12),
    _Size.large: Size(360, 12),
  },
  _DecorKind.door: {
    _Size.small: Size(34, 8),
    _Size.medium: Size(54, 8),
    _Size.large: Size(84, 10),
  },
  _DecorKind.corridor: {
    _Size.small: Size(180, 70),
    _Size.medium: Size(320, 90),
    _Size.large: Size(520, 120),
  },
  _DecorKind.bathroom: {
    _Size.small: Size(100, 100),
    _Size.medium: Size(150, 120),
    _Size.large: Size(220, 160),
  },
};

class LabBuilderPage extends StatefulWidget {
  const LabBuilderPage({super.key});

  @override
  State<LabBuilderPage> createState() => _LabBuilderPageState();
}

class _LabBuilderPageState extends State<LabBuilderPage> {
  List<LocationModel> _rooms = [];
  List<_CanvasLocation> _locations = [];
  // Live edit state.
  Map<int, _RoomGeom> _geom = {};
  // Snapshot taken at load (or last successful save) — Cancel restores to this,
  // and Save only writes rows whose current geom differs from this snapshot.
  Map<int, _RoomGeom> _baseline = {};
  Map<String, _CanvasLocation> _locationBaseline = {};
  // Rooms that had a NULL location_layout on load (we filled them in with a
  // grid fallback). They count as "unpersisted" until Save writes the JSON,
  // otherwise they would silently revert to a random grid on the next load.
  Set<int> _unpersistedRoomIds = {};
  Set<int> _unpersistedLocationIds = {};
  // Non-storage decorations (walls, doors, bathrooms, …). Persisted as a
  // single JSON document under app_meta.meta_settings.lab_layout.
  List<_Decor> _decors = [];
  String _decorsBaselineJson = '[]';
  Map<String, dynamic> _appMetaSettings = {};
  Size _backgroundSize = const Size(_kMinCanvasW, _kMinCanvasH);
  Size _backgroundBaselineSize = const Size(_kMinCanvasW, _kMinCanvasH);
  int? _selectedRoomId;
  String? _selectedLocationId;
  String? _selectedDecorId;
  _Tool _tool = _Tool.select;
  _Size _placementSize = _Size.medium;
  bool _loading = true;
  bool _saving = false;
  bool _snap = true;
  int _decorSeq = 0;
  int _locationSeq = 0;
  // InteractiveViewer state — we bind it to a controller so we can read the
  // current scale and convert pointer deltas back into canvas coordinates.
  final _viewerCtrl = TransformationController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _viewerCtrl.dispose();
    super.dispose();
  }

  bool get _dirty {
    if (_unpersistedRoomIds.isNotEmpty) return true;
    if (_unpersistedLocationIds.isNotEmpty) return true;
    for (final id in _geom.keys) {
      final a = _geom[id], b = _baseline[id];
      if (b == null) return true;
      if (a! != b) return true;
    }
    for (final loc in _locations) {
      final base = _locationBaseline[loc.clientId];
      if (base == null || loc != base) return true;
    }
    if (_locationBaseline.keys.any(
      (id) => !_locations.any((loc) => loc.clientId == id),
    )) {
      return true;
    }
    if (_encodeDecors(_decors) != _decorsBaselineJson) return true;
    if (_backgroundSize != _backgroundBaselineSize) return true;
    return false;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        Supabase.instance.client
            .from('storage_locations')
            .select(
              'location_id, location_name, location_type, '
              'location_parent_id, location_sort_order, location_layout',
            )
            .order('location_sort_order'),
        Supabase.instance.client
            .from('app_meta')
            .select('meta_settings')
            .eq('meta_initialized', true)
            .limit(1)
            .maybeSingle(),
      ]);
      final locationRows = results[0] as List;
      final metaRowRaw = results[1];

      final locationMaps = locationRows
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
      final locationLayoutsById = <int, dynamic>{
        for (final row in locationMaps)
          if (row['location_id'] != null)
            (row['location_id'] as num).toInt(): row['location_layout'],
      };

      final allLocations = locationMaps
          .map<LocationModel>((r) => LocationModel.fromMap(r))
          .toList();
      final rooms = allLocations.where((l) => l.isRoom).toList()
        ..sort(_bySortThenName);
      final roomIds = {for (final room in rooms) room.id};

      final geom = <int, _RoomGeom>{};
      final unpersisted = <int>{};
      for (var i = 0; i < rooms.length; i++) {
        // Match saved geometry to the room id after sorting so we do not
        // accidentally assign another room's layout when the sort order differs
        // from the raw query order.
        final raw = locationLayoutsById[rooms[i].id];
        final parsed = _RoomGeom.tryParse(raw);
        if (parsed == null) unpersisted.add(rooms[i].id);
        geom[rooms[i].id] = parsed ?? _gridFallback(i);
      }

      final roomChildCounts = <int, int>{};
      final locationItems = <_CanvasLocation>[];
      final unpersistedLocations = <int>{};
      final directChildren =
          allLocations
              .where(
                (loc) =>
                    !loc.isRoom &&
                    loc.parentId != null &&
                    roomIds.contains(loc.parentId),
              )
              .toList()
            ..sort((a, b) {
              if (a.parentId != b.parentId) {
                return (a.parentId ?? 0).compareTo(b.parentId ?? 0);
              }
              return _bySortThenName(a, b);
            });
      for (final loc in directChildren) {
        final roomGeom = geom[loc.parentId!];
        if (roomGeom == null) continue;
        final slot = roomChildCounts.update(
          loc.parentId!,
          (v) => v + 1,
          ifAbsent: () => 0,
        );
        final raw = locationLayoutsById[loc.id];
        final parsed = _RoomGeom.tryParse(raw);
        if (parsed == null) unpersistedLocations.add(loc.id);
        locationItems.add(
          _CanvasLocation(
            clientId: 'loc_${loc.id}',
            dbId: loc.id,
            parentRoomId: loc.parentId!,
            name: stripLocationCodePrefix(loc.name),
            type: loc.type,
            sortOrder: loc.sortOrder,
            geom: _clampLocationGeom(
              roomGeom,
              parsed ?? _locationFallback(roomGeom, slot, loc.type),
            ),
          ),
        );
      }

      // Decorations live on the singleton app_meta row.
      Map<String, dynamic> settings = {};
      Size? savedCanvasSize;
      final decors = <_Decor>[];
      if (metaRowRaw is Map) {
        final m = Map<String, dynamic>.from(metaRowRaw);
        final raw = m['meta_settings'];
        if (raw is Map) {
          settings = Map<String, dynamic>.from(raw);
        } else if (raw is String) {
          try {
            final parsed = jsonDecode(raw);
            if (parsed is Map) settings = Map<String, dynamic>.from(parsed);
          } catch (_) {
            /* keep empty */
          }
        }
        final layout = settings['lab_layout'];
        if (layout is Map) {
          savedCanvasSize = _parseCanvasSize(layout['canvas_size']);
          final list = layout['decorations'];
          if (list is List) {
            for (final item in list) {
              final d = _Decor.tryParse(item);
              if (d != null) decors.add(d);
            }
          }
        }
      }

      if (!mounted) return;
      final resolvedCanvasSize = _normalizeCanvasSize(
        savedCanvasSize ??
            _minimumCanvasSizeFor(
              geom: geom,
              locations: locationItems,
              decors: decors,
            ),
        geom: geom,
        locations: locationItems,
        decors: decors,
      );
      setState(() {
        _rooms = rooms;
        _locations = _sortCanvasLocations(locationItems);
        _geom = geom;
        _baseline = {for (final e in geom.entries) e.key: e.value};
        _locationBaseline = {
          for (final loc in locationItems) loc.clientId: loc,
        };
        _unpersistedRoomIds = unpersisted;
        _unpersistedLocationIds = unpersistedLocations;
        _decors = decors;
        _decorsBaselineJson = _encodeDecors(decors);
        _appMetaSettings = settings;
        _backgroundSize = resolvedCanvasSize;
        _backgroundBaselineSize = resolvedCanvasSize;
        _loading = false;
      });
    } catch (e) {
      debugPrint('lab_builder: load failed: $e');
      if (!mounted) return;
      setState(() => _loading = false);
      _snack('Failed to load rooms: $e', error: true);
    }
  }

  String _encodeDecors(List<_Decor> list) =>
      jsonEncode(list.map((d) => d.toJson()).toList());

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

  Map<String, dynamic> _encodeCanvasSize(Size size) => {
    'width': size.width,
    'height': size.height,
  };

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

  double _snapValue(double v) =>
      _snap ? (v / _kGridStep).round() * _kGridStep : v;

  /// Pointer deltas come in screen pixels. With InteractiveViewer pinch-zoom
  /// active, those need to be divided by the current scale to land at the
  /// right canvas coordinates.
  double get _scale {
    return _viewerCtrl.value.getMaxScaleOnAxis().clamp(0.0001, 1000.0);
  }

  _CanvasLocation? _locationById(String id) {
    for (final loc in _locations) {
      if (loc.clientId == id) return loc;
    }
    return null;
  }

  List<_CanvasLocation> _locationsForRoom(int roomId) {
    return _locations.where((loc) => loc.parentRoomId == roomId).toList()
      ..sort((a, b) {
        final ao = a.sortOrder, bo = b.sortOrder;
        if (ao != null && bo != null) {
          final bySort = ao.compareTo(bo);
          if (bySort != 0) return bySort;
        }
        return a.name.compareTo(b.name);
      });
  }

  List<_CanvasLocation> _sortCanvasLocations(List<_CanvasLocation> list) {
    final out = [...list];
    out.sort((a, b) {
      if (a.parentRoomId != b.parentRoomId) {
        return a.parentRoomId.compareTo(b.parentRoomId);
      }
      final ao = a.sortOrder, bo = b.sortOrder;
      if (ao != null && bo != null) {
        final bySort = ao.compareTo(bo);
        if (bySort != 0) return bySort;
      }
      return a.name.compareTo(b.name);
    });
    return out;
  }

  Size _defaultLocationSize(String type) => switch (type) {
    'bench' => const Size(120, 44),
    'cabinet' => const Size(80, 52),
    'drawer' => const Size(68, 40),
    'rack' => const Size(56, 82),
    'shelf' => const Size(92, 34),
    'cold_room' => const Size(96, 72),
    'cryotank' => const Size(58, 58),
    'freezer' => const Size(72, 68),
    'fridge' => const Size(68, 68),
    'box' => const Size(44, 44),
    _ => const Size(76, 44),
  };

  _RoomGeom _locationFallback(_RoomGeom roomGeom, int slot, String type) {
    final size = _defaultLocationSize(type);
    const gap = 12.0;
    const pad = 16.0;
    final cols = math.max(
      1,
      ((roomGeom.w - pad * 2) / (size.width + gap)).floor(),
    );
    final col = slot % cols;
    final row = slot ~/ cols;
    return _RoomGeom(
      x: roomGeom.x + pad + col * (size.width + gap),
      y: roomGeom.y + pad + row * (size.height + gap),
      w: size.width,
      h: size.height,
    );
  }

  _RoomGeom _clampLocationGeom(_RoomGeom roomGeom, _RoomGeom geom) {
    const pad = 6.0;
    final maxW = math.max(_kMinLocationSize, roomGeom.w - pad * 2);
    final maxH = math.max(_kMinLocationSize, roomGeom.h - pad * 2);
    final w = geom.w.clamp(_kMinLocationSize, maxW).toDouble();
    final h = geom.h.clamp(_kMinLocationSize, maxH).toDouble();
    final maxX = math.max(roomGeom.x + pad, roomGeom.x + roomGeom.w - pad - w);
    final maxY = math.max(roomGeom.y + pad, roomGeom.y + roomGeom.h - pad - h);
    final x = geom.x.clamp(roomGeom.x + pad, maxX).toDouble();
    final y = geom.y.clamp(roomGeom.y + pad, maxY).toDouble();
    return _RoomGeom(x: x, y: y, w: w, h: h);
  }

  Size _minimumCanvasSizeFor({
    Map<int, _RoomGeom>? geom,
    List<_CanvasLocation>? locations,
    List<_Decor>? decors,
  }) {
    final roomGeoms = (geom ?? _geom).values.toList();
    final locationItems = locations ?? _locations;
    final decorItems = decors ?? _decors;
    if (roomGeoms.isEmpty && locationItems.isEmpty && decorItems.isEmpty) {
      return const Size(_kMinCanvasW, _kMinCanvasH);
    }
    double maxX = 0;
    double maxY = 0;
    for (final g in roomGeoms) {
      maxX = math.max(maxX, g.x + g.w);
      maxY = math.max(maxY, g.y + g.h);
    }
    for (final loc in locationItems) {
      maxX = math.max(maxX, loc.geom.x + loc.geom.w);
      maxY = math.max(maxY, loc.geom.y + loc.geom.h);
    }
    for (final decor in decorItems) {
      maxX = math.max(maxX, decor.x + decor.w);
      maxY = math.max(maxY, decor.y + decor.h);
    }
    return Size(
      math.max(_kMinCanvasW, maxX + _kDefaultGap),
      math.max(_kMinCanvasH, maxY + _kDefaultGap),
    );
  }

  Size _normalizeCanvasSize(
    Size size, {
    Map<int, _RoomGeom>? geom,
    List<_CanvasLocation>? locations,
    List<_Decor>? decors,
  }) {
    final minSize = _minimumCanvasSizeFor(
      geom: geom,
      locations: locations,
      decors: decors,
    );
    return Size(
      math.max(size.width, minSize.width),
      math.max(size.height, minSize.height),
    );
  }

  _RoomGeom _clampFreeGeomToCanvas(
    _RoomGeom geom, {
    required double minW,
    required double minH,
  }) {
    final canvas = _canvasSize;
    final w = geom.w.clamp(minW, canvas.width).toDouble();
    final h = geom.h.clamp(minH, canvas.height).toDouble();
    final maxX = math.max(0.0, canvas.width - w);
    final maxY = math.max(0.0, canvas.height - h);
    return _RoomGeom(
      x: geom.x.clamp(0.0, maxX).toDouble(),
      y: geom.y.clamp(0.0, maxY).toDouble(),
      w: w,
      h: h,
    );
  }

  void _replaceLocation(_CanvasLocation next) {
    final i = _locations.indexWhere((loc) => loc.clientId == next.clientId);
    if (i < 0) return;
    _locations = _sortCanvasLocations([..._locations]..[i] = next);
  }

  void _moveRoom(int id, Offset delta) {
    final g = _geom[id];
    if (g == null) return;
    final s = _scale;
    final next = _clampFreeGeomToCanvas(
      _RoomGeom(x: g.x + delta.dx / s, y: g.y + delta.dy / s, w: g.w, h: g.h),
      minW: _kMinRoomSize,
      minH: _kMinRoomSize,
    );
    setState(() => _geom[id] = next);
  }

  void _resizeRoom(int id, Offset delta) {
    final g = _geom[id];
    if (g == null) return;
    final s = _scale;
    final next = _clampFreeGeomToCanvas(
      _RoomGeom(x: g.x, y: g.y, w: g.w + delta.dx / s, h: g.h + delta.dy / s),
      minW: _kMinRoomSize,
      minH: _kMinRoomSize,
    );
    setState(() => _geom[id] = next);
  }

  void _moveLocation(String id, Offset delta) {
    final loc = _locationById(id);
    if (loc == null) return;
    final roomGeom = _geom[loc.parentRoomId];
    if (roomGeom == null) return;
    final s = _scale;
    final next = _clampLocationGeom(
      roomGeom,
      _RoomGeom(
        x: loc.geom.x + delta.dx / s,
        y: loc.geom.y + delta.dy / s,
        w: loc.geom.w,
        h: loc.geom.h,
      ),
    );
    setState(() => _replaceLocation(loc.copyWith(geom: next)));
  }

  void _resizeLocation(String id, Offset delta) {
    final loc = _locationById(id);
    if (loc == null) return;
    final roomGeom = _geom[loc.parentRoomId];
    if (roomGeom == null) return;
    final s = _scale;
    final next = _clampLocationGeom(
      roomGeom,
      _RoomGeom(
        x: loc.geom.x,
        y: loc.geom.y,
        w: loc.geom.w + delta.dx / s,
        h: loc.geom.h + delta.dy / s,
      ),
    );
    setState(() => _replaceLocation(loc.copyWith(geom: next)));
  }

  void _snapSelected() {
    final roomId = _selectedRoomId;
    if (roomId != null) {
      final g = _geom[roomId];
      if (g != null) {
        setState(() {
          _geom[roomId] = _clampFreeGeomToCanvas(
            _RoomGeom(
              x: _snapValue(g.x),
              y: _snapValue(g.y),
              w: math.max(_kMinRoomSize, _snapValue(g.w)),
              h: math.max(_kMinRoomSize, _snapValue(g.h)),
            ),
            minW: _kMinRoomSize,
            minH: _kMinRoomSize,
          );
        });
      }
      return;
    }
    final locationId = _selectedLocationId;
    if (locationId != null) {
      final loc = _locationById(locationId);
      if (loc == null) return;
      final roomGeom = _geom[loc.parentRoomId];
      if (roomGeom == null) return;
      setState(() {
        _replaceLocation(
          loc.copyWith(
            geom: _clampLocationGeom(
              roomGeom,
              _RoomGeom(
                x: _snapValue(loc.geom.x),
                y: _snapValue(loc.geom.y),
                w: math.max(_kMinLocationSize, _snapValue(loc.geom.w)),
                h: math.max(_kMinLocationSize, _snapValue(loc.geom.h)),
              ),
            ),
          ),
        );
      });
      return;
    }
    final decorId = _selectedDecorId;
    if (decorId != null) {
      final d = _decorById(decorId);
      if (d == null) return;
      setState(() {
        final next = _clampFreeGeomToCanvas(
          _RoomGeom(
            x: _snapValue(d.x),
            y: _snapValue(d.y),
            w: math.max(_kMinDecorSize, _snapValue(d.w)),
            h: math.max(_kMinDecorSize, _snapValue(d.h)),
          ),
          minW: _kMinDecorSize,
          minH: _kMinDecorSize,
        );
        _replaceDecor(d.copyWith(x: next.x, y: next.y, w: next.w, h: next.h));
      });
    }
  }

  // ── Decoration helpers ────────────────────────────────────────────────────

  _Decor? _decorById(String id) {
    for (final d in _decors) {
      if (d.id == id) return d;
    }
    return null;
  }

  void _replaceDecor(_Decor next) {
    final i = _decors.indexWhere((d) => d.id == next.id);
    if (i < 0) return;
    _decors = [..._decors]..[i] = next;
  }

  /// Place a new decoration at the given canvas coordinates using the
  /// currently active tool + size. Selects the placed item.
  void _placeDecor(_DecorKind kind, Offset at) {
    final size = _kDefaultDecorSizes[kind]![_placementSize]!;
    final id = 'd_${DateTime.now().microsecondsSinceEpoch}_${_decorSeq++}';
    // Center the new shape on the click point.
    final x = _snap
        ? _snapValue(at.dx - size.width / 2)
        : at.dx - size.width / 2;
    final y = _snap
        ? _snapValue(at.dy - size.height / 2)
        : at.dy - size.height / 2;
    final geom = _clampFreeGeomToCanvas(
      _RoomGeom(
        x: math.max(0, x),
        y: math.max(0, y),
        w: size.width,
        h: size.height,
      ),
      minW: _kMinDecorSize,
      minH: _kMinDecorSize,
    );
    setState(() {
      _decors = [
        ..._decors,
        _Decor(
          id: id,
          kind: kind,
          x: geom.x,
          y: geom.y,
          w: geom.w,
          h: geom.h,
          label: switch (kind) {
            _DecorKind.bathroom => 'Bathroom',
            _DecorKind.corridor => 'Corridor',
            _ => null,
          },
        ),
      ];
      _selectedDecorId = id;
      _selectedLocationId = null;
      _selectedRoomId = null;
    });
  }

  void _moveDecor(String id, Offset delta) {
    final d = _decorById(id);
    if (d == null) return;
    final s = _scale;
    setState(() {
      final next = _clampFreeGeomToCanvas(
        _RoomGeom(x: d.x + delta.dx / s, y: d.y + delta.dy / s, w: d.w, h: d.h),
        minW: _kMinDecorSize,
        minH: _kMinDecorSize,
      );
      _replaceDecor(d.copyWith(x: next.x, y: next.y, w: next.w, h: next.h));
    });
  }

  void _resizeDecor(String id, Offset delta) {
    final d = _decorById(id);
    if (d == null) return;
    final s = _scale;
    setState(() {
      final next = _clampFreeGeomToCanvas(
        _RoomGeom(x: d.x, y: d.y, w: d.w + delta.dx / s, h: d.h + delta.dy / s),
        minW: _kMinDecorSize,
        minH: _kMinDecorSize,
      );
      _replaceDecor(d.copyWith(x: next.x, y: next.y, w: next.w, h: next.h));
    });
  }

  void _deleteSelectedDecor() {
    final id = _selectedDecorId;
    if (id == null) return;
    setState(() {
      _decors = _decors.where((d) => d.id != id).toList();
      _selectedDecorId = null;
    });
  }

  void _selectRoom(int? id) {
    setState(() {
      _selectedRoomId = id;
      _selectedLocationId = null;
      _selectedDecorId = null;
    });
  }

  void _selectLocation(String? id) {
    setState(() {
      _selectedLocationId = id;
      _selectedRoomId = null;
      _selectedDecorId = null;
    });
  }

  void _selectDecor(String? id) {
    setState(() {
      _selectedDecorId = id;
      _selectedLocationId = null;
      _selectedRoomId = null;
    });
  }

  Future<void> _addLocationToRoom(int roomId) async {
    if (!context.requireModuleAction(ModuleAction.create)) return;
    final room = _rooms.firstWhere((r) => r.id == roomId);
    final result = await showDialog<_NewCanvasLocation>(
      context: context,
      builder: (ctx) => _AddCanvasLocationDialog(room: room),
    );
    if (result == null || !mounted) return;
    final roomGeom = _geom[roomId];
    if (roomGeom == null) return;
    final slot = _locationsForRoom(roomId).length;
    final geom = _clampLocationGeom(
      roomGeom,
      _locationFallback(roomGeom, slot, result.type),
    );
    final clientId =
        'tmp_${DateTime.now().microsecondsSinceEpoch}_${_locationSeq++}';
    final sortOrder =
        (_locationsForRoom(roomId)
            .map((loc) => loc.sortOrder ?? 0)
            .fold<int>(0, math.max)) +
        1;
    final next = _CanvasLocation(
      clientId: clientId,
      dbId: null,
      parentRoomId: roomId,
      name: result.name,
      type: result.type,
      sortOrder: sortOrder,
      geom: geom,
    );
    setState(() {
      _locations = _sortCanvasLocations([..._locations, next]);
      _selectedLocationId = clientId;
      _selectedRoomId = null;
      _selectedDecorId = null;
    });
  }

  Future<void> _openLocationDetailFromBuilder(_CanvasLocation loc) async {
    final id = loc.dbId;
    if (id == null) {
      _snack('Save this location first to open its detail page.', error: true);
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LocationDetailPage(locationId: id)),
    );
    if (!mounted) return;
    await _refreshLocationFromDb(id);
  }

  Future<void> _refreshLocationFromDb(int locationId) async {
    try {
      final rows = await Supabase.instance.client
          .from('storage_locations')
          .select(
            'location_id, location_name, location_type, '
            'location_parent_id, location_sort_order, location_layout',
          )
          .eq('location_id', locationId)
          .limit(1);
      if (!mounted) return;
      if (rows.isEmpty) {
        setState(() {
          _locations = _locations.where((l) => l.dbId != locationId).toList();
          _locationBaseline.removeWhere((_, l) => l.dbId == locationId);
          _unpersistedLocationIds.remove(locationId);
          if (_selectedLocationId != null) {
            final selected = _locationById(_selectedLocationId!);
            if (selected == null) _selectedLocationId = null;
          }
        });
        return;
      }

      final row = Map<String, dynamic>.from(rows.first as Map);
      final model = LocationModel.fromMap(row);
      final matchingCurrent = _locations
          .where((l) => l.dbId == locationId)
          .toList();
      if (matchingCurrent.isEmpty) return;
      final current = matchingCurrent.first;
      final roomGeom = _geom[model.parentId ?? current.parentRoomId];
      if (roomGeom == null) return;
      final dbGeom = _RoomGeom.tryParse(row['location_layout']) ?? current.geom;
      final nextGeom = _clampLocationGeom(roomGeom, dbGeom);
      final next = current.copyWith(
        parentRoomId: model.parentId ?? current.parentRoomId,
        name: stripLocationCodePrefix(model.name),
        type: model.type,
        sortOrder: model.sortOrder,
        geom: nextGeom,
      );
      setState(() {
        _replaceLocation(next);
        _locationBaseline[current.clientId] = next;
        _unpersistedLocationIds.remove(locationId);
      });
    } catch (e) {
      debugPrint('lab_builder: refresh location $locationId failed: $e');
      if (mounted) {
        _snack('Failed to refresh location: $e', error: true);
      }
    }
  }

  Size get _canvasSize {
    return _normalizeCanvasSize(_backgroundSize);
  }

  Future<void> _save() async {
    if (!context.requireModuleAction(ModuleAction.edit)) return;
    if (!context.requireModuleAction(ModuleAction.bulkUpdate)) return;
    setState(() => _saving = true);
    final client = Supabase.instance.client;
    // Save (a) rows the user actually moved/resized AND (b) rows that never
    // had a stored layout — those are sitting on the default grid and would
    // otherwise revert to a fresh random grid on the next load.
    final dirty = <int>{..._unpersistedRoomIds};
    for (final id in _geom.keys) {
      if (_geom[id] != _baseline[id]) dirty.add(id);
    }
    final dirtyLocationClientIds = <String>{};
    final newLocationClientIds = <String>{};
    for (final loc in _locations) {
      if (loc.dbId == null) {
        newLocationClientIds.add(loc.clientId);
        continue;
      }
      final base = _locationBaseline[loc.clientId];
      if (base == null ||
          loc != base ||
          _unpersistedLocationIds.contains(loc.dbId)) {
        dirtyLocationClientIds.add(loc.clientId);
      }
    }
    final failures = <String>[];
    int ok = 0;
    for (final id in dirty) {
      final g = _geom[id]!;
      try {
        await client
            .from('storage_locations')
            .update({'location_layout': g.toJson()})
            .eq('location_id', id);
        ok++;
      } catch (e) {
        debugPrint('lab_builder: save row $id failed: $e');
        final room = _rooms.firstWhere(
          (r) => r.id == id,
          orElse: () => LocationModel.fromMap({
            'location_id': id,
            'location_name': '?',
            'location_type': 'room',
          }),
        );
        failures.add('${room.name}: $e');
      }
    }

    int savedLocations = 0;
    final savedLocationClientIds = <String>{};
    final insertedLocationClientIds = <String>{};
    final failedUnpersistedLocationIds = <int>{};
    final insertedDbIds = <String, int>{};
    final assignedSortOrders = <String, int>{};
    final nextSortByRoom = <int, int>{};
    for (final loc in _locations) {
      if (loc.sortOrder != null) {
        nextSortByRoom[loc.parentRoomId] = math.max(
          nextSortByRoom[loc.parentRoomId] ?? 0,
          loc.sortOrder!,
        );
      }
    }
    for (final clientId in dirtyLocationClientIds) {
      final loc = _locationById(clientId);
      if (loc == null || loc.dbId == null) continue;
      try {
        await client
            .from('storage_locations')
            .update({
              'location_name': loc.name.trim(),
              'location_type': loc.type,
              'location_layout': loc.geom.toJson(),
            })
            .eq('location_id', loc.dbId!);
        savedLocations++;
        savedLocationClientIds.add(clientId);
      } catch (e) {
        debugPrint('lab_builder: save location ${loc.dbId} failed: $e');
        failures.add('${LocationModel.typeLabel(loc.type)} ${loc.name}: $e');
        if (_unpersistedLocationIds.contains(loc.dbId)) {
          failedUnpersistedLocationIds.add(loc.dbId!);
        }
      }
    }
    for (final clientId in newLocationClientIds) {
      final loc = _locationById(clientId);
      if (loc == null) continue;
      final nextSort = (nextSortByRoom[loc.parentRoomId] ?? 0) + 1;
      nextSortByRoom[loc.parentRoomId] = nextSort;
      try {
        final row = await client
            .from('storage_locations')
            .insert({
              'location_name': loc.name.trim(),
              'location_type': loc.type,
              'location_parent_id': loc.parentRoomId,
              'location_sort_order': nextSort,
              'location_layout': loc.geom.toJson(),
            })
            .select('location_id')
            .single();
        final newId = (row['location_id'] as num).toInt();
        await client
            .from('storage_locations')
            .update({
              'location_qrcode': QrRules.build(
                SupabaseManager.projectRef ?? 'local',
                'locations',
                newId,
              ),
            })
            .eq('location_id', newId);
        savedLocations++;
        insertedLocationClientIds.add(clientId);
        insertedDbIds[clientId] = newId;
        assignedSortOrders[clientId] = nextSort;
      } catch (e) {
        debugPrint('lab_builder: insert location $clientId failed: $e');
        failures.add('${LocationModel.typeLabel(loc.type)} ${loc.name}: $e');
      }
    }

    // Persist decorations as a single JSON document on app_meta.
    final decorsChanged = _encodeDecors(_decors) != _decorsBaselineJson;
    final canvasChanged = _backgroundSize != _backgroundBaselineSize;
    var layoutSaved = false;
    if (decorsChanged || canvasChanged) {
      try {
        final newSettings = Map<String, dynamic>.from(_appMetaSettings);
        final priorLayout = newSettings['lab_layout'];
        final nextLayout = priorLayout is Map
            ? Map<String, dynamic>.from(priorLayout)
            : <String, dynamic>{};
        nextLayout['decorations'] = _decors.map((d) => d.toJson()).toList();
        nextLayout['canvas_size'] = _encodeCanvasSize(_backgroundSize);
        nextLayout['updated_at'] = DateTime.now().toUtc().toIso8601String();
        newSettings['lab_layout'] = nextLayout;
        final updated = await client
            .from('app_meta')
            .update({'meta_settings': newSettings})
            .eq('meta_initialized', true)
            .select('meta_initialized');
        if ((updated as List).isEmpty) {
          await client.from('app_meta').insert({
            'meta_initialized': true,
            'meta_version': '1.0',
            'meta_settings': newSettings,
          });
        }
        _appMetaSettings = newSettings;
        layoutSaved = true;
      } catch (e) {
        debugPrint('lab_builder: save decorations failed: $e');
        failures.add('Walls/doors/bathrooms: $e');
      }
    }

    if (!mounted) return;
    setState(() {
      _saving = false;
      _locations = _sortCanvasLocations(
        _locations.map((loc) {
          final insertedId = insertedDbIds[loc.clientId];
          if (insertedId == null) return loc;
          return loc.copyWith(
            dbId: insertedId,
            sortOrder: assignedSortOrders[loc.clientId],
          );
        }).toList(),
      );
      _baseline = {for (final e in _geom.entries) e.key: e.value};
      for (final clientId in savedLocationClientIds) {
        final loc = _locationById(clientId);
        if (loc != null) _locationBaseline[clientId] = loc;
      }
      for (final clientId in insertedLocationClientIds) {
        final loc = _locationById(clientId);
        if (loc != null) _locationBaseline[clientId] = loc;
      }
      if (layoutSaved) {
        _decorsBaselineJson = _encodeDecors(_decors);
        _backgroundBaselineSize = _backgroundSize;
      }
      // Rows we successfully wrote are now persisted; failed ones stay
      // marked so the next Save retries them.
      _unpersistedRoomIds = _unpersistedRoomIds
          .where(
            (id) => failures.any(
              (f) => f.contains(
                _rooms
                    .firstWhere(
                      (r) => r.id == id,
                      orElse: () => LocationModel.fromMap({
                        'location_id': id,
                        'location_name': '?',
                        'location_type': 'room',
                      }),
                    )
                    .name,
              ),
            ),
          )
          .toSet();
      _unpersistedLocationIds = _unpersistedLocationIds
          .where(failedUnpersistedLocationIds.contains)
          .toSet();
    });
    if (failures.isEmpty) {
      final parts = <String>[];
      if (ok > 0) parts.add('$ok room${ok == 1 ? '' : 's'}');
      if (savedLocations > 0) {
        parts.add('$savedLocations location${savedLocations == 1 ? '' : 's'}');
      }
      if (decorsChanged || canvasChanged) parts.add('layout');
      _snack(parts.isEmpty ? 'Saved.' : 'Saved ${parts.join(' + ')}.');
    } else {
      _snack(
        'Saved with ${failures.length} error(s):\n${failures.take(3).join('\n')}',
        error: true,
      );
    }
  }

  void _resetToBaseline() {
    setState(() {
      _geom = {for (final e in _baseline.entries) e.key: e.value};
      _locations = _sortCanvasLocations(_locationBaseline.values.toList());
      // Reload decorations from the encoded baseline.
      final list = jsonDecode(_decorsBaselineJson);
      _decors = (list as List)
          .map((e) => _Decor.tryParse(e))
          .whereType<_Decor>()
          .toList();
      _backgroundSize = _backgroundBaselineSize;
      _selectedLocationId = null;
      _selectedDecorId = null;
    });
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.appSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Discard changes?',
          style: GoogleFonts.spaceGrotesk(
            color: ctx.appTextPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'You have unsaved changes to the lab layout. Discard them?',
          style: GoogleFonts.spaceGrotesk(
            color: ctx.appTextSecondary,
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Keep editing',
              style: GoogleFonts.spaceGrotesk(color: ctx.appTextSecondary),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppDS.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Discard', style: GoogleFonts.spaceGrotesk()),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: GoogleFonts.spaceGrotesk(color: Colors.white),
        ),
        backgroundColor: error ? AppDS.red : AppDS.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmDiscard() && mounted) {
          navigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: context.appBg,
        appBar: AppBar(
          backgroundColor: context.appSurface2,
          foregroundColor: context.appTextPrimary,
          elevation: 0,
          title: Text(
            'Lab Builder',
            style: GoogleFonts.spaceGrotesk(
              color: context.appTextPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            _buildToolPalette(context),
            const SizedBox(width: 6),
            _buildSizeMenu(context),
            const SizedBox(width: 6),
            // Snap-to-grid toggle.
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: TextButton.icon(
                onPressed: () => setState(() => _snap = !_snap),
                icon: Icon(
                  _snap ? Icons.grid_on : Icons.grid_off,
                  size: 16,
                  color: _snap ? AppDS.accent : context.appTextSecondary,
                ),
                label: Text(
                  _snap ? 'Snap on' : 'Snap off',
                  style: GoogleFonts.spaceGrotesk(
                    color: _snap ? AppDS.accent : context.appTextSecondary,
                  ),
                ),
              ),
            ),
            if (_dirty && !_saving)
              IconButton(
                tooltip: 'Discard changes',
                icon: Icon(
                  Icons.undo,
                  size: 18,
                  color: context.appTextSecondary,
                ),
                onPressed: _resetToBaseline,
              ),
            _saving
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppDS.accent,
                      ),
                    ),
                  )
                : TextButton.icon(
                    onPressed: _dirty ? _save : null,
                    icon: const Icon(
                      Icons.save_outlined,
                      size: 16,
                      color: AppDS.accent,
                    ),
                    label: Text(
                      _dirty ? 'Save' : 'Saved',
                      style: GoogleFonts.spaceGrotesk(
                        color: _dirty ? AppDS.accent : context.appTextMuted,
                      ),
                    ),
                  ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _rooms.isEmpty
            ? _buildEmptyState(context)
            : _buildBody(context),
      ),
    );
  }

  // ── Toolbar widgets ────────────────────────────────────────────────────────

  Widget _buildToolPalette(BuildContext context) {
    Widget btn({
      required _Tool tool,
      required IconData icon,
      required String tooltip,
    }) {
      final selected = _tool == tool;
      return Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: () {
            setState(() => _tool = tool);
            if (tool == _Tool.select) _selectedDecorId = _selectedDecorId;
          },
          borderRadius: BorderRadius.circular(6),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 1),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: selected
                  ? AppDS.accent.withValues(alpha: 0.18)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
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
      mainAxisSize: MainAxisSize.min,
      children: [
        btn(
          tool: _Tool.select,
          icon: Icons.pan_tool_alt_outlined,
          tooltip: 'Select / move',
        ),
        btn(tool: _Tool.wall, icon: Icons.horizontal_rule, tooltip: 'Add wall'),
        btn(tool: _Tool.door, icon: Icons.remove, tooltip: 'Add door'),
        btn(
          tool: _Tool.corridor,
          icon: Icons.space_dashboard_outlined,
          tooltip: 'Add corridor',
        ),
        btn(tool: _Tool.bathroom, icon: Icons.wc, tooltip: 'Add bathroom'),
      ],
    );
  }

  Widget _buildSizeMenu(BuildContext context) {
    return PopupMenuButton<_Size>(
      tooltip: 'Default size for new shapes',
      initialValue: _placementSize,
      onSelected: (s) => setState(() => _placementSize = s),
      color: context.appSurface,
      itemBuilder: (_) => [
        for (final s in _Size.values)
          PopupMenuItem<_Size>(
            value: s,
            child: Text(
              s.label,
              style: GoogleFonts.spaceGrotesk(
                color: s == _placementSize
                    ? AppDS.accent
                    : context.appTextPrimary,
                fontSize: 13,
                fontWeight: s == _placementSize
                    ? FontWeight.w600
                    : FontWeight.normal,
              ),
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.transparent,
          border: Border.all(color: context.appBorder),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.aspect_ratio, size: 14, color: context.appTextSecondary),
            const SizedBox(width: 4),
            Text(
              _placementSize.label,
              style: GoogleFonts.spaceGrotesk(
                color: context.appTextSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.arrow_drop_down,
              size: 14,
              color: context.appTextSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.meeting_room_outlined,
            size: 56,
            color: context.appTextMuted,
          ),
          const SizedBox(height: 12),
          Text(
            'No rooms to lay out yet.',
            style: GoogleFonts.spaceGrotesk(
              color: context.appTextSecondary,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Add rooms in Rooms & Locations first — they will appear here for placement.',
            style: GoogleFonts.spaceGrotesk(
              color: context.appTextMuted,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final w = constraints.maxWidth;
        final canvas = _buildCanvas(context);
        final panel = _buildPanel(context);
        if (w < 700) {
          return Column(
            children: [
              Expanded(flex: 3, child: canvas),
              SizedBox(
                height: 240,
                child: Container(
                  decoration: BoxDecoration(
                    color: context.appSurface,
                    border: Border(top: BorderSide(color: context.appBorder)),
                  ),
                  child: panel,
                ),
              ),
            ],
          );
        }
        final panelW = math.min(320.0, w * 0.4);
        return Row(
          children: [
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
          ],
        );
      },
    );
  }

  Widget _buildCanvas(BuildContext context) {
    final size = _canvasSize;
    final placementActive = _tool != _Tool.select;
    return Container(
      color: context.appBg,
      child: InteractiveViewer(
        transformationController: _viewerCtrl,
        minScale: 0.4,
        maxScale: 4,
        boundaryMargin: const EdgeInsets.all(800),
        constrained: false,
        // Disable InteractiveViewer's own pan when something is selected or
        // a placement tool is active, so the gesture doesn't fight room/decor
        // drag or tap-to-place.
        panEnabled:
            _selectedRoomId == null &&
            _selectedLocationId == null &&
            _selectedDecorId == null &&
            !placementActive,
        child: GestureDetector(
          // Stack-local coordinates (= canvas coords) come through onTapUp.
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) {
            if (placementActive) {
              final kind = switch (_tool) {
                _Tool.wall => _DecorKind.wall,
                _Tool.door => _DecorKind.door,
                _Tool.corridor => _DecorKind.corridor,
                _Tool.bathroom => _DecorKind.bathroom,
                _Tool.select => null,
              };
              if (kind != null) _placeDecor(kind, details.localPosition);
              return;
            }
            // Empty-canvas tap with the select tool → deselect.
            setState(() {
              _selectedRoomId = null;
              _selectedLocationId = null;
              _selectedDecorId = null;
            });
          },
          child: MouseRegion(
            cursor: placementActive
                ? SystemMouseCursors.precise
                : SystemMouseCursors.basic,
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _GridPainter(context.appBorder),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _CorridorPainter(
                          _decors.where(_isBackgroundDecor).toList(),
                        ),
                      ),
                    ),
                  ),
                  for (final d in _decors.where(_isBackgroundDecor))
                    _buildDecorShape(context, d),
                  for (final room in _rooms) _buildRoomShape(context, room),
                  for (final loc in _locations)
                    _buildLocationShape(context, loc),
                  for (final d in _decors.where((d) => !_isBackgroundDecor(d)))
                    _buildDecorShape(context, d),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _isBackgroundDecor(_Decor d) => d.kind == _DecorKind.corridor;

  Widget _buildLocationShape(BuildContext context, _CanvasLocation loc) {
    final selected = loc.clientId == _selectedLocationId;
    final accent = LocationModel.typeAccent(loc.type);
    final icon = LocationModel.typeIcon(loc.type);
    final displayName = loc.name.trim().isEmpty
        ? LocationModel.typeLabel(loc.type)
        : loc.name;

    return Positioned(
      left: loc.geom.x,
      top: loc.geom.y,
      width: loc.geom.w,
      height: loc.geom.h,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _selectLocation(loc.clientId),
            onDoubleTap: loc.dbId == null
                ? null
                : () => _openLocationDetailFromBuilder(loc),
            onPanStart: (_) {
              if (!selected) _selectLocation(loc.clientId);
            },
            onPanUpdate: (d) => _moveLocation(loc.clientId, d.delta),
            onPanEnd: (_) => _snapSelected(),
            child: MouseRegion(
              cursor: selected
                  ? SystemMouseCursors.move
                  : SystemMouseCursors.click,
              child: Container(
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: selected ? 0.24 : 0.16),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected ? accent : accent.withValues(alpha: 0.75),
                    width: selected ? 2.2 : 1.2,
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.30),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
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
                      ],
                    ),
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
          if (selected)
            Positioned(
              right: -_kHandleSize / 2,
              bottom: -_kHandleSize / 2,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (d) => _resizeLocation(loc.clientId, d.delta),
                onPanEnd: (_) => _snapSelected(),
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeDownRight,
                  child: Container(
                    width: _kHandleSize,
                    height: _kHandleSize,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDecorShape(BuildContext context, _Decor d) {
    final selected = d.id == _selectedDecorId;
    final accent = switch (d.kind) {
      _DecorKind.wall => const Color(0xFF64748B), // slate
      _DecorKind.door => const Color(0xFFF97316), // orange
      _DecorKind.corridor => const Color(0xFFB08968), // warm taupe
      _DecorKind.bathroom => const Color(0xFF38BDF8), // sky (matches lab)
    };
    final fillAlpha = switch (d.kind) {
      _DecorKind.wall => selected ? 0.85 : 0.7,
      _DecorKind.door => selected ? 0.88 : 0.78,
      _DecorKind.corridor => selected ? 0.22 : 0.16,
      _DecorKind.bathroom => selected ? 0.30 : 0.18,
    };
    final icon = switch (d.kind) {
      _DecorKind.wall => null,
      _DecorKind.door => null,
      _DecorKind.corridor => null,
      _DecorKind.bathroom => Icons.wc,
    };

    return Positioned(
      left: d.x,
      top: d.y,
      width: d.w,
      height: d.h,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _selectDecor(d.id),
            onPanStart: (_) {
              if (!selected) _selectDecor(d.id);
            },
            onPanUpdate: (e) => _moveDecor(d.id, e.delta),
            onPanEnd: (_) => _snapSelected(),
            child: MouseRegion(
              cursor: selected
                  ? SystemMouseCursors.move
                  : SystemMouseCursors.click,
              child: Container(
                decoration: BoxDecoration(
                  color: d.kind == _DecorKind.corridor
                      ? (selected
                            ? accent.withValues(alpha: 0.08)
                            : Colors.transparent)
                      : accent.withValues(alpha: fillAlpha),
                  borderRadius: BorderRadius.circular(switch (d.kind) {
                    _DecorKind.wall => 2,
                    _DecorKind.door => 999,
                    _DecorKind.corridor => 0,
                    _DecorKind.bathroom => 6,
                  }),
                  border: d.kind == _DecorKind.corridor && !selected
                      ? null
                      : Border.all(
                          color: selected
                              ? accent
                              : accent.withValues(alpha: 0.7),
                          width: selected ? 2 : 1.2,
                        ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.35),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: icon == null
                    ? (d.kind == _DecorKind.corridor && selected && d.h > 34
                          ? Text(
                              d.label ?? 'Corridor',
                              style: GoogleFonts.spaceGrotesk(
                                color: accent,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          : null)
                    : (d.kind == _DecorKind.bathroom
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  icon,
                                  size: math.min(28, d.h * 0.4),
                                  color: accent,
                                ),
                                if (d.h > 60)
                                  Text(
                                    d.label ?? 'Bathroom',
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
                              size: math.min(d.w, d.h) * 0.6,
                              color: accent,
                            )),
              ),
            ),
          ),
          if (selected)
            Positioned(
              right: -_kHandleSize / 2,
              bottom: -_kHandleSize / 2,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (e) => _resizeDecor(d.id, e.delta),
                onPanEnd: (_) => _snapSelected(),
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeDownRight,
                  child: Container(
                    width: _kHandleSize,
                    height: _kHandleSize,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRoomShape(BuildContext context, LocationModel room) {
    final g = _geom[room.id];
    if (g == null) return const SizedBox.shrink();
    final selected = room.id == _selectedRoomId;
    final accent = LocationModel.typeAccent(LocationModel.roomType);
    final idx = _rooms.indexWhere((r) => r.id == room.id);
    final code = idx >= 0 ? 'R${idx + 1}' : '';
    final desc = stripLocationCodePrefix(room.name);

    return Positioned(
      left: g.x,
      top: g.y,
      width: g.w,
      height: g.h,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Body — tap to select, drag to move when already selected.
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _selectRoom(room.id),
            onPanStart: (_) {
              if (!selected) _selectRoom(room.id);
            },
            onPanUpdate: (d) => _moveRoom(room.id, d.delta),
            onPanEnd: (_) => _snapSelected(),
            child: MouseRegion(
              cursor: selected
                  ? SystemMouseCursors.move
                  : SystemMouseCursors.click,
              child: Container(
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: selected ? 0.22 : 0.10),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected ? accent : accent.withValues(alpha: 0.6),
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
                    Row(
                      children: [
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
                      ],
                    ),
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
                    Text(
                      '${g.w.toStringAsFixed(0)} × ${g.h.toStringAsFixed(0)}',
                      style: GoogleFonts.jetBrainsMono(
                        color: context.appTextMuted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Resize handle (bottom-right) — only visible when selected.
          if (selected)
            Positioned(
              right: -_kHandleSize / 2,
              bottom: -_kHandleSize / 2,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (d) => _resizeRoom(room.id, d.delta),
                onPanEnd: (_) => _snapSelected(),
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeDownRight,
                  child: Container(
                    width: _kHandleSize,
                    height: _kHandleSize,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDecorPanel(BuildContext context, _Decor d) {
    final kindLabel = switch (d.kind) {
      _DecorKind.wall => 'Wall',
      _DecorKind.door => 'Door',
      _DecorKind.corridor => 'Corridor',
      _DecorKind.bathroom => 'Bathroom',
    };
    final kindColor = switch (d.kind) {
      _DecorKind.wall => const Color(0xFF64748B),
      _DecorKind.door => const Color(0xFFF97316),
      _DecorKind.corridor => const Color(0xFFB08968),
      _DecorKind.bathroom => const Color(0xFF38BDF8),
    };
    final kindIcon = switch (d.kind) {
      _DecorKind.wall => Icons.horizontal_rule,
      _DecorKind.door => Icons.remove,
      _DecorKind.corridor => Icons.space_dashboard_outlined,
      _DecorKind.bathroom => Icons.wc,
    };
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: kindColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(kindIcon, color: kindColor, size: 16),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                kindLabel,
                style: GoogleFonts.spaceGrotesk(
                  color: context.appTextPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(
                Icons.delete_outline,
                size: 18,
                color: AppDS.red,
              ),
              onPressed: _deleteSelectedDecor,
            ),
          ],
        ),
        if (d.kind == _DecorKind.bathroom || d.kind == _DecorKind.corridor) ...[
          const SizedBox(height: 12),
          _LabelField(
            // Remount when the user picks a different decoration so the
            // controller starts on the right text.
            key: ValueKey('label_${d.id}'),
            initial: d.label ?? '',
            labelText: d.kind == _DecorKind.bathroom ? 'Label' : 'Name',
            onChanged: (v) =>
                setState(() => _replaceDecor(d.copyWith(label: v))),
          ),
        ],
        const SizedBox(height: 16),
        Text(
          'GEOMETRY',
          style: GoogleFonts.spaceGrotesk(
            color: context.appTextMuted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        _GeomField(
          label: 'X',
          value: d.x,
          onChanged: (v) => setState(() {
            final next = _clampFreeGeomToCanvas(
              _RoomGeom(x: v, y: d.y, w: d.w, h: d.h),
              minW: _kMinDecorSize,
              minH: _kMinDecorSize,
            );
            _replaceDecor(
              d.copyWith(x: next.x, y: next.y, w: next.w, h: next.h),
            );
          }),
        ),
        const SizedBox(height: 6),
        _GeomField(
          label: 'Y',
          value: d.y,
          onChanged: (v) => setState(() {
            final next = _clampFreeGeomToCanvas(
              _RoomGeom(x: d.x, y: v, w: d.w, h: d.h),
              minW: _kMinDecorSize,
              minH: _kMinDecorSize,
            );
            _replaceDecor(
              d.copyWith(x: next.x, y: next.y, w: next.w, h: next.h),
            );
          }),
        ),
        const SizedBox(height: 6),
        _GeomField(
          label: 'W',
          value: d.w,
          onChanged: (v) => setState(() {
            final next = _clampFreeGeomToCanvas(
              _RoomGeom(x: d.x, y: d.y, w: v, h: d.h),
              minW: _kMinDecorSize,
              minH: _kMinDecorSize,
            );
            _replaceDecor(
              d.copyWith(x: next.x, y: next.y, w: next.w, h: next.h),
            );
          }),
        ),
        const SizedBox(height: 6),
        _GeomField(
          label: 'H',
          value: d.h,
          onChanged: (v) => setState(() {
            final next = _clampFreeGeomToCanvas(
              _RoomGeom(x: d.x, y: d.y, w: d.w, h: v),
              minW: _kMinDecorSize,
              minH: _kMinDecorSize,
            );
            _replaceDecor(
              d.copyWith(x: next.x, y: next.y, w: next.w, h: next.h),
            );
          }),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _snapSelected,
          icon: const Icon(Icons.straighten, size: 14),
          label: const Text('Snap to grid'),
          style: OutlinedButton.styleFrom(
            foregroundColor: context.appTextSecondary,
            side: BorderSide(color: context.appBorder),
            minimumSize: const Size(double.infinity, 32),
            textStyle: GoogleFonts.spaceGrotesk(fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationPanel(BuildContext context, _CanvasLocation loc) {
    final accent = LocationModel.typeAccent(loc.type);
    final icon = LocationModel.typeIcon(loc.type);
    final room = _rooms.firstWhere((r) => r.id == loc.parentRoomId);
    final roomIdx = _rooms.indexWhere((r) => r.id == room.id);
    final roomCode = roomIdx >= 0 ? 'R${roomIdx + 1}' : '';
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, color: accent, size: 16),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                LocationModel.typeLabel(loc.type),
                style: GoogleFonts.spaceGrotesk(
                  color: context.appTextPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (loc.dbId != null)
              IconButton(
                tooltip: 'Open location',
                icon: Icon(
                  Icons.open_in_new,
                  size: 16,
                  color: context.appTextSecondary,
                ),
                onPressed: () => _openLocationDetailFromBuilder(loc),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _LabelField(
          key: ValueKey('loc_name_${loc.clientId}'),
          initial: loc.name,
          labelText: 'Name',
          onChanged: (v) => setState(
            () => _replaceLocation(
              loc.copyWith(name: v.trim().isEmpty ? loc.name : v.trim()),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: context.appSurface2,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: context.appBorder),
          ),
          child: Row(
            children: [
              Text(
                roomCode,
                style: GoogleFonts.jetBrainsMono(
                  color: AppDS.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  stripLocationCodePrefix(room.name),
                  style: GoogleFonts.spaceGrotesk(
                    color: context.appTextSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (loc.dbId == null) ...[
          const SizedBox(height: 10),
          Text(
            'This location will be created in storage_locations when you save.',
            style: GoogleFonts.spaceGrotesk(
              color: context.appTextMuted,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
        const SizedBox(height: 16),
        Text(
          'GEOMETRY',
          style: GoogleFonts.spaceGrotesk(
            color: context.appTextMuted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        _GeomField(
          label: 'X',
          value: loc.geom.x,
          onChanged: (v) {
            final roomGeom = _geom[loc.parentRoomId];
            if (roomGeom == null) return;
            setState(
              () => _replaceLocation(
                loc.copyWith(
                  geom: _clampLocationGeom(
                    roomGeom,
                    _RoomGeom(
                      x: v,
                      y: loc.geom.y,
                      w: loc.geom.w,
                      h: loc.geom.h,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 6),
        _GeomField(
          label: 'Y',
          value: loc.geom.y,
          onChanged: (v) {
            final roomGeom = _geom[loc.parentRoomId];
            if (roomGeom == null) return;
            setState(
              () => _replaceLocation(
                loc.copyWith(
                  geom: _clampLocationGeom(
                    roomGeom,
                    _RoomGeom(
                      x: loc.geom.x,
                      y: v,
                      w: loc.geom.w,
                      h: loc.geom.h,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 6),
        _GeomField(
          label: 'W',
          value: loc.geom.w,
          onChanged: (v) {
            final roomGeom = _geom[loc.parentRoomId];
            if (roomGeom == null) return;
            setState(
              () => _replaceLocation(
                loc.copyWith(
                  geom: _clampLocationGeom(
                    roomGeom,
                    _RoomGeom(
                      x: loc.geom.x,
                      y: loc.geom.y,
                      w: math.max(_kMinLocationSize, v),
                      h: loc.geom.h,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 6),
        _GeomField(
          label: 'H',
          value: loc.geom.h,
          onChanged: (v) {
            final roomGeom = _geom[loc.parentRoomId];
            if (roomGeom == null) return;
            setState(
              () => _replaceLocation(
                loc.copyWith(
                  geom: _clampLocationGeom(
                    roomGeom,
                    _RoomGeom(
                      x: loc.geom.x,
                      y: loc.geom.y,
                      w: loc.geom.w,
                      h: math.max(_kMinLocationSize, v),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _snapSelected,
          icon: const Icon(Icons.straighten, size: 14),
          label: const Text('Snap to grid'),
          style: OutlinedButton.styleFrom(
            foregroundColor: context.appTextSecondary,
            side: BorderSide(color: context.appBorder),
            minimumSize: const Size(double.infinity, 32),
            textStyle: GoogleFonts.spaceGrotesk(fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildPanel(BuildContext context) {
    final decorId = _selectedDecorId;
    if (decorId != null) {
      final d = _decorById(decorId);
      if (d != null) return _buildDecorPanel(context, d);
    }
    final locationId = _selectedLocationId;
    if (locationId != null) {
      final loc = _locationById(locationId);
      if (loc != null) return _buildLocationPanel(context, loc);
    }
    final id = _selectedRoomId;
    if (id == null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        children: [
          Icon(Icons.swipe, size: 36, color: context.appTextMuted),
          const SizedBox(height: 10),
          Text(
            'Tap a room or shape to edit it',
            textAlign: TextAlign.center,
            style: GoogleFonts.spaceGrotesk(
              color: context.appTextSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '· Pick a tool then click the canvas to add a wall, door, or bathroom.\n'
            '· Drag a shape to move it.\n'
            '· Drag the corner to resize.\n'
            '· Snap can be toggled in the AppBar.',
            textAlign: TextAlign.center,
            style: GoogleFonts.spaceGrotesk(
              color: context.appTextMuted,
              fontSize: 11,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'BACKGROUND SIZE',
            style: GoogleFonts.spaceGrotesk(
              color: context.appTextMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          _GeomField(
            label: 'W',
            value: _backgroundSize.width,
            onChanged: (v) => setState(() {
              _backgroundSize = _normalizeCanvasSize(
                Size(v, _backgroundSize.height),
              );
            }),
          ),
          const SizedBox(height: 6),
          _GeomField(
            label: 'H',
            value: _backgroundSize.height,
            onChanged: (v) => setState(() {
              _backgroundSize = _normalizeCanvasSize(
                Size(_backgroundSize.width, v),
              );
            }),
          ),
          const SizedBox(height: 10),
          Text(
            'This sets the editable background area. It will not shrink smaller than the placed layout.',
            style: GoogleFonts.spaceGrotesk(
              color: context.appTextMuted,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      );
    }
    final room = _rooms.firstWhere((r) => r.id == id);
    final g = _geom[id]!;
    final idx = _rooms.indexWhere((r) => r.id == id);
    final code = 'R${idx + 1}';
    final desc = stripLocationCodePrefix(room.name);
    final roomLocations = _locationsForRoom(room.id);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppDS.accent.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                code,
                style: GoogleFonts.jetBrainsMono(
                  color: AppDS.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                desc.isEmpty ? '—' : desc,
                style: GoogleFonts.spaceGrotesk(
                  color: context.appTextPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _saving ? null : () => _addLocationToRoom(room.id),
          icon: const Icon(Icons.add_box_outlined, size: 16),
          label: const Text('Add location here'),
          style: FilledButton.styleFrom(
            backgroundColor: AppDS.accent,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 36),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: GoogleFonts.spaceGrotesk(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'IN-ROOM LOCATIONS  (${roomLocations.length})',
          style: GoogleFonts.spaceGrotesk(
            color: context.appTextMuted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        if (roomLocations.isEmpty)
          Text(
            'No locations placed in this room yet.',
            style: GoogleFonts.spaceGrotesk(
              color: context.appTextMuted,
              fontSize: 12,
            ),
          )
        else
          for (final loc in roomLocations)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => _selectLocation(loc.clientId),
                  onDoubleTap: loc.dbId == null
                      ? null
                      : () => _openLocationDetailFromBuilder(loc),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: context.appSurface2,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: context.appBorder),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          LocationModel.typeIcon(loc.type),
                          size: 13,
                          color: LocationModel.typeAccent(loc.type),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            loc.name.trim().isEmpty
                                ? LocationModel.typeLabel(loc.type)
                                : loc.name,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.spaceGrotesk(
                              color: context.appTextPrimary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Text(
                          LocationModel.typeLabel(loc.type),
                          style: GoogleFonts.jetBrainsMono(
                            color: context.appTextMuted,
                            fontSize: 10,
                          ),
                        ),
                        if (loc.dbId != null) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.open_in_new,
                            size: 14,
                            color: context.appTextMuted,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
        const SizedBox(height: 16),
        Text(
          'GEOMETRY',
          style: GoogleFonts.spaceGrotesk(
            color: context.appTextMuted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        _GeomField(
          label: 'X',
          value: g.x,
          onChanged: (v) => setState(
            () => _geom[id] = _clampFreeGeomToCanvas(
              _RoomGeom(x: v, y: g.y, w: g.w, h: g.h),
              minW: _kMinRoomSize,
              minH: _kMinRoomSize,
            ),
          ),
        ),
        const SizedBox(height: 6),
        _GeomField(
          label: 'Y',
          value: g.y,
          onChanged: (v) => setState(
            () => _geom[id] = _clampFreeGeomToCanvas(
              _RoomGeom(x: g.x, y: v, w: g.w, h: g.h),
              minW: _kMinRoomSize,
              minH: _kMinRoomSize,
            ),
          ),
        ),
        const SizedBox(height: 6),
        _GeomField(
          label: 'W',
          value: g.w,
          onChanged: (v) => setState(
            () => _geom[id] = _clampFreeGeomToCanvas(
              _RoomGeom(x: g.x, y: g.y, w: v, h: g.h),
              minW: _kMinRoomSize,
              minH: _kMinRoomSize,
            ),
          ),
        ),
        const SizedBox(height: 6),
        _GeomField(
          label: 'H',
          value: g.h,
          onChanged: (v) => setState(
            () => _geom[id] = _clampFreeGeomToCanvas(
              _RoomGeom(x: g.x, y: g.y, w: g.w, h: v),
              minW: _kMinRoomSize,
              minH: _kMinRoomSize,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _snapSelected,
                icon: const Icon(Icons.straighten, size: 14),
                label: const Text('Snap to grid'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.appTextSecondary,
                  side: BorderSide(color: context.appBorder),
                  minimumSize: const Size(0, 32),
                  textStyle: GoogleFonts.spaceGrotesk(fontSize: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  final base = _baseline[id];
                  if (base != null) setState(() => _geom[id] = base);
                },
                icon: const Icon(Icons.undo, size: 14),
                label: const Text('Reset'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.appTextSecondary,
                  side: BorderSide(color: context.appBorder),
                  minimumSize: const Size(0, 32),
                  textStyle: GoogleFonts.spaceGrotesk(fontSize: 12),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Geometry is stored as JSON on the storage_locations row '
          '(location_layout). The viewer reads the same field, so saved '
          'changes appear in Lab Map immediately.',
          style: GoogleFonts.spaceGrotesk(
            color: context.appTextMuted,
            fontSize: 11,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

// ─── Decoration (wall / door / bathroom) ────────────────────────────────────
// Lives in app_meta.meta_settings.lab_layout.decorations and is rendered on
// top of the room shapes. Identity is a client-generated string id so we can
// move/resize/delete each one without involving a DB row.
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

  _Decor copyWith({
    double? x,
    double? y,
    double? w,
    double? h,
    String? label,
  }) => _Decor(
    id: id,
    kind: kind,
    x: x ?? this.x,
    y: y ?? this.y,
    w: w ?? this.w,
    h: h ?? this.h,
    label: label ?? this.label,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.id,
    'x': x,
    'y': y,
    'w': w,
    'h': h,
    if (label != null) 'label': label,
  };

  static _Decor? tryParse(dynamic raw) {
    if (raw is! Map) return null;
    final kind = _DecorKindParse.parse(raw['kind'] as String?);
    final id = raw['id'] as String?;
    final x = (raw['x'] as num?)?.toDouble();
    final y = (raw['y'] as num?)?.toDouble();
    final w = (raw['w'] as num?)?.toDouble();
    final h = (raw['h'] as num?)?.toDouble();
    if (kind == null ||
        id == null ||
        x == null ||
        y == null ||
        w == null ||
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

// Workaround: Dart doesn't allow extension static methods to be referenced
// from outside the extension's own scope, so expose `_DecorKind.parse` via a
// stand-alone helper.
class _DecorKindParse {
  static _DecorKind? parse(String? raw) => switch (raw) {
    'wall' => _DecorKind.wall,
    'door' => _DecorKind.door,
    'corridor' => _DecorKind.corridor,
    'bathroom' => _DecorKind.bathroom,
    _ => null,
  };
}

class _CanvasLocation {
  final String clientId;
  final int? dbId;
  final int parentRoomId;
  final String name;
  final String type;
  final int? sortOrder;
  final _RoomGeom geom;

  const _CanvasLocation({
    required this.clientId,
    required this.dbId,
    required this.parentRoomId,
    required this.name,
    required this.type,
    required this.sortOrder,
    required this.geom,
  });

  _CanvasLocation copyWith({
    int? dbId,
    int? parentRoomId,
    String? name,
    String? type,
    int? sortOrder,
    _RoomGeom? geom,
  }) => _CanvasLocation(
    clientId: clientId,
    dbId: dbId ?? this.dbId,
    parentRoomId: parentRoomId ?? this.parentRoomId,
    name: name ?? this.name,
    type: type ?? this.type,
    sortOrder: sortOrder ?? this.sortOrder,
    geom: geom ?? this.geom,
  );

  @override
  bool operator ==(Object other) =>
      other is _CanvasLocation &&
      other.clientId == clientId &&
      other.dbId == dbId &&
      other.parentRoomId == parentRoomId &&
      other.name == name &&
      other.type == type &&
      other.sortOrder == sortOrder &&
      other.geom == geom;

  @override
  int get hashCode =>
      Object.hash(clientId, dbId, parentRoomId, name, type, sortOrder, geom);
}

class _NewCanvasLocation {
  final String name;
  final String type;
  const _NewCanvasLocation({required this.name, required this.type});
}

// ─── Geometry record + JSON ─────────────────────────────────────────────────
class _RoomGeom {
  final double x, y, w, h;
  const _RoomGeom({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });

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

  Map<String, dynamic> toJson() => {'x': x, 'y': y, 'w': w, 'h': h};

  @override
  bool operator ==(Object other) =>
      other is _RoomGeom &&
      other.x == x &&
      other.y == y &&
      other.w == w &&
      other.h == h;

  @override
  int get hashCode => Object.hash(x, y, w, h);
}

// ─── Background grid ────────────────────────────────────────────────────────
class _CorridorPainter extends CustomPainter {
  final List<_Decor> corridors;

  const _CorridorPainter(this.corridors);

  @override
  void paint(Canvas canvas, Size size) {
    if (corridors.isEmpty) return;

    Path? corridorPath;
    for (final corridor in corridors) {
      // This slight overlap prevents anti-aliasing seams where snapped
      // corridor segments meet edge-to-edge.
      final segment = Path()
        ..addRect(
          Rect.fromLTWH(
            corridor.x,
            corridor.y,
            corridor.w,
            corridor.h,
          ).inflate(0.35),
        );
      corridorPath = corridorPath == null
          ? segment
          : Path.combine(PathOperation.union, corridorPath, segment);
    }

    const accent = Color(0xFFB08968);
    canvas.drawPath(
      corridorPath!,
      Paint()
        ..style = PaintingStyle.fill
        ..color = accent.withValues(alpha: 0.16),
    );
    canvas.drawPath(
      corridorPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = accent.withValues(alpha: 0.7),
    );
  }

  @override
  bool shouldRepaint(covariant _CorridorPainter oldDelegate) => true;
}

class _GridPainter extends CustomPainter {
  final Color color;
  const _GridPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..strokeWidth = 0.5;
    for (double x = 0; x < size.width; x += _kGridStep) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += _kGridStep) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) => old.color != color;
}

// ─── Tiny single-line text field for the right panel (debounced) ────────────
class _LabelField extends StatefulWidget {
  final String initial;
  final String labelText;
  final ValueChanged<String> onChanged;
  const _LabelField({
    super.key,
    required this.initial,
    this.labelText = 'Label',
    required this.onChanged,
  });

  @override
  State<_LabelField> createState() => _LabelFieldState();
}

class _LabelFieldState extends State<_LabelField> {
  late final TextEditingController _ctrl;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      style: GoogleFonts.spaceGrotesk(
        color: context.appTextPrimary,
        fontSize: 13,
      ),
      onChanged: (v) {
        _debounce?.cancel();
        _debounce = Timer(
          const Duration(milliseconds: 250),
          () => widget.onChanged(v),
        );
      },
      onSubmitted: widget.onChanged,
      decoration: InputDecoration(
        isDense: true,
        labelText: widget.labelText,
        labelStyle: GoogleFonts.spaceGrotesk(
          color: context.appTextSecondary,
          fontSize: 11,
        ),
        filled: true,
        fillColor: context.appSurface3,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: context.appBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: context.appBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppDS.accent),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      ),
    );
  }
}

// ─── Tiny labelled numeric field for the right panel ────────────────────────
class _GeomField extends StatefulWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  const _GeomField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  State<_GeomField> createState() => _GeomFieldState();
}

class _GeomFieldState extends State<_GeomField> {
  late final TextEditingController _ctrl;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: _format(widget.value));
  }

  @override
  void didUpdateWidget(covariant _GeomField old) {
    super.didUpdateWidget(old);
    final formatted = _format(widget.value);
    if (formatted != _ctrl.text) {
      // External update (drag, snap, reset) — overwrite without firing the
      // listener-style debounce.
      _ctrl.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  String _format(double v) =>
      v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 1);

  void _onChanged(String raw) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      final v = double.tryParse(raw.trim());
      if (v != null) widget.onChanged(v);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 22,
          child: Text(
            widget.label,
            style: GoogleFonts.jetBrainsMono(
              color: context.appTextMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: TextField(
            controller: _ctrl,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: false,
            ),
            style: GoogleFonts.jetBrainsMono(
              color: context.appTextPrimary,
              fontSize: 12,
            ),
            onChanged: _onChanged,
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: context.appSurface3,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: context.appBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: context.appBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppDS.accent),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 6,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AddCanvasLocationDialog extends StatefulWidget {
  final LocationModel room;
  const _AddCanvasLocationDialog({required this.room});

  @override
  State<_AddCanvasLocationDialog> createState() =>
      _AddCanvasLocationDialogState();
}

class _AddCanvasLocationDialogState extends State<_AddCanvasLocationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  String _type = 'cabinet';

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.appSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(
        'Add Location',
        style: GoogleFonts.spaceGrotesk(
          color: context.appTextPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stripLocationCodePrefix(widget.room.name),
                style: GoogleFonts.spaceGrotesk(
                  color: context.appTextMuted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _type,
                dropdownColor: context.appSurface,
                decoration: InputDecoration(
                  labelText: 'Type',
                  labelStyle: GoogleFonts.spaceGrotesk(
                    color: context.appTextSecondary,
                    fontSize: 11,
                  ),
                  filled: true,
                  fillColor: context.appSurface3,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: context.appBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: context.appBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: AppDS.accent),
                  ),
                ),
                style: GoogleFonts.spaceGrotesk(
                  color: context.appTextPrimary,
                  fontSize: 13,
                ),
                items: [
                  for (final group in LocationModel.locationSubtypeGroups) ...[
                    DropdownMenuItem<String>(
                      enabled: false,
                      value: '__header_${group.$1}',
                      child: Text(
                        group.$1.toUpperCase(),
                        style: GoogleFonts.spaceGrotesk(
                          color: context.appTextMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    for (final type in group.$2)
                      DropdownMenuItem<String>(
                        value: type,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(LocationModel.typeLabel(type)),
                        ),
                      ),
                  ],
                ],
                onChanged: (value) {
                  if (value == null || value.startsWith('__header_')) return;
                  setState(() => _type = value);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameCtrl,
                style: GoogleFonts.spaceGrotesk(
                  color: context.appTextPrimary,
                  fontSize: 13,
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                decoration: InputDecoration(
                  labelText: 'Name',
                  labelStyle: GoogleFonts.spaceGrotesk(
                    color: context.appTextSecondary,
                    fontSize: 11,
                  ),
                  filled: true,
                  fillColor: context.appSurface3,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: context.appBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: context.appBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: AppDS.accent),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: GoogleFonts.spaceGrotesk(color: context.appTextSecondary),
          ),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(
              context,
              _NewCanvasLocation(name: _nameCtrl.text.trim(), type: _type),
            );
          },
          style: FilledButton.styleFrom(
            backgroundColor: AppDS.accent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text('Add', style: GoogleFonts.spaceGrotesk()),
        ),
      ],
    );
  }
}
