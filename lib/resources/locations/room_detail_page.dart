// room_detail_page.dart - Room detail editor.
// Fields: name, responsible, notes. Sub-locations sorted numerically by L#.# suffix.
// Pushed via Navigator with its own Scaffold + AppBar.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide LocalStorage;
import '/theme/theme.dart';
import '/theme/module_permission.dart';
import 'detail_widgets.dart';
import 'location_detail_page.dart';
import 'location_model.dart';

class RoomDetailPage extends StatefulWidget {
  final int locationId;
  const RoomDetailPage({super.key, required this.locationId});

  @override
  State<RoomDetailPage> createState() => _RoomDetailPageState();
}

class _RoomDetailPageState extends State<RoomDetailPage> {
  LocationModel? _room;
  List<LocationModel> _children = [];
  List<Map<String, dynamic>> _users = [];
  final Map<int, String> _childCodes = {};
  bool _loading = true;
  bool _saving = false;
  bool _editMode = false;
  final Set<int> _expanded = {0, 1, 2};

  late final TextEditingController _nameCtrl;
  late final TextEditingController _responsibleCtrl;
  late final TextEditingController _notesCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl        = TextEditingController();
    _responsibleCtrl = TextEditingController();
    _notesCtrl       = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _responsibleCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await Supabase.instance.client
          .from('storage_locations')
          .select()
          .eq('location_id', widget.locationId)
          .limit(1);

      if (rows.isEmpty) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final room = LocationModel.fromMap(rows[0]);

      final roomRows = await Supabase.instance.client
          .from('storage_locations')
          .select('location_id, location_name, location_sort_order')
          .eq('location_type', LocationModel.roomType);
      final allRooms = roomRows
          .map<LocationModel>((c) => LocationModel.fromMap(c))
          .toList()
        ..sort(_bySortThenName);
      final roomIdx = allRooms.indexWhere((r) => r.id == room.id);

      final childRows = await Supabase.instance.client
          .from('storage_locations')
          .select()
          .eq('location_parent_id', widget.locationId);
      final children = childRows
          .map<LocationModel>((c) => LocationModel.fromMap(c))
          .toList()
        ..sort(_bySortThenName);

      List<Map<String, dynamic>> users = [];
      try {
        final userRows = await Supabase.instance.client
            .from('users')
            .select('user_id, user_email, user_name, user_phone, '
                'user_institution, user_group, user_role')
            .order('user_name');
        users = List<Map<String, dynamic>>.from(userRows);
      } catch (e) {
        debugPrint('room_detail: users lookup failed: $e');
      }

      final codes = <int, String>{
        for (var i = 0; i < children.length; i++)
          children[i].id:
              roomIdx >= 0 ? 'L${roomIdx + 1}.${i + 1}' : 'L?.${i + 1}',
      };

      if (mounted) {
        _nameCtrl.text        = stripLocationCodePrefix(room.name);
        _responsibleCtrl.text = room.responsible ?? '';
        _notesCtrl.text       = room.notes ?? '';

        setState(() {
          _room      = room;
          _children  = children;
          _users     = users;
          _childCodes
            ..clear()
            ..addAll(codes);
          _loading   = false;
        });
      }
    } catch (e) {
      debugPrint('room_detail: load failed: $e');
      if (mounted) {
        setState(() => _loading = false);
        detailSnack(context, 'Failed to load: $e');
      }
    }
  }

  int _bySortThenName(LocationModel a, LocationModel b) {
    final ao = a.sortOrder;
    final bo = b.sortOrder;
    if (ao != null && bo != null) return ao.compareTo(bo);
    if (ao != null) return -1;
    if (bo != null) return 1;
    return a.name.compareTo(b.name);
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      detailSnack(context, 'Name is required');
      return;
    }
    setState(() => _saving = true);
    try {
      final data = <String, dynamic>{
        'location_name': _nameCtrl.text.trim(),
        'location_type': LocationModel.roomType,
        'location_responsible': _responsibleCtrl.text.trim().isEmpty
            ? null
            : _responsibleCtrl.text.trim(),
        'location_notes':
            _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        'location_parent_id': null,
        'location_temperature': null,
        'location_capacity': null,
      };
      await Supabase.instance.client
          .from('storage_locations')
          .update(data)
          .eq('location_id', widget.locationId);
      await _load();
      if (mounted) {
        setState(() => _editMode = false);
        detailSnack(context, 'Saved');
      }
    } catch (e) {
      debugPrint('room_detail: save failed: $e');
      if (mounted) detailSnack(context, 'Save failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final name = _room?.name ?? 'this room';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.appSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Delete Room?',
            style: GoogleFonts.spaceGrotesk(
                color: ctx.appTextPrimary, fontWeight: FontWeight.w600)),
        content: Text(
          'This will permanently delete "$name". Sub-locations inside will be unlinked but kept. This cannot be undone.',
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
    final client = Supabase.instance.client;
    final fkUnlinks = <(String table, String column)>[
      ('reagents', 'reagent_location_id'),
      ('strains', 'strain_location_id'),
      ('equipment', 'equipment_location_id'),
      ('storage_locations', 'location_parent_id'),
    ];
    for (final (table, column) in fkUnlinks) {
      try {
        await client
            .from(table)
            .update({column: null})
            .eq(column, widget.locationId);
      } catch (e) {
        debugPrint('room_detail: unlink $table.$column failed: $e');
      }
    }
    try {
      await client
          .from('storage_locations')
          .delete()
          .eq('location_id', widget.locationId);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      debugPrint('room_detail: delete failed: $e');
      if (mounted) detailSnack(context, 'Delete failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final room = _room;
    final accent = LocationModel.typeAccent(LocationModel.roomType);

    return Scaffold(
      backgroundColor: context.appBg,
      appBar: AppBar(
        backgroundColor: context.appSurface2,
        foregroundColor: context.appTextPrimary,
        elevation: 0,
        title: Text(
          'Room',
          style: GoogleFonts.spaceGrotesk(
              color: context.appTextPrimary, fontWeight: FontWeight.w600),
        ),
        actions: [
          if (room != null) ...[
            if (_editMode)
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 20, color: AppDS.red),
                tooltip: 'Delete',
                onPressed: _delete,
              ),
            if (_editMode && !_saving)
              IconButton(
                icon: Icon(Icons.close,
                    size: 20, color: context.appTextSecondary),
                tooltip: 'Cancel',
                onPressed: () {
                  setState(() => _editMode = false);
                  _load();
                },
              ),
            _saving
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white)))
                : _editMode
                    ? TextButton.icon(
                        onPressed: _save,
                        icon: const Icon(Icons.save_outlined,
                            size: 16, color: AppDS.accent),
                        label: Text('Save',
                            style: GoogleFonts.spaceGrotesk(
                                color: AppDS.accent)),
                      )
                    : TextButton.icon(
                        onPressed: () {
                          if (!context.canEditModule) {
                            context.warnReadOnly();
                            return;
                          }
                          setState(() => _editMode = true);
                        },
                        icon: const Icon(Icons.edit_outlined,
                            size: 16, color: AppDS.accent),
                        label: Text('Edit',
                            style: GoogleFonts.spaceGrotesk(
                                color: AppDS.accent)),
                      ),
          ],
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : room == null
              ? Center(
                  child: Text('Room not found',
                      style: GoogleFonts.spaceGrotesk(color: context.appTextMuted)))
              : _buildBody(context, room, accent),
    );
  }

  Widget _buildBody(BuildContext context, LocationModel room, Color accent) {
    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _buildHeader(context, room, accent),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            DetailSection(
              title: 'ROOM DETAILS',
              icon: Icons.info_outline,
              expanded: _expanded.contains(0),
              onToggle: () => setState(() {
                _expanded.contains(0)
                    ? _expanded.remove(0)
                    : _expanded.add(0);
              }),
              child: _buildDetailsSection(context, room),
            ),
            DetailSection(
              title: 'NOTES',
              icon: Icons.notes_rounded,
              expanded: _expanded.contains(1),
              onToggle: () => setState(() {
                _expanded.contains(1)
                    ? _expanded.remove(1)
                    : _expanded.add(1);
              }),
              child: DetailInlineField(
                  label: 'Notes',
                  controller: _notesCtrl,
                  maxLines: 4,
                  readOnly: !_editMode),
            ),
            DetailSection(
              title: 'SUB-LOCATIONS (${_children.length})',
              icon: Icons.account_tree_outlined,
              expanded: _expanded.contains(2),
              onToggle: () => setState(() {
                _expanded.contains(2)
                    ? _expanded.remove(2)
                    : _expanded.add(2);
              }),
              child: _buildChildrenSection(context),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildHeader(BuildContext context, LocationModel room, Color accent) {
    return Container(
      color: context.appSurface2,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(LocationModel.typeIcon(LocationModel.roomType),
                  color: accent, size: 13),
              const SizedBox(width: 5),
              Text('Room',
                  style: GoogleFonts.spaceGrotesk(
                      color: accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
          if (room.responsible != null &&
              room.responsible!.trim().isNotEmpty) ...[
            const SizedBox(width: 10),
            Flexible(
              child: DetailResponsibleChips(
                  raw: room.responsible, users: _users),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailsSection(BuildContext context, LocationModel room) {
    final ro = !_editMode;
    return Column(children: [
      DetailFieldRow(children: [
        DetailInlineField(label: 'Name', controller: _nameCtrl, readOnly: ro),
        DetailResponsibleField(
          label: 'Responsible',
          controller: _responsibleCtrl,
          users: _users,
          readOnly: ro,
        ),
      ]),
      if (room.createdAt != null) ...[
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Created ${detailFmtDate(room.createdAt!)}',
            style:
                GoogleFonts.spaceGrotesk(color: context.appTextMuted, fontSize: 11),
          ),
        ),
      ],
    ]);
  }

  Widget _buildChildrenSection(BuildContext context) {
    if (_children.isEmpty) {
      return Text('No sub-locations in this room.',
          style: GoogleFonts.spaceGrotesk(
              color: context.appTextMuted, fontSize: 13));
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _children.map((c) {
        final acc = LocationModel.typeAccent(c.type);
        final code = _childCodes[c.id];
        final cleaned = stripLocationCodePrefix(c.name);
        final display = code == null
            ? cleaned
            : (cleaned.isEmpty ? code : '$code · $cleaned');
        return InkWell(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => LocationDetailPage(locationId: c.id)),
            );
            if (mounted) _load();
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
            decoration: BoxDecoration(
              color: context.appSurface3,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: context.appBorder),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(LocationModel.typeIcon(c.type), color: acc, size: 16),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(display,
                      style: GoogleFonts.spaceGrotesk(
                          color: context.appTextPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                  if (c.temperature != null)
                    Text(c.temperature!,
                        style: GoogleFonts.spaceGrotesk(
                            color: context.appTextMuted, fontSize: 11)),
                ],
              ),
            ]),
          ),
        );
      }).toList(),
    );
  }
}
