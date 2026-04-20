// location_detail_page.dart - Location detail editor (non-room).
// Fields: name, type, parent room, temperature, capacity, notes.
// Pushed via Navigator with its own Scaffold + AppBar.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide LocalStorage;
import '/theme/theme.dart';
import 'detail_widgets.dart';
import 'location_model.dart';

class LocationDetailPage extends StatefulWidget {
  final int locationId;
  const LocationDetailPage({super.key, required this.locationId});

  @override
  State<LocationDetailPage> createState() => _LocationDetailPageState();
}

class _LocationDetailPageState extends State<LocationDetailPage> {
  LocationModel? _loc;
  List<LocationModel> _rooms = [];
  List<Map<String, dynamic>> _reagents = [];
  String? _displayCode;
  bool _loading = true;
  bool _saving = false;
  final Set<int> _expanded = {0, 1, 2};

  late final TextEditingController _nameCtrl;
  late final TextEditingController _tempCtrl;
  late final TextEditingController _capCtrl;
  late final TextEditingController _notesCtrl;
  String _type = LocationModel.defaultLocationType;
  int? _parentId;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _tempCtrl = TextEditingController();
    _capCtrl  = TextEditingController();
    _notesCtrl = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _tempCtrl.dispose();
    _capCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await Supabase.instance.client
          .from('storage_locations')
          .select('*, parent:location_parent_id(location_name)')
          .eq('location_id', widget.locationId)
          .limit(1);

      if (rows.isEmpty) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final r = rows[0];
      final p = r['parent'];
      final loc = LocationModel.fromMap({
        ...r,
        'parent_name': p is Map ? p['location_name'] as String? : null,
      });

      final allRows = await Supabase.instance.client
          .from('storage_locations')
          .select(
              'location_id, location_name, location_type, location_parent_id, location_sort_order')
          .eq('location_type', LocationModel.roomType);
      final rooms = allRows
          .map<LocationModel>((c) => LocationModel.fromMap(c))
          .toList()
        ..sort(_bySortThenName);

      String? code;
      if (loc.parentId != null) {
        final roomIdx =
            rooms.indexWhere((r) => r.id == loc.parentId);
        if (roomIdx >= 0) {
          final siblingRows = await Supabase.instance.client
              .from('storage_locations')
              .select('location_id, location_name, location_sort_order')
              .eq('location_parent_id', loc.parentId!);
          final siblings = siblingRows
              .map<LocationModel>((c) => LocationModel.fromMap(c))
              .toList()
            ..sort(_bySortThenName);
          final childIdx = siblings.indexWhere((s) => s.id == loc.id);
          if (childIdx >= 0) {
            code = 'L${roomIdx + 1}.${childIdx + 1}';
          }
        }
      }

      List<dynamic> reagentRows = [];
      try {
        reagentRows = await Supabase.instance.client
            .from('reagents')
            .select(
                'reagent_id, reagent_name, reagent_package_size, reagent_container_count, reagent_unit, reagent_expiry_date')
            .eq('reagent_location_id', widget.locationId)
            .order('reagent_name');
      } catch (e) {
        debugPrint('location_detail: reagents lookup failed: $e');
      }

      if (mounted) {
        _nameCtrl.text  = stripLocationCodePrefix(loc.name);
        _tempCtrl.text  = loc.temperature ?? '';
        _capCtrl.text   = loc.capacity?.toString() ?? '';
        _notesCtrl.text = loc.notes ?? '';
        _type = loc.isRoom ? LocationModel.defaultLocationType : loc.type;
        final roomIds = {for (final r in rooms) r.id};
        _parentId = roomIds.contains(loc.parentId) ? loc.parentId : null;

        setState(() {
          _loc         = loc;
          _rooms       = rooms;
          _reagents    = List<Map<String, dynamic>>.from(reagentRows);
          _displayCode = code;
          _loading     = false;
        });
      }
    } catch (e) {
      debugPrint('location_detail: load failed: $e');
      if (mounted) {
        setState(() => _loading = false);
        detailSnack(context, 'Failed to load: $e');
      }
    }
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
        'location_type': _type,
        'location_temperature':
            _tempCtrl.text.trim().isEmpty ? null : _tempCtrl.text.trim(),
        'location_capacity': _capCtrl.text.trim().isEmpty
            ? null
            : int.tryParse(_capCtrl.text.trim()),
        'location_responsible': null,
        'location_notes':
            _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        'location_parent_id': _parentId,
      };
      await Supabase.instance.client
          .from('storage_locations')
          .update(data)
          .eq('location_id', widget.locationId);
      await _load();
      if (mounted) detailSnack(context, 'Saved');
    } catch (e) {
      debugPrint('location_detail: save failed: $e');
      if (mounted) detailSnack(context, 'Save failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
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

  Future<void> _delete() async {
    final name = _loc?.name ?? 'this location';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.appSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Delete Location?',
            style: GoogleFonts.spaceGrotesk(
                color: ctx.appTextPrimary, fontWeight: FontWeight.w600)),
        content: Text(
          'This will permanently delete "$name". This cannot be undone.',
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
        debugPrint('location_detail: unlink $table.$column failed: $e');
      }
    }
    try {
      await client
          .from('storage_locations')
          .delete()
          .eq('location_id', widget.locationId);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      debugPrint('location_detail: delete failed: $e');
      if (mounted) detailSnack(context, 'Delete failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = _loc;
    final accent = loc != null ? LocationModel.typeAccent(loc.type) : AppDS.accent;

    return Scaffold(
      backgroundColor: context.appBg,
      appBar: AppBar(
        backgroundColor: context.appSurface2,
        foregroundColor: context.appTextPrimary,
        elevation: 0,
        title: Text(
          loc == null
              ? 'Location'
              : (_displayCode == null
                  ? stripLocationCodePrefix(loc.name)
                  : '${_displayCode!} · ${stripLocationCodePrefix(loc.name)}'),
          style: GoogleFonts.spaceGrotesk(
              color: context.appTextPrimary, fontWeight: FontWeight.w600),
        ),
        actions: [
          if (loc != null) ...[
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20, color: AppDS.red),
              tooltip: 'Delete',
              onPressed: _delete,
            ),
            _saving
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white)))
                : TextButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save_outlined,
                        size: 16, color: AppDS.accent),
                    label: Text('Save',
                        style:
                            GoogleFonts.spaceGrotesk(color: AppDS.accent)),
                  ),
          ],
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : loc == null
              ? Center(
                  child: Text('Location not found',
                      style: GoogleFonts.spaceGrotesk(color: context.appTextMuted)))
              : _buildBody(context, loc, accent),
    );
  }

  Widget _buildBody(BuildContext context, LocationModel loc, Color accent) {
    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _buildHeader(context, loc, accent),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            DetailSection(
              title: 'LOCATION DETAILS',
              icon: Icons.info_outline,
              expanded: _expanded.contains(0),
              onToggle: () => setState(() {
                _expanded.contains(0)
                    ? _expanded.remove(0)
                    : _expanded.add(0);
              }),
              child: _buildDetailsSection(context, loc),
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
                  label: 'Notes', controller: _notesCtrl, maxLines: 4),
            ),
            DetailSection(
              title: 'REAGENTS STORED HERE (${_reagents.length})',
              icon: Icons.science_outlined,
              expanded: _expanded.contains(2),
              onToggle: () => setState(() {
                _expanded.contains(2)
                    ? _expanded.remove(2)
                    : _expanded.add(2);
              }),
              child: _buildReagentsSection(context),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildHeader(BuildContext context, LocationModel loc, Color accent) {
    return Container(
      color: context.appSurface2,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (loc.parentName != null)
          Text('${loc.parentName} ›',
              style: GoogleFonts.spaceGrotesk(
                  color: context.appTextMuted, fontSize: 12)),
        if (_displayCode != null)
          Text(_displayCode!,
              style: GoogleFonts.jetBrainsMono(
                  color: context.appTextMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
        Text(stripLocationCodePrefix(loc.name),
            style: GoogleFonts.spaceGrotesk(
                color: context.appTextPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Row(children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(LocationModel.typeIcon(loc.type), color: accent, size: 13),
              const SizedBox(width: 5),
              Text(LocationModel.typeLabel(loc.type),
                  style: GoogleFonts.spaceGrotesk(
                      color: accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
      ]),
    );
  }

  Widget _buildDetailsSection(BuildContext context, LocationModel loc) {
    final parentChoices = _rooms.where((l) => l.id != loc.id).toList();
    final selectedParentId =
        parentChoices.any((room) => room.id == _parentId) ? _parentId : null;
    final typeOptions = LocationModel.locationTypeOptions;
    final typeValue = typeOptions.contains(_type)
        ? _type
        : LocationModel.defaultLocationType;

    return Column(children: [
      DetailFieldRow(children: [
        DetailInlineField(label: 'Name', controller: _nameCtrl),
        DetailInlineDropdown<String>(
          label: 'Type',
          value: typeValue,
          items: typeOptions
              .map((t) => DropdownMenuItem(
                    value: t,
                    child: Text(LocationModel.typeLabel(t),
                        style: GoogleFonts.spaceGrotesk(
                            color: context.appTextPrimary, fontSize: 13)),
                  ))
              .toList(),
          onChanged: (v) =>
              setState(() => _type = v ?? LocationModel.defaultLocationType),
        ),
      ]),
      const SizedBox(height: 10),
      DetailFieldRow(children: [
        DetailInlineField(label: 'Temperature', controller: _tempCtrl),
        DetailInlineField(
            label: 'Capacity',
            controller: _capCtrl,
            keyboardType: TextInputType.number),
      ]),
      const SizedBox(height: 10),
      DetailFieldRow(children: [
        DetailInlineDropdown<int?>(
          label: 'Parent Room',
          value: selectedParentId,
          items: [
            DropdownMenuItem<int?>(
              value: null,
              child: Text('None',
                  style: GoogleFonts.spaceGrotesk(
                      color: context.appTextMuted, fontSize: 13)),
            ),
            ...parentChoices.map((l) => DropdownMenuItem<int?>(
                  value: l.id,
                  child: Text(stripLocationCodePrefix(l.name),
                      style: GoogleFonts.spaceGrotesk(
                          color: context.appTextPrimary, fontSize: 13)),
                )),
          ],
          onChanged: (v) => setState(() => _parentId = v),
        ),
      ]),
      if (loc.createdAt != null) ...[
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Created ${detailFmtDate(loc.createdAt!)}',
            style:
                GoogleFonts.spaceGrotesk(color: context.appTextMuted, fontSize: 11),
          ),
        ),
      ],
    ]);
  }

  Widget _buildReagentsSection(BuildContext context) {
    if (_reagents.isEmpty) {
      return Text('No reagents assigned to this location.',
          style:
              GoogleFonts.spaceGrotesk(color: context.appTextMuted, fontSize: 13));
    }
    return Column(
      children: _reagents.map((r) {
        final name   = r['reagent_name'] as String? ?? '';
        final packSize = r['reagent_package_size'] as num?;
        final count  = r['reagent_container_count'] as int?;
        final unit   = r['reagent_unit'] as String? ?? '';
        final expiry = r['reagent_expiry_date'] != null
            ? DateTime.tryParse(r['reagent_expiry_date'].toString())
            : null;
        final expired = expiry != null && expiry.isBefore(DateTime.now());

        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: context.appSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: context.appBorder),
          ),
          child: Row(children: [
            Expanded(
              child: Text(name,
                  style: GoogleFonts.spaceGrotesk(
                      color: context.appTextPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
            ),
            if (count != null && packSize != null)
              Text(
                '$count × ${packSize.toStringAsFixed((packSize % 1 == 0) ? 0 : 2)} $unit',
                style: GoogleFonts.spaceGrotesk(
                    color: context.appTextSecondary, fontSize: 12),
              )
            else if (count != null)
              Text('$count containers',
                  style: GoogleFonts.spaceGrotesk(
                      color: context.appTextSecondary, fontSize: 12)),
            if (expiry != null) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (expired ? AppDS.red : AppDS.yellow)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  expired ? 'Expired' : 'Exp ${detailFmtDate(expiry)}',
                  style: GoogleFonts.spaceGrotesk(
                      color: expired ? AppDS.red : AppDS.yellow,
                      fontSize: 10),
                ),
              ),
            ],
          ]),
        );
      }).toList(),
    );
  }
}
