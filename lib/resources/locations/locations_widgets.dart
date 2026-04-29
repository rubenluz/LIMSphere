// locations_widgets.dart - Part of locations_page.dart.
// Display codes (R{n}, L{roomN}.{childN}) are passed in from the page, derived
// from sort position. _QuickAddLocationDialog assigns location_sort_order on create.
part of 'locations_page.dart';

// Strip any leading R#/L#.# prefix from a stored name so it isn't duplicated
// when the derived code is prepended at display time.
String _stripCodePrefix(String name) {
  final match = RegExp(r'^[RL]\d+(?:\.\d+)?\s*(?:[-·]\s*)?',
          caseSensitive: false)
      .firstMatch(name.trim());
  if (match == null) return name.trim();
  return name.trim().substring(match.end).trim();
}

// ─── Room Card ──────────────────────────────────────────────────────────────────
class _RoomCard extends StatefulWidget {
  final LocationModel room;
  final String roomCode;
  final List<LocationModel> children;
  final Map<int, String> childCodes;
  final List<Map<String, dynamic>> users;
  final int? dragIndex;
  final VoidCallback onTap;
  final void Function(LocationModel) onTapChild;
  final VoidCallback onAddChild;
  final VoidCallback? onEditAll;
  final void Function(int oldIndex, int newIndex)? onReorderChildren;

  const _RoomCard({
    required super.key,
    required this.room,
    required this.roomCode,
    required this.children,
    required this.childCodes,
    required this.users,
    required this.dragIndex,
    required this.onTap,
    required this.onTapChild,
    required this.onAddChild,
    this.onEditAll,
    this.onReorderChildren,
  });

  @override
  State<_RoomCard> createState() => _RoomCardState();
}

class _RoomCardState extends State<_RoomCard> {
  bool _expanded = true;

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
        if (_expanded && widget.children.isNotEmpty) ...[
          Divider(height: 1, color: context.appBorder),
          if (widget.onReorderChildren != null)
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              proxyDecorator: (child, _, _) => Material(
                color: Colors.transparent,
                elevation: 4,
                child: child,
              ),
              onReorder: widget.onReorderChildren!,
              children: [
                for (var i = 0; i < widget.children.length; i++)
                  _ChildTile(
                    key: ValueKey('child-${widget.children[i].id}'),
                    loc: widget.children[i],
                    code: widget.childCodes[widget.children[i].id],
                    dragIndex: i,
                    onTap: () => widget.onTapChild(widget.children[i]),
                  ),
              ],
            )
          else
            ...widget.children.map((c) => _ChildTile(
                  loc: c,
                  code: widget.childCodes[c.id],
                  onTap: () => widget.onTapChild(c),
                )),
        ],
        _buildFooter(context),
      ]),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final desc = _stripCodePrefix(widget.room.name);
    final display = desc.isEmpty
        ? widget.roomCode
        : '${widget.roomCode} · $desc';
    return Container(
      decoration: BoxDecoration(
        color: context.appSurface2,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
      child: Row(children: [
        if (widget.dragIndex != null) ...[
          ReorderableDragStartListener(
            index: widget.dragIndex!,
            child: MouseRegion(
              cursor: SystemMouseCursors.grab,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Icon(Icons.drag_indicator,
                    size: 18, color: context.appTextMuted),
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
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
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                display,
                style: GoogleFonts.spaceGrotesk(
                    color: context.appTextPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600),
              ),
              if (widget.room.temperature != null ||
                  widget.room.capacity != null)
                Row(children: [
                  if (widget.room.temperature != null) ...[
                    Icon(Icons.thermostat_outlined,
                        size: 11, color: context.appTextMuted),
                    const SizedBox(width: 2),
                    Text(widget.room.temperature!,
                        style: GoogleFonts.spaceGrotesk(
                            color: context.appTextMuted, fontSize: 11)),
                    const SizedBox(width: 8),
                  ],
                  if (widget.room.capacity != null) ...[
                    Icon(Icons.storage_outlined,
                        size: 11, color: context.appTextMuted),
                    const SizedBox(width: 2),
                    Text('Cap: ${widget.room.capacity}',
                        style: GoogleFonts.spaceGrotesk(
                            color: context.appTextMuted, fontSize: 11)),
                  ],
                ]),
            ],
          ),
        ),
        if (widget.children.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: _roomAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('${widget.children.length}',
                style: GoogleFonts.spaceGrotesk(
                    color: _roomAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
        ],
        if (widget.room.responsible != null &&
            widget.room.responsible!.trim().isNotEmpty) ...[
          Flexible(
            child: Align(
              alignment: Alignment.centerRight,
              child: DetailResponsibleChips(
                  raw: widget.room.responsible, users: widget.users),
            ),
          ),
          const SizedBox(width: 8),
        ],
        if (widget.onEditAll != null && widget.children.isNotEmpty) ...[
          OutlinedButton.icon(
            onPressed: widget.onEditAll,
            icon: const Icon(Icons.edit_note_rounded, size: 14),
            label: const Text('Edit All'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _roomAccent,
              side: BorderSide(color: _roomAccent.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: const Size(0, 28),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6)),
              textStyle: GoogleFonts.spaceGrotesk(fontSize: 12),
            ),
          ),
          const SizedBox(width: 4),
        ],
        OutlinedButton(
          onPressed: widget.onTap,
          style: OutlinedButton.styleFrom(
            foregroundColor: _roomAccent,
            side: BorderSide(color: _roomAccent.withValues(alpha: 0.5)),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            minimumSize: const Size(0, 28),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            textStyle: GoogleFonts.spaceGrotesk(fontSize: 12),
          ),
          child: const Text('View More'),
        ),
        if (widget.children.isNotEmpty) ...[
          const SizedBox(width: 4),
          IconButton(
            icon: Icon(
              _expanded ? Icons.expand_less : Icons.expand_more,
              size: 18,
              color: context.appTextSecondary,
            ),
            onPressed: () => setState(() => _expanded = !_expanded),
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
          ),
        ],
      ]),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onAddChild,
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
            Text('Add location',
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
  final String? code;
  final VoidCallback onTap;
  final int? dragIndex;

  const _ChildTile({
    super.key,
    required this.loc,
    required this.onTap,
    this.code,
    this.dragIndex,
  });

  @override
  Widget build(BuildContext context) {
    final accent = LocationModel.typeAccent(loc.type);
    final desc = _stripCodePrefix(loc.name);
    final display = code == null
        ? (desc.isEmpty ? '—' : desc)
        : (desc.isEmpty ? code! : '$code · $desc');
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(
                  color: context.appBorder.withValues(alpha: 0.5))),
        ),
        child: Row(children: [
          if (dragIndex != null)
            ReorderableDragStartListener(
              index: dragIndex!,
              child: MouseRegion(
                cursor: SystemMouseCursors.grab,
                child: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(Icons.drag_indicator,
                      size: 16, color: context.appTextMuted),
                ),
              ),
            )
          else
            const SizedBox(width: 20),
          Icon(LocationModel.typeIcon(loc.type), color: accent, size: 15),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  display,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.spaceGrotesk(
                      color: context.appTextPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500),
                ),
                if (loc.temperature != null)
                  Text(loc.temperature!,
                      style: GoogleFonts.spaceGrotesk(
                          color: context.appTextMuted, fontSize: 11)),
              ],
            ),
          ),
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              foregroundColor: AppDS.accent,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 28),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: GoogleFonts.spaceGrotesk(fontSize: 12),
            ),
            child: const Text('View More'),
          ),
        ]),
      ),
    );
  }
}

// ─── Orphan Card ────────────────────────────────────────────────────────────────
class _OrphanCard extends StatelessWidget {
  final List<LocationModel> locations;
  final void Function(LocationModel) onTap;
  final VoidCallback onAdd;

  const _OrphanCard({
    required super.key,
    required this.locations,
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
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            Icon(Icons.inbox_outlined, color: context.appTextMuted, size: 16),
            const SizedBox(width: 8),
            Text('Locations Without Room',
                style: GoogleFonts.spaceGrotesk(
                    color: context.appTextSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
            const Spacer(),
            Text(
                '${locations.length} location${locations.length == 1 ? '' : 's'} need a room',
                style: GoogleFonts.spaceGrotesk(
                    color: context.appTextMuted, fontSize: 11)),
          ]),
        ),
        Divider(height: 1, color: context.appBorder),
        ...locations.map((l) => _ChildTile(
              loc: l,
              onTap: () => onTap(l),
            )),
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
                Text('Add location',
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

// ─── Add Dialog ─────────────────────────────────────────────────────────────────

class _QuickAddLocationDialog extends StatefulWidget {
  final List<LocationModel> rooms;
  final Map<int, List<LocationModel>> childMap;
  final int? defaultParentId;
  final String defaultKind;

  const _QuickAddLocationDialog({
    required this.rooms,
    required this.childMap,
    this.defaultParentId,
    this.defaultKind = LocationModel.roomType,
  });

  @override
  State<_QuickAddLocationDialog> createState() => _QuickAddLocationDialogState();
}

class _QuickAddLocationDialogState extends State<_QuickAddLocationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _countCtrl = TextEditingController(text: '1');
  final _descCtrl = TextEditingController();
  final Map<int, TextEditingController> _rangeDescCtrls = {};
  late String _kind;
  late int? _parentId;
  // Saved as location_type when _kind == genericLocationType. Defaults to
  // "cabinet" (first item under the Furniture group).
  String _subType = 'cabinet';
  bool _saving = false;

  TextEditingController _rangeDescCtrl(int slot) =>
      _rangeDescCtrls.putIfAbsent(slot, TextEditingController.new);

  int get _count {
    final n = int.tryParse(_countCtrl.text.trim());
    if (n == null || n < 1) return 1;
    return n.clamp(1, 50);
  }

  LocationModel? get _selectedRoom {
    final id = _parentId;
    if (id == null) return null;
    for (final room in widget.rooms) {
      if (room.id == id) return room;
    }
    return null;
  }

  int get _nextRoomIndex => widget.rooms.length;
  int _nextChildIndex(LocationModel room) =>
      (widget.childMap[room.id] ?? const []).length;

  String get _nextRoomCode => roomCode(_nextRoomIndex);
  String _nextChildCode(LocationModel room, int slot) {
    final roomIdx = widget.rooms.indexOf(room);
    return childCode(roomIdx, _nextChildIndex(room) + slot);
  }

  @override
  void initState() {
    super.initState();
    _kind = widget.defaultKind == LocationModel.genericLocationType
        ? LocationModel.genericLocationType
        : LocationModel.roomType;
    _parentId = widget.defaultParentId;
    _countCtrl.addListener(() {
      if (mounted) setState(() {});
    });
    _descCtrl.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _countCtrl.dispose();
    _descCtrl.dispose();
    for (final c in _rangeDescCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_kind == LocationModel.genericLocationType && _selectedRoom == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Select a parent room.')));
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final client = Supabase.instance.client;
      if (_kind == LocationModel.roomType) {
        final row = await client
            .from('storage_locations')
            .insert({
              'location_name': _descCtrl.text.trim(),
              'location_type': LocationModel.roomType,
              'location_sort_order': _nextRoomIndex + 1,
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
      } else {
        final room = _selectedRoom!;
        final baseIndex = _nextChildIndex(room);
        final count = _count;
        for (var slot = 0; slot < count; slot++) {
          final desc = (count == 1
                  ? _descCtrl.text
                  : (_rangeDescCtrls[slot]?.text ?? ''))
              .trim();
          final row = await client
              .from('storage_locations')
              .insert({
                'location_name': desc,
                'location_type': _subType,
                'location_parent_id': room.id,
                'location_sort_order': baseIndex + slot + 1,
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
        }
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to save: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final room = _selectedRoom;
    final count = _count;

    return AlertDialog(
      backgroundColor: context.appSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(
        'Add Room or Location',
        style: GoogleFonts.spaceGrotesk(
          color: context.appTextPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DarkDropdown<String>(
                  label: 'Type',
                  value: _kind,
                  items: const [
                    DropdownMenuItem(
                      value: LocationModel.roomType,
                      child: Text('Room'),
                    ),
                    DropdownMenuItem(
                      value: LocationModel.genericLocationType,
                      child: Text('Location'),
                    ),
                  ],
                  onChanged: (value) => setState(() {
                    _kind = value ?? LocationModel.roomType;
                  }),
                ),
                const SizedBox(height: 12),
                if (_kind == LocationModel.roomType) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.appSurface2,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: context.appBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Next room code',
                          style: GoogleFonts.spaceGrotesk(
                            color: context.appTextMuted,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _nextRoomCode,
                          style: GoogleFonts.jetBrainsMono(
                            color: context.appTextPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _DarkField(
                    controller: _descCtrl,
                    label: 'Description (e.g. Microscopy) *',
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                ] else ...[
                  _DarkDropdown<String>(
                    label: 'Subcategory',
                    value: _subType,
                    items: [
                      for (final group
                          in LocationModel.locationSubtypeGroups) ...[
                        DropdownMenuItem<String>(
                          // Picking the header is a no-op: enabled=false makes
                          // it visually distinct and unselectable, so the
                          // current `_subType` selection is preserved.
                          enabled: false,
                          value: '__header_${group.$1}',
                          child: Padding(
                            padding: const EdgeInsets.only(top: 4, bottom: 2),
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
                        ),
                        for (final t in group.$2)
                          DropdownMenuItem<String>(
                            value: t,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Text(
                                LocationModel.typeLabel(t),
                                style: GoogleFonts.spaceGrotesk(
                                  color: context.appTextPrimary,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ],
                    onChanged: _saving
                        ? (_) {}
                        : (value) {
                            // Headers are disabled, but guard anyway so a
                            // synthesized header value never leaks into state.
                            if (value == null ||
                                value.startsWith('__header_')) {
                              return;
                            }
                            setState(() => _subType = value);
                          },
                  ),
                  const SizedBox(height: 12),
                  _DarkDropdown<int?>(
                    label: 'Parent Room',
                    value: _parentId,
                    items: [
                      DropdownMenuItem<int?>(
                        value: null,
                        child: Text(
                          widget.rooms.isEmpty
                              ? 'No rooms available'
                              : 'Select room',
                          style: GoogleFonts.spaceGrotesk(
                            color: context.appTextMuted,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      ...widget.rooms.asMap().entries.map(
                            (entry) => DropdownMenuItem<int?>(
                              value: entry.value.id,
                              child: Text(
                                '${roomCode(entry.key)} · ${_stripCodePrefix(entry.value.name)}',
                                style: GoogleFonts.spaceGrotesk(
                                  color: context.appTextPrimary,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                    ],
                    onChanged: _saving
                        ? (_) {}
                        : (value) => setState(() => _parentId = value),
                  ),
                  const SizedBox(height: 12),
                  _DarkField(
                    controller: _countCtrl,
                    label: 'How many? (1-50)',
                    validator: (v) {
                      final n = int.tryParse((v ?? '').trim());
                      if (n == null || n < 1 || n > 50) {
                        return 'Enter a number between 1 and 50';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  if (count <= 1 && room != null)
                    _DarkField(
                      controller: _descCtrl,
                      label:
                          'Description for ${_nextChildCode(room, 0)} (e.g. Cabinet) *',
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    )
                  else if (count <= 1)
                    _DarkField(
                      controller: _descCtrl,
                      label: 'Description *',
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    )
                  else if (room != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Descriptions *',
                          style: GoogleFonts.spaceGrotesk(
                            color: context.appTextSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (var slot = 0; slot < count; slot++) ...[
                          Row(children: [
                            SizedBox(
                              width: 72,
                              child: Text(
                                _nextChildCode(room, slot),
                                style: GoogleFonts.jetBrainsMono(
                                  color: context.appTextSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Expanded(
                              child: _DarkField(
                                controller: _rangeDescCtrl(slot),
                                label: 'Description',
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                        ? 'Required'
                                        : null,
                              ),
                            ),
                          ]),
                          const SizedBox(height: 8),
                        ],
                      ],
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: Text(
            'Cancel',
            style: GoogleFonts.spaceGrotesk(color: context.appTextSecondary),
          ),
        ),
        FilledButton(
          onPressed: _saving ||
                  (_kind == LocationModel.genericLocationType &&
                      widget.rooms.isEmpty)
              ? null
              : _save,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF6366F1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('Create', style: GoogleFonts.spaceGrotesk()),
        ),
      ],
    );
  }
}


// ─── Shared dark form widgets ────────────────────────────────────────────────────
class _DarkField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;

  const _DarkField({
    required this.controller,
    required this.label,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
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

// ─── Edit Children Dialog ───────────────────────────────────────────────────────
// Bulk-edit all sub-locations of a single room: rename, change subcategory,
// reorder. Used by the "Edit All" button on _RoomCard. Save commits every
// change (name + type + sort_order) in one batch and pops `true` so the page
// can reload.
class _EditChildrenDialog extends StatefulWidget {
  final LocationModel room;
  final String roomCode;
  // 0-based room index — used to derive child codes "L{roomIndex+1}.{n}".
  final int roomIndex;
  final List<LocationModel> children;

  const _EditChildrenDialog({
    required this.room,
    required this.roomCode,
    required this.roomIndex,
    required this.children,
  });

  @override
  State<_EditChildrenDialog> createState() => _EditChildrenDialogState();
}

class _EditChildEntry {
  final int id;
  final String originalName;
  final String originalType;
  final int? originalSortOrder;
  final TextEditingController nameCtrl;
  String type;

  _EditChildEntry({
    required this.id,
    required this.originalName,
    required this.originalType,
    required this.originalSortOrder,
    required this.nameCtrl,
    required this.type,
  });
}

class _EditChildrenDialogState extends State<_EditChildrenDialog> {
  late List<_EditChildEntry> _entries;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _entries = widget.children
        .map((c) => _EditChildEntry(
              id: c.id,
              originalName: c.name,
              originalType: c.type,
              originalSortOrder: c.sortOrder,
              nameCtrl: TextEditingController(text: _stripCodePrefix(c.name)),
              type: LocationModel.locationTypeOptions.contains(c.type)
                  ? c.type
                  : (c.type == LocationModel.genericLocationType
                      ? 'cabinet'
                      : c.type),
            ))
        .toList();
  }

  @override
  void dispose() {
    for (final e in _entries) {
      e.nameCtrl.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final client = Supabase.instance.client;
    final failures = <String>[];
    try {
      for (var i = 0; i < _entries.length; i++) {
        final e = _entries[i];
        final newName = e.nameCtrl.text.trim();
        if (newName.isEmpty) {
          failures.add('Row ${i + 1}: name is required');
          continue;
        }
        final newSort = i + 1;
        final patch = <String, dynamic>{};
        if (newName != _stripCodePrefix(e.originalName)) {
          patch['location_name'] = newName;
        }
        if (e.type != e.originalType) {
          patch['location_type'] = e.type;
        }
        if (e.originalSortOrder != newSort) {
          patch['location_sort_order'] = newSort;
        }
        if (patch.isEmpty) continue;
        try {
          await client
              .from('storage_locations')
              .update(patch)
              .eq('location_id', e.id);
        } catch (err) {
          debugPrint('edit-all save row ${e.id} failed: $err');
          failures.add('${e.nameCtrl.text}: $err');
        }
      }
      if (!mounted) return;
      if (failures.isEmpty) {
        Navigator.pop(context, true);
      } else {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            'Saved with ${failures.length} error(s):\n'
            '${failures.take(3).join('\n')}',
            style: GoogleFonts.spaceGrotesk(color: Colors.white),
          ),
          backgroundColor: AppDS.red,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Save failed: $e')));
    }
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final moved = _entries.removeAt(oldIndex);
      _entries.insert(newIndex, moved);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.appSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Row(children: [
        Icon(Icons.edit_note_rounded, size: 18, color: AppDS.accent),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Edit locations · ${widget.roomCode}',
            style: GoogleFonts.spaceGrotesk(
                color: context.appTextPrimary, fontWeight: FontWeight.w600),
          ),
        ),
      ]),
      content: SizedBox(
        width: 560,
        height: 480,
        child: _entries.isEmpty
            ? Center(
                child: Text('This room has no sub-locations.',
                    style: GoogleFonts.spaceGrotesk(
                        color: context.appTextMuted, fontSize: 13)),
              )
            : Column(children: [
                // ── Header bar ─────────────────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: context.appHeaderBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 6),
                  child: Row(children: [
                    const SizedBox(width: 26),
                    SizedBox(
                      width: 60,
                      child: Text('CODE',
                          style: GoogleFonts.spaceGrotesk(
                              color: context.appHeaderText,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8)),
                    ),
                    const SizedBox(width: 22),
                    Expanded(
                      flex: 3,
                      child: Text('NAME',
                          style: GoogleFonts.spaceGrotesk(
                              color: context.appHeaderText,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: Text('TYPE',
                          style: GoogleFonts.spaceGrotesk(
                              color: context.appHeaderText,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8)),
                    ),
                  ]),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: ReorderableListView.builder(
                    buildDefaultDragHandles: false,
                    itemCount: _entries.length,
                    onReorder: _reorder,
                    proxyDecorator: (child, _, _) => Material(
                      color: Colors.transparent,
                      elevation: 4,
                      child: child,
                    ),
                    itemBuilder: (ctx, i) {
                      final e = _entries[i];
                      final accent = LocationModel.typeAccent(e.type);
                      return Padding(
                        key: ValueKey('edit-child-${e.id}'),
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(children: [
                          ReorderableDragStartListener(
                            index: i,
                            child: MouseRegion(
                              cursor: SystemMouseCursors.grab,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4),
                                child: Icon(Icons.drag_indicator,
                                    size: 18, color: ctx.appTextMuted),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 60,
                            child: Text(
                              childCode(widget.roomIndex, i),
                              style: GoogleFonts.jetBrainsMono(
                                  color: ctx.appTextMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                          Container(
                            width: 22,
                            height: 22,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Icon(LocationModel.typeIcon(e.type),
                                color: accent, size: 13),
                          ),
                          Expanded(
                            flex: 3,
                            child: TextField(
                          controller: e.nameCtrl,
                          enabled: !_saving,
                          style: GoogleFonts.spaceGrotesk(
                              color: ctx.appTextPrimary, fontSize: 13),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'Name',
                            hintStyle: GoogleFonts.spaceGrotesk(
                                color: ctx.appTextMuted, fontSize: 12),
                            filled: true,
                            fillColor: ctx.appSurface3,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide:
                                    BorderSide(color: ctx.appBorder)),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide:
                                    BorderSide(color: ctx.appBorder)),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide:
                                    const BorderSide(color: AppDS.accent)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: ctx.appSurface3,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: ctx.appBorder),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: e.type,
                                isExpanded: true,
                                isDense: true,
                                dropdownColor: ctx.appSurface,
                                style: GoogleFonts.spaceGrotesk(
                                    color: ctx.appTextPrimary, fontSize: 12),
                                onChanged: _saving
                                    ? null
                                    : (v) {
                                        if (v == null ||
                                            v.startsWith('__header_')) {
                                          return;
                                        }
                                        setState(() => e.type = v);
                                      },
                                items: [
                                  for (final group
                                      in LocationModel.locationSubtypeGroups) ...[
                                    DropdownMenuItem<String>(
                                      enabled: false,
                                      value: '__header_${group.$1}',
                                      child: Text(
                                        group.$1.toUpperCase(),
                                        style: GoogleFonts.spaceGrotesk(
                                            color: ctx.appTextMuted,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.8),
                                      ),
                                    ),
                                    for (final t in group.$2)
                                      DropdownMenuItem<String>(
                                        value: t,
                                        child: Padding(
                                          padding:
                                              const EdgeInsets.only(left: 8),
                                          child: Text(
                                              LocationModel.typeLabel(t)),
                                        ),
                                      ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                        ]),
                      );
                    },
                  ),
                ),
              ]),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: Text('Cancel',
              style:
                  GoogleFonts.spaceGrotesk(color: context.appTextSecondary)),
        ),
        FilledButton(
          onPressed: _saving || _entries.isEmpty ? null : _save,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF6366F1),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('Save', style: GoogleFonts.spaceGrotesk()),
        ),
      ],
    );
  }
}
