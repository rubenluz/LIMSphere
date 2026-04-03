// locations_widgets.dart - Part of locations_page.dart.
// _RoomCard: expandable list card for a top-level room.
// _ChildTile: sub-location row inside a room card.
// _OrphanCard: card for locations with no parent.
// _LocationFormDialog: add/edit location form dialog.
// _DarkField, _DarkDropdown: dark-themed form field helpers.
part of 'locations_page.dart';

// ─── Room Card ──────────────────────────────────────────────────────────────────
class _RoomCard extends StatefulWidget {
  final LocationModel room;
  final List<LocationModel> children;
  final VoidCallback onTap;
  final void Function(LocationModel) onTapChild;
  final VoidCallback onAddChild;

  const _RoomCard({
    required super.key,
    required this.room,
    required this.children,
    required this.onTap,
    required this.onTapChild,
    required this.onAddChild,
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
          ...widget.children.map((c) => _ChildTile(
                loc: c,
                onTap: () => widget.onTapChild(c),
              )),
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
      padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
      child: Row(children: [
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
              Text(widget.room.name,
                  style: GoogleFonts.spaceGrotesk(
                      color: context.appTextPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
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
  final VoidCallback onTap;

  const _ChildTile({
    required this.loc,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = LocationModel.typeAccent(loc.type);
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
          const SizedBox(width: 20),
          Icon(LocationModel.typeIcon(loc.type), color: accent, size: 15),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
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
        final row = await Supabase.instance.client
            .from('storage_locations')
            .insert(data)
            .select('location_id')
            .single();
        final newId = row['location_id'] as int;
        await Supabase.instance.client
            .from('storage_locations')
            .update({'location_qrcode': QrRules.build(
                SupabaseManager.projectRef ?? 'local', 'locations', newId)})
            .eq('location_id', newId);
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
