import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../strains/strains_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Design tokens
// ─────────────────────────────────────────────────────────────────────────────
class _DS {
  static const Color headerBg   = Color(0xFF1E293B);
  static const Color accent     = Color(0xFF3B82F6);
  static const Color sectionBg  = Color(0xFFF8FAFC);
  static const Color cardBorder = Color(0xFFE2E8F0);
  static const Color labelColor = Color(0xFF64748B);
  static const Color titleColor = Color(0xFF0F172A);

  static const TextStyle sectionTitle = TextStyle(
    fontSize: 12, fontWeight: FontWeight.w700,
    color: Color(0xFF64748B), letterSpacing: 0.8,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Field model
// ─────────────────────────────────────────────────────────────────────────────
typedef _Field = ({String key, String label, bool readOnly, int lines});

_Field _f(String key, String label, {bool readOnly = false, int lines = 1}) =>
    (key: key, label: label, readOnly: readOnly, lines: lines);

// ─────────────────────────────────────────────────────────────────────────────
// Section definitions
// ─────────────────────────────────────────────────────────────────────────────
const _groups = <({String title, String icon, List<_Field> fields})>[
  (
    title: 'Identifiers',
    icon: 'id',
    fields: [
      (key: 'sample_code',       label: 'Code',        readOnly: true,  lines: 1),
      (key: 'sample_rebeca',     label: 'REBECA',      readOnly: false, lines: 1),
      (key: 'sample_ccpi',       label: 'CCPI',        readOnly: false, lines: 1),
      (key: 'sample_permit',     label: 'Permit',      readOnly: false, lines: 1),
      (key: 'sample_other_code', label: 'Other Code',  readOnly: false, lines: 1),
    ],
  ),
  (
    title: 'Collection Event',
    icon: 'collection',
    fields: [
      (key: 'sample_date',        label: 'Date',        readOnly: false, lines: 1),
      (key: 'sample_collector',   label: 'Collector',   readOnly: false, lines: 1),
      (key: 'sample_responsible', label: 'Responsible', readOnly: false, lines: 1),
      (key: 'sample_project',     label: 'Project',     readOnly: false, lines: 1),
    ],
  ),
  (
    title: 'Geography',
    icon: 'geo',
    fields: [
      (key: 'sample_country',      label: 'Country',      readOnly: false, lines: 1),
      (key: 'sample_archipelago',  label: 'Archipelago',  readOnly: false, lines: 1),
      (key: 'sample_island',       label: 'Island',       readOnly: false, lines: 1),
      (key: 'sample_region',       label: 'Region',       readOnly: false, lines: 1),
      (key: 'sample_municipality', label: 'Municipality', readOnly: false, lines: 1),
      (key: 'sample_parish',       label: 'Parish',       readOnly: false, lines: 1),
      (key: 'sample_local',        label: 'Local',        readOnly: false, lines: 1),
      (key: 'sample_gps',          label: 'GPS',          readOnly: false, lines: 1),
      (key: 'sample_latitude',     label: 'Latitude',     readOnly: false, lines: 1),
      (key: 'sample_longitude',    label: 'Longitude',    readOnly: false, lines: 1),
      (key: 'sample_altitude_m',   label: 'Altitude (m)', readOnly: false, lines: 1),
    ],
  ),
  (
    title: 'Habitat',
    icon: 'habitat',
    fields: [
      (key: 'sample_habitat_type',          label: 'Habitat Type',         readOnly: false, lines: 1),
      (key: 'sample_habitat_1',             label: 'Habitat 1',            readOnly: false, lines: 1),
      (key: 'sample_habitat_2',             label: 'Habitat 2',            readOnly: false, lines: 1),
      (key: 'sample_habitat_3',             label: 'Habitat 3',            readOnly: false, lines: 1),
      (key: 'sample_substrate',             label: 'Substrate',            readOnly: false, lines: 1),
      (key: 'sample_method',                label: 'Method',               readOnly: false, lines: 1),
      (key: 'sample_bloom',                 label: 'Bloom',                readOnly: false, lines: 1),
      (key: 'sample_associated_organisms',  label: 'Associated Organisms', readOnly: false, lines: 2),
    ],
  ),
  (
    title: 'Physical-Chemical Parameters',
    icon: 'parameters',
    fields: [
      (key: 'sample_temperature',  label: '°C',              readOnly: false, lines: 1),
      (key: 'sample_ph',           label: 'pH',              readOnly: false, lines: 1),
      (key: 'sample_conductivity', label: 'µS/cm',           readOnly: false, lines: 1),
      (key: 'sample_oxygen',       label: 'O₂ (mg/L)',       readOnly: false, lines: 1),
      (key: 'sample_salinity',     label: 'Salinity',        readOnly: false, lines: 1),
      (key: 'sample_radiation',    label: 'Solar Radiation', readOnly: false, lines: 1),
      (key: 'sample_turbidity',    label: 'Turbidity (NTU)', readOnly: false, lines: 1),
      (key: 'sample_depth_m',      label: 'Depth (m)',       readOnly: false, lines: 1),
    ],
  ),
  (
    title: 'Logistics',
    icon: 'logistics',
    fields: [
      (key: 'sample_photos',           label: 'Photos',        readOnly: false, lines: 1),
      (key: 'sample_preservation',     label: 'Preservation',  readOnly: false, lines: 1),
      (key: 'sample_transport_time_h', label: 'Transport (h)', readOnly: false, lines: 1),
    ],
  ),
  (
    title: 'Observations',
    icon: 'notes',
    fields: [
      (key: 'sample_observations', label: 'Observations', readOnly: false, lines: 4),
    ],
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────
IconData _sectionIcon(String icon) {
  return switch (icon) {
    'id'         => Icons.tag_rounded,
    'collection' => Icons.event_note_rounded,
    'geo'        => Icons.place_rounded,
    'habitat'    => Icons.forest_rounded,
    'parameters' => Icons.thermostat_rounded,
    'logistics'  => Icons.local_shipping_outlined,
    _            => Icons.notes_rounded,
  };
}

Color _statusColor(String? s) => switch (s?.toUpperCase()) {
  'ALIVE'  => const Color(0xFF16A34A),
  'DEAD'   => const Color(0xFFDC2626),
  'INCARE' => const Color(0xFFD97706),
  _        => const Color(0xFF94A3B8),
};

IconData _statusIcon(String? s) => switch (s?.toUpperCase()) {
  'ALIVE'  => Icons.check_circle_rounded,
  'DEAD'   => Icons.cancel_rounded,
  'INCARE' => Icons.medical_services_rounded,
  _        => Icons.help_outline_rounded,
};

bool _isMobile(BuildContext context) =>
    MediaQuery.of(context).size.width < 720;

// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────
class SampleDetailPage extends StatefulWidget {
  final dynamic sampleId;
  final VoidCallback? onSaved;

  const SampleDetailPage({super.key, required this.sampleId, this.onSaved});

  @override
  State<SampleDetailPage> createState() => _SampleDetailPageState();
}

class _SampleDetailPageState extends State<SampleDetailPage> {
  final _supabase = Supabase.instance.client;

  Map<String, dynamic> _data    = {};
  List<Map<String, dynamic>> _strains = [];

  bool _loading = true;
  bool _saving  = false;

  // Mobile: active section index (last = strains)
  int _mobileSection = 0;

  // Desktop: expanded sections
  final Set<int> _expanded = {};

  final Map<String, TextEditingController> _ctrl = {};

  // Total "tabs" on mobile = sections + 1 for strains
  int get _mobileTotalTabs => _groups.length + 1;

  @override
  void initState() {
    super.initState();
    _expanded.addAll(List.generate(_groups.length, (i) => i));
    _load();
  }

  @override
  void dispose() {
    for (final c in _ctrl.values) c.dispose();
    super.dispose();
  }

  // ── Data ──────────────────────────────────────────────────────────────────
  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final sample = await _supabase
          .from('samples')
          .select()
          .eq('sample_code', widget.sampleId)
          .single();

      final strains = await _supabase
          .from('strains')
          .select('strain_id, strain_code, strain_status, strain_genus, strain_species, strain_scientific_name, strain_sample_code')
          .eq('strain_sample_code', widget.sampleId)
          .order('strain_code', ascending: true);

      if (!mounted) return;
      _data    = Map<String, dynamic>.from(sample);
      _strains = List<Map<String, dynamic>>.from(strains);
      _syncControllers();
    } catch (e) {
      _snack('Error loading sample: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _syncControllers() {
    for (final group in _groups) {
      for (final f in group.fields) {
        _ctrl[f.key] ??= TextEditingController();
        _ctrl[f.key]!.text = _data[f.key]?.toString() ?? '';
      }
    }
  }

  // ── Save ──────────────────────────────────────────────────────────────────
  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final update = <String, dynamic>{};
      for (final group in _groups) {
        for (final f in group.fields) {
          if (!f.readOnly) {
            final v = _ctrl[f.key]?.text.trim() ?? '';
            update[f.key] = v.isEmpty ? null : v;
          }
        }
      }
      await _supabase.from('samples').update(update).eq('sample_code', widget.sampleId);
      widget.onSaved?.call();
      _snack('Saved successfully.');
    } catch (e) {
      _snack('Save error: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Delete ────────────────────────────────────────────────────────────────
  Future<void> _delete() async {
    final label = _data['sample_code']?.toString() ??
        '#${_data['sample_other_code']?.toString() ?? widget.sampleId.toString()}';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.delete_forever_rounded, color: Color(0xFFDC2626), size: 40),
        title: const Text('Delete Sample?', textAlign: TextAlign.center),
        content: RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: const TextStyle(fontSize: 14, color: Color(0xFF475569), height: 1.5),
            children: [
              const TextSpan(text: 'You are about to permanently delete\n'),
              TextSpan(text: label,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              const TextSpan(
                  text: '.\n\nAll linked strains will be unlinked.\nThis action cannot be undone.'),
            ],
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          const SizedBox(width: 8),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            icon: const Icon(Icons.delete_forever_rounded, size: 16),
            label: const Text('Delete'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    try {
      await _supabase.from('samples').delete().eq('sample_code', widget.sampleId);
      widget.onSaved?.call();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _snack('Delete error: $e');
    }
  }

  // ── Navigation ────────────────────────────────────────────────────────────
  Future<void> _openStrains() async {
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => StrainsPage(filterSampleId: widget.sampleId),
    ));
    _load();
  }

  Future<void> _addStrain() async {
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => StrainsPage(
        filterSampleId: widget.sampleId,
        autoOpenNewStrainForSample: widget.sampleId,
      ),
    ));
    _load();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD — route to mobile or desktop
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return _isMobile(context) ? _buildMobile() : _buildDesktop();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MOBILE LAYOUT
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildMobile() {
    final code = _data['sample_code']?.toString();
    final isStrainTab = _mobileSection == _groups.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: _buildMobileAppBar(code),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              // ── Quick info banner ─────────────────────────────────────────
              _buildMobileInfoBanner(),

              // ── Section tab bar ───────────────────────────────────────────
              _buildMobileSectionBar(),

              // ── Content ───────────────────────────────────────────────────
              Expanded(
                child: isStrainTab
                    ? _buildMobileStrainsTab()
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(12, 14, 12, 100),
                        child: _buildMobileSectionFields(
                            _groups[_mobileSection].fields),
                      ),
              ),
            ]),

      // ── FAB: save (hidden on strains tab) ─────────────────────────────────
      floatingActionButton: isStrainTab
          ? FloatingActionButton.extended(
              onPressed: _addStrain,
              backgroundColor: _DS.accent,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Add Strain',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            )
          : FloatingActionButton.extended(
              onPressed: _saving ? null : _save,
              backgroundColor: _DS.accent,
              foregroundColor: Colors.white,
              icon: _saving
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_rounded, size: 20),
              label: Text(_saving ? 'Saving…' : 'Save',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
    );
  }

  PreferredSizeWidget _buildMobileAppBar(String? code) {
    return AppBar(
      backgroundColor: _DS.headerBg,
      foregroundColor: Colors.white,
      elevation: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            code != null ? 'Sample: $code' : 'Sample Detail',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
        ],
      ),
      actions: [
        if (!_loading) ...[
          // Strain count badge
          if (_strains.isNotEmpty)
            GestureDetector(
              onTap: () => setState(() => _mobileSection = _groups.length),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _DS.accent.withOpacity(0.15),
                  border: Border.all(color: _DS.accent.withOpacity(0.4)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.science_rounded, size: 11, color: _DS.accent),
                  const SizedBox(width: 4),
                  Text('${_strains.length}',
                      style: const TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w600,
                          color: _DS.accent)),
                ]),
              ),
            ),
          // More menu (delete)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white70),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            onSelected: (v) { if (v == 'delete') _delete(); },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.delete_outline_rounded,
                      color: Color(0xFFDC2626), size: 18),
                  title: Text('Delete sample',
                      style: TextStyle(
                          color: Color(0xFFDC2626), fontSize: 13)),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // ── Mobile: compact info banner ───────────────────────────────────────────
  Widget _buildMobileInfoBanner() {
    final country = _data['sample_country']?.toString();
    final island  = _data['sample_island']?.toString();
    final date    = _data['sample_date']?.toString();

    final parts = [country, island, date]
        .where((v) => v != null && v!.isNotEmpty)
        .join('  ·  ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      color: const Color(0xFFEFF6FF),
      child: Row(children: [
        const Icon(Icons.place_rounded, size: 14, color: _DS.accent),
        const SizedBox(width: 8),
        Expanded(
          child: parts.isNotEmpty
              ? Text(parts,
                  style: const TextStyle(fontSize: 12, color: _DS.labelColor),
                  overflow: TextOverflow.ellipsis)
              : const Text('No location data',
                  style: TextStyle(fontSize: 12, color: _DS.labelColor)),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => setState(() => _mobileSection = _groups.length),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _DS.accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.science_rounded, size: 12, color: _DS.accent),
              const SizedBox(width: 4),
              Text('${_strains.length} strain${_strains.length != 1 ? 's' : ''}',
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: _DS.accent)),
            ]),
          ),
        ),
      ]),
    );
  }

  // ── Mobile: horizontal scrollable section + strains tab bar ──────────────
  Widget _buildMobileSectionBar() {
    return Container(
      color: Colors.white,
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        // +1 for Strains tab at the end
        itemCount: _groups.length + 1,
        itemBuilder: (ctx, i) {
          final isStrainTab = i == _groups.length;
          final isActive    = _mobileSection == i;

          final label = isStrainTab ? 'Strains' : _groups[i].title;
          final icon  = isStrainTab
              ? Icons.science_rounded
              : _sectionIcon(_groups[i].icon);

          return GestureDetector(
            onTap: () => setState(() => _mobileSection = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isActive
                    ? (isStrainTab
                        ? const Color(0xFF16A34A)
                        : _DS.accent)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isActive
                      ? (isStrainTab
                          ? const Color(0xFF16A34A)
                          : _DS.accent)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 13,
                    color: isActive ? Colors.white : const Color(0xFF64748B)),
                const SizedBox(width: 5),
                Text(label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isActive
                          ? Colors.white
                          : const Color(0xFF475569),
                    )),
                // Strain count badge on the strains tab
                if (isStrainTab && _strains.isNotEmpty) ...[
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: isActive
                          ? Colors.white.withOpacity(0.3)
                          : const Color(0xFF16A34A).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${_strains.length}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isActive
                              ? Colors.white
                              : const Color(0xFF16A34A),
                        )),
                  ),
                ],
              ]),
            ),
          );
        },
      ),
    );
  }

  // ── Mobile: section fields (single column) ────────────────────────────────
  Widget _buildMobileSectionFields(List<_Field> fields) {
    return Column(
      children: fields.map((f) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _buildField(f),
      )).toList(),
    );
  }

  // ── Mobile: strains tab ───────────────────────────────────────────────────
  Widget _buildMobileStrainsTab() {
    if (_strains.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.science_outlined, size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 14),
            Text('No strains yet',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: Colors.grey.shade500)),
            const SizedBox(height: 4),
            Text('Tap the button below to add the first strain.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
          ]),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
      itemCount: _strains.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final s       = _strains[i];
        final code    = s['strain_code']?.toString() ?? '—';
        final genus   = s['strain_genus']?.toString();
        final sp      = s['strain_species']?.toString();
        final sciName = s['strain_scientific_name']?.toString();
        final status  = s['strain_status']?.toString();
        final taxon   = sciName ??
            [genus, sp].where((v) => v != null && v!.isNotEmpty).join(' ');

        return GestureDetector(
          onTap: _openStrains,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _DS.cardBorder),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.03),
                    blurRadius: 4, offset: const Offset(0, 1)),
              ],
            ),
            child: Row(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: _DS.accent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.science_outlined, size: 18, color: _DS.accent),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(code,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: _DS.titleColor)),
                  if (taxon.isNotEmpty)
                    Text(taxon,
                        style: const TextStyle(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: _DS.labelColor),
                        overflow: TextOverflow.ellipsis),
                ],
              )),
              if (status != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withOpacity(0.1),
                    border: Border.all(
                        color: _statusColor(status).withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(_statusIcon(status),
                        size: 11, color: _statusColor(status)),
                    const SizedBox(width: 4),
                    Text(status,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _statusColor(status))),
                  ]),
                ),
            ]),
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DESKTOP LAYOUT  (original — unchanged)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildDesktop() {
    final code = _data['sample_code']?.toString();
    final id   = _data['sample_id']?.toString();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: _buildDesktopAppBar(code, id),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildDesktopBody(),
    );
  }

  PreferredSizeWidget _buildDesktopAppBar(String? code, String? number) {
    return AppBar(
      backgroundColor: _DS.headerBg,
      foregroundColor: Colors.white,
      elevation: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            code != null ? 'Sample: $code' : 'Sample Detail',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
        ],
      ),
      actions: [
        if (!_loading) ...[
          if (_strains.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _DS.accent.withOpacity(0.15),
                border: Border.all(color: _DS.accent.withOpacity(0.4)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.science_rounded, size: 13, color: _DS.accent),
                const SizedBox(width: 5),
                Text('${_strains.length} strain${_strains.length != 1 ? 's' : ''}',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600,
                        color: _DS.accent)),
              ]),
            ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFFC8181)),
            tooltip: 'Delete sample',
            onPressed: _delete,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: _DS.accent,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              icon: _saving
                  ? const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_rounded, size: 16),
              label: const Text('Save', style: TextStyle(fontSize: 13)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDesktopBody() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Left sidebar ───────────────────────────────────────────────────
        SizedBox(
          width: 240,
          child: Container(
            color: Colors.white,
            child: Column(children: [
              _buildStatsBar(),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _groups.length,
                  itemBuilder: (ctx, i) {
                    final group = _groups[i];
                    final isExp = _expanded.contains(i);
                    return ListTile(
                      dense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                      leading: Icon(_sectionIcon(group.icon), size: 18,
                          color: isExp ? _DS.accent : const Color(0xFF94A3B8)),
                      title: Text(group.title,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isExp ? FontWeight.w600 : FontWeight.normal,
                            color: isExp ? _DS.accent : const Color(0xFF475569),
                          )),
                      trailing: Icon(
                          isExp
                              ? Icons.keyboard_arrow_down_rounded
                              : Icons.keyboard_arrow_right_rounded,
                          size: 16,
                          color: isExp ? _DS.accent : const Color(0xFF94A3B8)),
                      selected: isExp,
                      selectedTileColor: _DS.accent.withOpacity(0.06),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      onTap: () => setState(() {
                        if (isExp) _expanded.remove(i);
                        else _expanded.add(i);
                      }),
                    );
                  },
                ),
              ),
            ]),
          ),
        ),

        // ── Main content ───────────────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...List.generate(_groups.length, (i) {
                  if (!_expanded.contains(i)) return const SizedBox.shrink();
                  final g = _groups[i];
                  return _buildSection(i, g.title, g.icon, g.fields);
                }),
                const SizedBox(height: 8),
                _buildStrainsSection(),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Desktop: stats bar ────────────────────────────────────────────────────
  Widget _buildStatsBar() {
    final country = _data['sample_country']?.toString();
    final island  = _data['sample_island']?.toString();
    final date    = _data['sample_date']?.toString();

    return Container(
      padding: const EdgeInsets.all(14),
      color: const Color(0xFFEFF6FF),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.colorize_outlined, size: 15, color: _DS.accent),
          const SizedBox(width: 6),
          const Text('Sample Info',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                  color: _DS.accent, letterSpacing: 0.5)),
        ]),
        const SizedBox(height: 8),
        if (country != null) _statRow(Icons.flag_rounded, country),
        if (island  != null) _statRow(Icons.landscape_rounded, island),
        if (date    != null) _statRow(Icons.calendar_today_rounded, date),
        const SizedBox(height: 6),
        _statRow(Icons.science_rounded,
            '${_strains.length} strain${_strains.length != 1 ? 's' : ''}',
            color: _DS.accent),
      ]),
    );
  }

  Widget _statRow(IconData icon, String text, {Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(children: [
      Icon(icon, size: 13, color: color ?? _DS.labelColor),
      const SizedBox(width: 6),
      Expanded(
        child: Text(text,
            style: TextStyle(fontSize: 12, color: color ?? const Color(0xFF334155)),
            overflow: TextOverflow.ellipsis),
      ),
    ]),
  );

  // ── Desktop: section card ─────────────────────────────────────────────────
  Widget _buildSection(int index, String title, String iconKey, List<_Field> fields) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _DS.cardBorder),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03),
                blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: _DS.sectionBg,
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12), topRight: Radius.circular(12)),
              border: const Border(bottom: BorderSide(color: _DS.cardBorder)),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: _DS.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(_sectionIcon(iconKey), size: 16, color: _DS.accent),
              ),
              const SizedBox(width: 10),
              Text(title.toUpperCase(), style: _DS.sectionTitle),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() {
                  if (_expanded.contains(index)) _expanded.remove(index);
                  else _expanded.add(index);
                }),
                child: const Icon(Icons.keyboard_arrow_up_rounded,
                    size: 20, color: Color(0xFF94A3B8)),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: LayoutBuilder(builder: (ctx, constraints) {
              final cols = constraints.maxWidth > 800 ? 3
                  : constraints.maxWidth > 520 ? 2 : 1;
              final fieldW = (constraints.maxWidth - (cols - 1) * 16) / cols;
              return Wrap(
                spacing: 16, runSpacing: 16,
                children: fields
                    .map((f) => SizedBox(width: fieldW, child: _buildField(f)))
                    .toList(),
              );
            }),
          ),
        ]),
      ),
    );
  }

  // ── Shared: individual field ──────────────────────────────────────────────
  Widget _buildField(_Field f) {
    final ctrl = _ctrl[f.key] ??=
        TextEditingController(text: _data[f.key]?.toString() ?? '');

    return TextFormField(
      controller: ctrl,
      readOnly: f.readOnly,
      maxLines: f.lines,
      style: const TextStyle(fontSize: 13, color: _DS.titleColor),
      decoration: InputDecoration(
        labelText: f.label,
        labelStyle: const TextStyle(fontSize: 12, color: _DS.labelColor),
        isDense: true,
        filled: true,
        fillColor: f.readOnly ? const Color(0xFFF1F5F9) : const Color(0xFFFAFAFC),
        border:         OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _DS.cardBorder)),
        enabledBorder:  OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _DS.cardBorder)),
        focusedBorder:  OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _DS.accent, width: 1.5)),
        disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _DS.cardBorder)),
        contentPadding: f.lines > 1
            ? const EdgeInsets.all(12)
            : const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }

  // ── Desktop: strains section ──────────────────────────────────────────────
  Widget _buildStrainsSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _DS.cardBorder),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03),
              blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: const BoxDecoration(
            color: _DS.sectionBg,
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12), topRight: Radius.circular(12)),
            border: Border(bottom: BorderSide(color: _DS.cardBorder)),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                  color: _DS.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.science_rounded, size: 16, color: _DS.accent),
            ),
            const SizedBox(width: 10),
            Text('STRAINS FROM THIS SAMPLE'.toUpperCase(), style: _DS.sectionTitle),
            if (_strains.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                    color: _DS.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: Text('${_strains.length}',
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.bold,
                        color: _DS.accent)),
              ),
            ],
            const Spacer(),
            if (_strains.isNotEmpty)
              TextButton.icon(
                onPressed: _openStrains,
                icon: const Icon(Icons.open_in_new, size: 14),
                label: const Text('View all', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(foregroundColor: _DS.accent,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
              ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _addStrain,
              icon: const Icon(Icons.add, size: 15),
              label: const Text('Add Strain', style: TextStyle(fontSize: 12)),
              style: FilledButton.styleFrom(
                backgroundColor: _DS.accent,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
            ),
          ]),
        ),
        if (_strains.isEmpty)
          _buildEmptyStrains()
        else
          _buildDesktopStrainsList(),
      ]),
    );
  }

  Widget _buildEmptyStrains() => Padding(
    padding: const EdgeInsets.all(32),
    child: Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.science_outlined, size: 48, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        Text('No strains yet',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15,
                color: Colors.grey.shade500)),
        const SizedBox(height: 4),
        Text('Add the first strain isolated from this sample.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _addStrain,
          icon: const Icon(Icons.add),
          label: const Text('Add First Strain'),
          style: FilledButton.styleFrom(backgroundColor: _DS.accent),
        ),
      ]),
    ),
  );

  Widget _buildDesktopStrainsList() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _strains.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: _DS.cardBorder),
      itemBuilder: (_, i) {
        final s       = _strains[i];
        final code    = s['strain_code']?.toString() ?? '—';
        final genus   = s['strain_genus']?.toString();
        final sp      = s['strain_species']?.toString();
        final sciName = s['strain_scientific_name']?.toString();
        final status  = s['strain_status']?.toString();
        final taxon   = sciName ??
            [genus, sp].where((v) => v != null && v!.isNotEmpty).join(' ');

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          leading: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
                color: _DS.accent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.science_outlined, size: 18, color: _DS.accent),
          ),
          title: Text(code,
              style: const TextStyle(fontWeight: FontWeight.w600,
                  fontSize: 13, color: _DS.titleColor)),
          subtitle: taxon.isNotEmpty
              ? Text(taxon,
                  style: const TextStyle(fontSize: 12,
                      fontStyle: FontStyle.italic, color: _DS.labelColor))
              : null,
          trailing: status != null
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withOpacity(0.1),
                    border: Border.all(
                        color: _statusColor(status).withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(_statusIcon(status), size: 11, color: _statusColor(status)),
                    const SizedBox(width: 4),
                    Text(status,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                            color: _statusColor(status))),
                  ]),
                )
              : null,
          onTap: _openStrains,
        );
      },
    );
  }
}