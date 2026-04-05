// location_detail_page.dart - Location/room detail editor: name, parent room,
// storage capacity, description, QR code generation.
// Pushed via Navigator with its own Scaffold + AppBar.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide LocalStorage;
import '../supabase/supabase_manager.dart';
import '/theme/theme.dart';
import 'location_model.dart';

// ─── Page ─────────────────────────────────────────────────────────────────────
class LocationDetailPage extends StatefulWidget {
  final int locationId;
  const LocationDetailPage({super.key, required this.locationId});

  @override
  State<LocationDetailPage> createState() => _LocationDetailPageState();
}

class _LocationDetailPageState extends State<LocationDetailPage> {
  LocationModel? _loc;
  List<LocationModel> _children = [];
  List<LocationModel> _allLocations = [];
  List<Map<String, dynamic>> _reagents = [];
  bool _loading = true;
  bool _saving = false;
  final Set<int> _expanded = {0, 1, 2, 3};

  // Inline edit controllers
  late final TextEditingController _nameCtrl;
  late final TextEditingController _tempCtrl;
  late final TextEditingController _capCtrl;
  late final TextEditingController _responsibleCtrl;
  late final TextEditingController _notesCtrl;
  String _type = 'room';
  int? _parentId;

  @override
  void initState() {
    super.initState();
    _nameCtrl        = TextEditingController();
    _tempCtrl        = TextEditingController();
    _capCtrl         = TextEditingController();
    _responsibleCtrl = TextEditingController();
    _notesCtrl       = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _tempCtrl.dispose();
    _capCtrl.dispose();
    _responsibleCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  // ── Data ───────────────────────────────────────────────────────────────────

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

      // Children of this location
      final childRows = await Supabase.instance.client
          .from('storage_locations')
          .select()
          .eq('location_parent_id', widget.locationId)
          .order('location_name');
      final children =
          childRows.map<LocationModel>((c) => LocationModel.fromMap(c)).toList();

      // All locations for parent picker
      final allRows = await Supabase.instance.client
          .from('storage_locations')
          .select('location_id, location_name, location_type, location_parent_id')
          .order('location_name');
      final allLocations =
          allRows.map<LocationModel>((c) => LocationModel.fromMap(c)).toList();

      // Reagents stored here
      final reagentRows = await Supabase.instance.client
          .from('reagents')
          .select(
              'reagent_id, reagent_name, reagent_type, reagent_quantity, reagent_unit, reagent_expiry_date')
          .eq('reagent_location_id', widget.locationId)
          .order('reagent_name');

      if (mounted) {
        // Populate controllers
        _nameCtrl.text        = loc.name;
        _tempCtrl.text        = loc.temperature ?? '';
        _capCtrl.text         = loc.capacity?.toString() ?? '';
        _responsibleCtrl.text = loc.responsible ?? '';
        _notesCtrl.text       = loc.notes ?? '';
        _type     = loc.type;
        _parentId = loc.parentId;

        setState(() {
          _loc          = loc;
          _children     = children;
          _allLocations = allLocations;
          _reagents     = List<Map<String, dynamic>>.from(reagentRows);
          _loading      = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _snack('Failed to load: $e');
      }
    }
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      _snack('Name is required');
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
        'location_responsible': _responsibleCtrl.text.trim().isEmpty
            ? null
            : _responsibleCtrl.text.trim(),
        'location_notes':
            _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        'location_parent_id': _parentId,
      };
      await Supabase.instance.client
          .from('storage_locations')
          .update(data)
          .eq('location_id', widget.locationId);
      await _load();
      _snack('Saved');
    } catch (e) {
      _snack('Save failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppDS.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  // ── Build ──────────────────────────────────────────────────────────────────

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
          loc?.name ?? 'Location',
          style: GoogleFonts.spaceGrotesk(
              color: context.appTextPrimary, fontWeight: FontWeight.w600),
        ),
        actions: [
          if (loc != null) ...[
            // QR copy
            IconButton(
              icon: const Icon(Icons.qr_code, size: 20),
              tooltip: 'QR Code',
              onPressed: () => _showQr(loc),
            ),
            // Save
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
    final qrData =
        'bluelims://${SupabaseManager.projectRef ?? 'local'}/locations/${loc.id}';

    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // ── Header ────────────────────────────────────────────────────────────
        _buildHeader(context, loc, accent, qrData),

        // ── Sections ──────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            _Section(
              index: 0,
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
            _Section(
              index: 1,
              title: 'NOTES',
              icon: Icons.notes_rounded,
              expanded: _expanded.contains(1),
              onToggle: () => setState(() {
                _expanded.contains(1)
                    ? _expanded.remove(1)
                    : _expanded.add(1);
              }),
              child: _buildNotesSection(),
            ),
            if (_children.isNotEmpty)
              _Section(
                index: 2,
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
            _Section(
              index: 3,
              title: 'REAGENTS STORED HERE (${_reagents.length})',
              icon: Icons.science_outlined,
              expanded: _expanded.contains(3),
              onToggle: () => setState(() {
                _expanded.contains(3)
                    ? _expanded.remove(3)
                    : _expanded.add(3);
              }),
              child: _buildReagentsSection(context),
            ),
          ]),
        ),
      ]),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, LocationModel loc, Color accent, String qrData) {
    return Container(
      color: context.appSurface2,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // QR code
        GestureDetector(
          onTap: () => _showQr(loc),
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.all(10),
            child: QrImageView(data: qrData, size: 120),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (loc.parentName != null)
              Text('${loc.parentName} ›',
                  style: GoogleFonts.spaceGrotesk(
                      color: context.appTextMuted, fontSize: 12)),
            Text(loc.name,
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
                  Icon(LocationModel.typeIcon(loc.type),
                      color: accent, size: 13),
                  const SizedBox(width: 5),
                  Text(LocationModel.typeLabel(loc.type),
                      style: GoogleFonts.spaceGrotesk(
                          color: accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ]),
              ),
              if (loc.responsible != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: context.appSurface3,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: context.appBorder),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.person_outline,
                        color: context.appTextMuted, size: 13),
                    const SizedBox(width: 5),
                    Text(loc.responsible!,
                        style: GoogleFonts.spaceGrotesk(
                            color: context.appTextSecondary, fontSize: 12)),
                  ]),
                ),
              ],
            ]),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: qrData));
                _snack('Link copied');
              },
              child: Text(qrData,
                  style: GoogleFonts.jetBrainsMono(
                      color: context.appTextMuted, fontSize: 10)),
            ),
          ]),
        ),
      ]),
    );
  }

  // ── Details section ────────────────────────────────────────────────────────

  Widget _buildDetailsSection(BuildContext context, LocationModel loc) {
    final parentChoices =
        _allLocations.where((l) => l.id != loc.id).toList();

    return Column(children: [
      _FieldRow(children: [
        _InlineField(label: 'Name', controller: _nameCtrl),
        _InlineDropdown<String>(
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
      ]),
      const SizedBox(height: 10),
      _FieldRow(children: [
        _InlineField(label: 'Responsible', controller: _responsibleCtrl),
        _InlineField(label: 'Temperature', controller: _tempCtrl),
      ]),
      const SizedBox(height: 10),
      _FieldRow(children: [
        _InlineField(
            label: 'Capacity',
            controller: _capCtrl,
            keyboardType: TextInputType.number),
        _InlineDropdown<int?>(
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
      ]),
      if (loc.createdAt != null) ...[
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Created ${_fmt(loc.createdAt!)}',
            style:
                GoogleFonts.spaceGrotesk(color: context.appTextMuted, fontSize: 11),
          ),
        ),
      ],
    ]);
  }

  // ── Notes section ──────────────────────────────────────────────────────────

  Widget _buildNotesSection() {
    return _InlineField(label: 'Notes', controller: _notesCtrl, maxLines: 4);
  }

  // ── Children section ───────────────────────────────────────────────────────

  Widget _buildChildrenSection(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _children.map((c) {
        final acc = LocationModel.typeAccent(c.type);
        return InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => LocationDetailPage(locationId: c.id)),
          ),
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
                  Text(c.name,
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

  // ── Reagents section ───────────────────────────────────────────────────────

  Widget _buildReagentsSection(BuildContext context) {
    if (_reagents.isEmpty) {
      return Text('No reagents assigned to this location.',
          style:
              GoogleFonts.spaceGrotesk(color: context.appTextMuted, fontSize: 13));
    }
    return Column(
      children: _reagents.map((r) {
        final name   = r['reagent_name'] as String? ?? '';
        final type   = r['reagent_type'] as String? ?? '';
        final qty    = r['reagent_quantity'];
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: GoogleFonts.spaceGrotesk(
                          color: context.appTextPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                  Text(type,
                      style: GoogleFonts.spaceGrotesk(
                          color: context.appTextMuted, fontSize: 11)),
                ],
              ),
            ),
            if (qty != null)
              Text(
                '${(qty as num).toStringAsFixed((qty % 1 == 0) ? 0 : 2)} $unit',
                style: GoogleFonts.spaceGrotesk(
                    color: context.appTextSecondary, fontSize: 12),
              ),
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
                  expired ? 'Expired' : 'Exp ${_fmt(expiry)}',
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

  // ── QR dialog ──────────────────────────────────────────────────────────────

  void _showQr(LocationModel loc) {
    final ref  = SupabaseManager.projectRef ?? 'local';
    final data = 'bluelims://$ref/locations/${loc.id}';
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
                style: GoogleFonts.spaceGrotesk(
                    color: ctx.appTextMuted, fontSize: 11)),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: data));
              if (context.mounted) Navigator.pop(ctx);
              _snack('Link copied');
            },
            child: Text('Copy Link',
                style: GoogleFonts.spaceGrotesk(color: AppDS.accent)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Close',
                style:
                    GoogleFonts.spaceGrotesk(color: ctx.appTextSecondary)),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

// ─── Collapsible Section ─────────────────────────────────────────────────────
class _Section extends StatelessWidget {
  final int index;
  final String title;
  final IconData icon;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;

  const _Section({
    required this.index,
    required this.title,
    required this.icon,
    required this.expanded,
    required this.onToggle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.appBorder),
      ),
      child: Column(children: [
        // Header
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.vertical(
            top: const Radius.circular(10),
            bottom: Radius.circular(expanded ? 0 : 10),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: context.appSurface2,
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(10),
                bottom: Radius.circular(expanded ? 0 : 10),
              ),
            ),
            child: Row(children: [
              Icon(icon, size: 14, color: AppDS.accent),
              const SizedBox(width: 8),
              Text(title,
                  style: GoogleFonts.spaceGrotesk(
                      color: context.appTextSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8)),
              const Spacer(),
              Icon(
                expanded ? Icons.expand_less : Icons.expand_more,
                size: 18,
                color: context.appTextMuted,
              ),
            ]),
          ),
        ),
        // Body
        if (expanded) ...[
          Divider(height: 1, color: context.appBorder),
          Padding(
            padding: const EdgeInsets.all(14),
            child: child,
          ),
        ],
      ]),
    );
  }
}

// ─── Inline field layout helpers ─────────────────────────────────────────────
class _FieldRow extends StatelessWidget {
  final List<Widget> children;
  const _FieldRow({required this.children});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: children
          .expand((w) => [Expanded(child: w), const SizedBox(width: 10)])
          .toList()
        ..removeLast(),
    );
  }
}

class _InlineField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final int maxLines;
  final TextInputType? keyboardType;

  const _InlineField({
    required this.label,
    required this.controller,
    this.maxLines = 1,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: GoogleFonts.spaceGrotesk(color: context.appTextPrimary, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.spaceGrotesk(
            color: context.appTextSecondary, fontSize: 11),
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}

class _InlineDropdown<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final void Function(T?) onChanged;

  const _InlineDropdown({
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
            color: context.appTextSecondary, fontSize: 11),
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
