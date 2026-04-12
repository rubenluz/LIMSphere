// strain_detail_page.dart - Strain editor: taxonomy, morphology, culture
// maintenance, cryopreservation, molecular data, bioactivity.
// Widget classes in strain_detail_widgets.dart (part).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../samples/sample_detail_page.dart';
import '../../backups/backup_service.dart';
import '/theme/theme.dart';
import '/supabase/supabase_manager.dart';
import '../../camera/qr_scanner/qr_code_rules.dart';
import '../../requests/requests_page.dart';

part 'strain_detail_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Design tokens
// ─────────────────────────────────────────────────────────────────────────────
class _DS {
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
// Field group definitions
// ─────────────────────────────────────────────────────────────────────────────
typedef _Field = ({String key, String label, int lines});

_Field _f(String key, String label, {int lines = 1}) =>
    (key: key, label: label, lines: lines);

const _groups = <({String title, String icon, List<_Field> fields})>[
  (
    title: 'Identity & Status',
    icon: 'identity',
    fields: [
      (key: 'strain_code',               label: 'Code',                lines: 1),
      (key: 'strain_status',             label: 'Status',              lines: 1),
      (key: 'strain_origin',             label: 'Origin',              lines: 1),
      (key: 'strain_toxins',             label: 'Toxins',              lines: 1),
      (key: 'strain_situation',          label: 'Situation',           lines: 1),
      (key: 'strain_last_checked',       label: 'Last Checked',        lines: 1),
      (key: 'strain_public',             label: 'Public',              lines: 1),
      (key: 'strain_private_collection', label: 'Private Collection',  lines: 1),
      (key: 'strain_type_strain',        label: 'Type Strain',         lines: 1),
      (key: 'strain_biosafety_level',    label: 'Biosafety Level',     lines: 1),
      (key: 'strain_access_conditions',  label: 'Access Conditions',   lines: 1),
      (key: 'strain_other_codes',        label: 'Other Codes',         lines: 1),
    ],
  ),
  (
    title: 'Taxonomy',
    icon: 'taxonomy',
    fields: [
      (key: 'strain_empire',               label: 'Empire',              lines: 1),
      (key: 'strain_kingdom',              label: 'Kingdom',             lines: 1),
      (key: 'strain_phylum',               label: 'Phylum',              lines: 1),
      (key: 'strain_class',                label: 'Class',               lines: 1),
      (key: 'strain_order',                label: 'Order',               lines: 1),
      (key: 'strain_family',               label: 'Family',              lines: 1),
      (key: 'strain_genus',                label: 'Genus',               lines: 1),
      (key: 'strain_species',              label: 'Species',             lines: 1),
      (key: 'strain_subspecies',           label: 'Subspecies',          lines: 1),
      (key: 'strain_variety',              label: 'Variety',             lines: 1),
      (key: 'strain_scientific_name',      label: 'Scientific Name',     lines: 1),
      (key: 'strain_authority',            label: 'Authority',           lines: 1),
      (key: 'strain_other_names',          label: 'Other Names / Old ID',lines: 1),
      (key: 'strain_taxonomist',           label: 'Taxonomist',          lines: 1),
      (key: 'strain_identification_method',label: 'ID Method',           lines: 1),
      (key: 'strain_identification_date',  label: 'ID Date',             lines: 1),
    ],
  ),
  (
    title: 'Morphology',
    icon: 'morphology',
    fields: [
      (key: 'strain_morphology',          label: 'Morphology',          lines: 1),
      (key: 'strain_cell_shape',          label: 'Cell Shape',          lines: 1),
      (key: 'strain_cell_size_um',        label: 'Cell Size (µm)',      lines: 1),
      (key: 'strain_motility',            label: 'Motility',            lines: 1),
      (key: 'strain_pigments',            label: 'Pigments',            lines: 1),
      (key: 'strain_colonial_morphology', label: 'Colonial Morphology', lines: 1),
    ],
  ),
  (
    title: 'Herbarium',
    icon: 'herbarium',
    fields: [
      (key: 'strain_herbarium_code',   label: 'Herbarium Code',   lines: 1),
      (key: 'strain_herbarium_name',   label: 'Herbarium Name',   lines: 1),
      (key: 'strain_herbarium_status', label: 'Herbarium Status', lines: 1),
      (key: 'strain_herbarium_date',   label: 'Herbarium Date',   lines: 1),
      (key: 'strain_herbarium_method', label: 'Herbarium Method', lines: 1),
      (key: 'strain_herbarium_notes',  label: 'Herbarium Notes',  lines: 2),
    ],
  ),
  (
    title: 'Culture Maintenance',
    icon: 'culture',
    fields: [
      (key: 'strain_last_transfer',        label: 'Last Transfer',          lines: 1),
      (key: 'strain_periodicity',          label: 'Cycle (Days)',           lines: 1),
      (key: 'strain_next_transfer',        label: 'Next Transfer',          lines: 1),
      (key: 'strain_medium',               label: 'Medium',                 lines: 1),
      (key: 'strain_medium_salinity',      label: 'Medium Salinity',        lines: 1),
      (key: 'strain_light_cycle',          label: 'Light Cycle',            lines: 1),
      (key: 'strain_light_intensity_umol', label: 'Light (µmol)',           lines: 1),
      (key: 'strain_temperature_c',        label: 'Incubation °C',          lines: 1),
      (key: 'strain_co2_pct',              label: 'CO₂ (%)',                lines: 1),
      (key: 'strain_aeration',             label: 'Aeration',               lines: 1),
      (key: 'strain_culture_vessel',       label: 'Culture Vessel',         lines: 1),
      (key: 'strain_room',                 label: 'Room',                   lines: 1),
      (key: 'strain_isolation_responsible',label: 'Isolation Responsible',  lines: 1),
      (key: 'strain_isolation_date',       label: 'Isolation Date',         lines: 1),
      (key: 'strain_isolation_method',     label: 'Isolation Method',       lines: 1),
      (key: 'strain_deposit_date',         label: 'Deposit Date',           lines: 1),
    ],
  ),
  (
    title: 'Cryopreservation',
    icon: 'cryo',
    fields: [
      (key: 'strain_cryo_date',        label: 'Cryo Date',        lines: 1),
      (key: 'strain_cryo_method',      label: 'Cryo Method',      lines: 1),
      (key: 'strain_cryo_location',    label: 'Cryo Location',    lines: 1),
      (key: 'strain_cryo_vials',       label: 'Cryo Vials',       lines: 1),
      (key: 'strain_cryo_responsible', label: 'Cryo Responsible', lines: 1),
    ],
  ),
  (
    title: 'Photos',
    icon: 'photos',
    fields: [
      (key: 'strain_photo',            label: 'Photo URL',           lines: 1),
      (key: 'strain_public_photo',     label: 'Public Photo URL',    lines: 1),
      (key: 'strain_microscopy_photo', label: 'Microscopy Photo URL',lines: 1),
    ],
  ),
  (
    title: 'Molecular — Prokaryotes',
    icon: 'mol_pro',
    fields: [
      (key: 'strain_seq_16s_bp',      label: '16S (bp)',              lines: 1),
      (key: 'strain_its',             label: 'ITS',                   lines: 1),
      (key: 'strain_its_bands',       label: 'ITS Bands',             lines: 1),
      (key: 'strain_cloned_gel',      label: 'Cloned/GelExtraction',  lines: 1),
      (key: 'strain_genbank_16s_its', label: 'GenBank (16S+ITS)',     lines: 1),
      (key: 'strain_genbank_status',  label: 'GenBank Status',        lines: 1),
      (key: 'strain_genome_pct',      label: 'Genome (%)',            lines: 1),
      (key: 'strain_genome_cont',     label: 'Genome (Cont.)',        lines: 1),
      (key: 'strain_genome_16s',      label: 'Genome (16S)',          lines: 1),
      (key: 'strain_gca_accession',   label: 'GCA Accession',         lines: 1),
    ],
  ),
  (
    title: 'Molecular — Eukaryotes',
    icon: 'mol_euk',
    fields: [
      (key: 'strain_seq_18s_bp',    label: '18S (bp)',        lines: 1),
      (key: 'strain_genbank_18s',   label: 'GenBank (18S)',   lines: 1),
      (key: 'strain_its2_bp',       label: 'ITS2 (bp)',       lines: 1),
      (key: 'strain_genbank_its2',  label: 'GenBank (ITS2)',  lines: 1),
      (key: 'strain_rbcl_bp',       label: 'rbcL (bp)',       lines: 1),
      (key: 'strain_genbank_rbcl',  label: 'GenBank (rbcL)',  lines: 1),
      (key: 'strain_tufa_bp',       label: 'tufA (bp)',       lines: 1),
      (key: 'strain_genbank_tufa',  label: 'GenBank (tufA)',  lines: 1),
      (key: 'strain_cox1_bp',       label: 'COX1 (bp)',       lines: 1),
      (key: 'strain_genbank_cox1',  label: 'GenBank (COX1)',  lines: 1),
    ],
  ),
  (
    title: 'Bioactivity & Applications',
    icon: 'bioactivity',
    fields: [
      (key: 'strain_bioactivity',    label: 'Bioactivity',    lines: 2),
      (key: 'strain_metabolites',    label: 'Metabolites',    lines: 2),
      (key: 'strain_industrial_use', label: 'Industrial Use', lines: 2),
      (key: 'strain_growth_rate',    label: 'Growth Rate',    lines: 1),
    ],
  ),
  (
    title: 'References & Other',
    icon: 'other',
    fields: [
      (key: 'strain_publications',   label: 'Publications',   lines: 3),
      (key: 'strain_external_links', label: 'External Links', lines: 2),
      (key: 'strain_notes',          label: 'Notes',          lines: 3),
      (key: 'strain_qrcode',         label: 'QR Code',        lines: 1),
    ],
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────
IconData _sectionIcon(String icon) {
  return switch (icon) {
    'identity'    => Icons.fingerprint_rounded,
    'taxonomy'    => Icons.account_tree_rounded,
    'morphology'  => Icons.biotech_rounded,
    'herbarium'   => Icons.grass_rounded,
    'culture'     => Icons.science_rounded,
    'cryo'        => Icons.ac_unit_rounded,
    'photos'      => Icons.photo_library_outlined,
    'mol_pro'     => Icons.hexagon_outlined,
    'mol_euk'     => Icons.blur_circular_rounded,
    'bioactivity' => Icons.bolt_rounded,
    _             => Icons.notes_rounded,
  };
}

Color _statusColor(String? s) {
  return switch (s?.toUpperCase()) {
    'ALIVE'  => const Color(0xFF16A34A),
    'DEAD'   => const Color(0xFFDC2626),
    'INCARE' => const Color(0xFFD97706),
    _        => const Color(0xFF94A3B8),
  };
}

IconData _statusIcon(String? s) {
  return switch (s?.toUpperCase()) {
    'ALIVE'  => Icons.check_circle_rounded,
    'DEAD'   => Icons.cancel_rounded,
    'INCARE' => Icons.medical_services_rounded,
    _        => Icons.help_outline_rounded,
  };
}

bool _isMobile(BuildContext context) =>
    MediaQuery.of(context).size.width < 720;

// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────
class StrainDetailPage extends StatefulWidget {
  final dynamic strainId;
  final VoidCallback? onSaved;

  const StrainDetailPage({super.key, required this.strainId, this.onSaved});

  @override
  State<StrainDetailPage> createState() => _StrainDetailPageState();
}

class _StrainDetailPageState extends State<StrainDetailPage> {
  Map<String, dynamic> _data       = {};
  Map<String, dynamic> _sampleData = {};
  bool _loading = true;
  bool _saving  = false;

  // Mobile: which section index is active (shown one at a time)
  int _mobileSection = 0;

  // Desktop: expanded sections set
  final Set<int> _expanded = {};

  final Map<String, TextEditingController> _ctrl = {};

  @override
  void initState() {
    super.initState();
    _expanded.addAll(List.generate(_groups.length, (i) => i));
    _load();
  }

  void _recomputeNextTransfer() {
    final lastStr = _ctrl['strain_last_transfer']?.text ?? '';
    final days = int.tryParse(_ctrl['strain_periodicity']?.text ?? '');
    if (lastStr.isNotEmpty && days != null && days > 0) {
      final last = DateTime.tryParse(lastStr);
      if (last != null) {
        final next = last.add(Duration(days: days));
        final s = '${next.year}-${next.month.toString().padLeft(2, '0')}-${next.day.toString().padLeft(2, '0')}';
        _ctrl['strain_next_transfer'] ??= TextEditingController();
        _ctrl['strain_next_transfer']!.text = s;
        setState(() {});
      }
    }
  }

  void _showQrDialog(String data) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(_data['strain_code']?.toString() ?? 'QR Code',
            style: const TextStyle(fontSize: 15, color: _DS.titleColor)),
        content: SizedBox(
          width: 260,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12),
            child: QrImageView(data: data, size: 200),
          ),
          const SizedBox(height: 10),
          Text(data,
              style: const TextStyle(
                  fontSize: 10, color: _DS.labelColor, fontFamily: 'monospace'),
              textAlign: TextAlign.center),
        ]),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: data));
              if (ctx.mounted) { Navigator.pop(ctx); }
              if (mounted) { ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard'))); }
            },
            child: const Text('Copy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showLastTransferDatePicker() async {
    final current = DateTime.tryParse(_ctrl['strain_last_transfer']?.text ?? '');
    DateTime selected = current ?? DateTime.now();
    final result = await showDialog<DateTime>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Last Transfer Date', style: TextStyle(fontSize: 15)),
          content: SizedBox(
            width: 300,
            child: CalendarDatePicker(
              initialDate: selected,
              firstDate: DateTime(2000),
              lastDate: DateTime.now().add(const Duration(days: 1)),
              onDateChanged: (d) => selected = d,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _DS.accent, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, selected),
              child: const Text('OK')),
          ],
        ),
      ),
    );
    if (result == null) return;
    final s = '${result.year}-${result.month.toString().padLeft(2, '0')}-${result.day.toString().padLeft(2, '0')}';
    _ctrl['strain_last_transfer'] ??= TextEditingController();
    _ctrl['strain_last_transfer']!.text = s;
    _recomputeNextTransfer();
  }

  @override
  void dispose() {
    for (final c in _ctrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Data ──────────────────────────────────────────────────────────────────
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await Supabase.instance.client
          .from('strains')
          .select('*, samples(*)')
          .eq('strain_id', widget.strainId)
          .single();

      _data = Map<String, dynamic>.from(res);
      _sampleData = Map<String, dynamic>.from(_data['samples'] ?? {});
      _data.remove('samples');

      for (final group in _groups) {
        for (final f in group.fields) {
          _ctrl[f.key] ??= TextEditingController();
          _ctrl[f.key]!.text = _data[f.key]?.toString() ?? '';
        }
      }
      // Auto-compute next transfer if not stored
      if ((_data['strain_next_transfer']?.toString() ?? '').isEmpty) {
        _recomputeNextTransfer();
      }
      // Ensure QR code is generated and follows app rules
      final ref = SupabaseManager.projectRef ?? 'local';
      final expectedQr = QrRules.build(ref, 'strains', int.parse(widget.strainId.toString()));
      if (!QrRules.isValid(_data['strain_qrcode']?.toString() ?? '')) {
        _data['strain_qrcode'] = expectedQr;
        _ctrl['strain_qrcode']?.text = expectedQr;
        Supabase.instance.client
            .from('strains')
            .update({'strain_qrcode': expectedQr})
            .eq('strain_id', widget.strainId)
            .then((_) {})
            .catchError((_) {});
      }
    } catch (e) {
      _snack('Error loading strain: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final update = <String, dynamic>{};
      for (final group in _groups) {
        for (final f in group.fields) {
          final v = _ctrl[f.key]?.text ?? '';
          update[f.key] = v.isEmpty ? null : v;
        }
      }
      // Always enforce correct QR code — never let it be nulled or hand-edited
      final ref = SupabaseManager.projectRef ?? 'local';
      update['strain_qrcode'] = QrRules.build(ref, 'strains', int.parse(widget.strainId.toString()));
      await Supabase.instance.client
          .from('strains')
          .update(update)
          .eq('strain_id', widget.strainId);
      unawaited(BackupService.instance.notifyCrudChange('strains'));
      widget.onSaved?.call();
      _snack('Saved successfully.');
    } catch (e) {
      _snack('Save error: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final code = _data['strain_code'] ?? widget.strainId.toString();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.delete_forever_rounded, color: Color(0xFFDC2626), size: 40),
        title: const Text('Delete Strain?', textAlign: TextAlign.center),
        content: RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: const TextStyle(fontSize: 14, color: Color(0xFF475569), height: 1.5),
            children: [
              const TextSpan(text: 'You are about to permanently delete\n'),
              TextSpan(text: code,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              const TextSpan(text: '.\n\nThis action cannot be undone.'),
            ],
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
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
      await Supabase.instance.client
          .from('strains')
          .delete()
          .eq('strain_id', widget.strainId);
      unawaited(BackupService.instance.notifyCrudChange('strains'));
      widget.onSaved?.call();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _snack('Delete error: $e');
    }
  }

  void _openSample() {
    final sampleId = _data['strain_sample_code'];
    if (sampleId == null) return;
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => SampleDetailPage(sampleId: sampleId)));
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
    final code   = _data['strain_code']?.toString();
    final status = _data['strain_status']?.toString();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: _buildMobileAppBar(code, status),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              // ── Sample origin banner ──────────────────────────────────────
              if (_sampleData.isNotEmpty) _buildMobileSampleBanner(),

              // ── Section tab bar ───────────────────────────────────────────
              _buildMobileSectionBar(),

              // ── Fields for active section ─────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(12, 14, 12, 100),
                  child: _buildMobileSectionFields(_groups[_mobileSection].fields),
                ),
              ),
            ]),

      // ── Floating save button ──────────────────────────────────────────────
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : _save,
        backgroundColor: _DS.accent,
        foregroundColor: context.appTextPrimary,
        icon: _saving
            ? const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.save_rounded, size: 20),
        label: Text(_saving ? 'Saving…' : 'Save',
            style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }

  PreferredSizeWidget _buildMobileAppBar(String? code, String? status) {
    return AppBar(
      backgroundColor: context.appSurface,
      foregroundColor: context.appTextPrimary,
      elevation: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            code != null ? 'Strain: $code' : 'Strain Detail',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          if (_data['strain_scientific_name'] != null)
            Text(
              _data['strain_scientific_name'].toString(),
              style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: context.appTextSecondary),
            ),
        ],
      ),
      actions: [
        if (!_loading) ...[
          // Status badge
          if (status != null)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _statusColor(status).withValues(alpha:0.15),
                border: Border.all(color: _statusColor(status).withValues(alpha:0.5)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(_statusIcon(status), size: 11, color: _statusColor(status)),
                const SizedBox(width: 4),
                Text(status,
                    style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w600,
                        color: _statusColor(status))),
              ]),
            ),
          // More menu (delete)
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: context.appTextSecondary),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            onSelected: (v) {
              if (v == 'delete') _delete();
              if (v == 'request') {
                showQuickRequestDialog(
                context,
                type: 'strains',
                prefillTitle: _data['strain_code']?.toString() ?? '',
              );
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'request',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.outbox_outlined, size: 18),
                  title: Text('Quick Request', style: TextStyle(fontSize: 13)),
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 18),
                  title: Text('Delete strain', style: TextStyle(color: Color(0xFFDC2626), fontSize: 13)),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // ── Mobile: sample origin banner ──────────────────────────────────────────
  Widget _buildMobileSampleBanner() {
    final code    = _sampleData['sample_code'];
    final country = _sampleData['sample_country'];
    final island  = _sampleData['sample_island'];
    final parts   = [country, island].where((v) => v != null && v.toString().isNotEmpty).join(' · ');

    return GestureDetector(
      onTap: _openSample,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        color: const Color(0xFFEFF6FF),
        child: Row(children: [
          const Icon(Icons.colorize_outlined, size: 14, color: _DS.accent),
          const SizedBox(width: 8),
          Expanded(child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 12),
              children: [
                const TextSpan(text: 'Origin: ',
                    style: TextStyle(color: _DS.accent, fontWeight: FontWeight.w600)),
                TextSpan(text: code?.toString() ?? '—',
                    style: const TextStyle(color: _DS.titleColor, fontWeight: FontWeight.w600)),
                if (parts.isNotEmpty)
                  TextSpan(text: '  $parts',
                      style: const TextStyle(color: _DS.labelColor)),
              ],
            ),
          )),
          const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: _DS.accent),
        ]),
      ),
    );
  }

  // ── Mobile: horizontal scrollable section tab bar ─────────────────────────
  Widget _buildMobileSectionBar() {
    return Container(
      color: Colors.white,
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        itemCount: _groups.length,
        itemBuilder: (ctx, i) {
          final isActive = _mobileSection == i;
          return GestureDetector(
            onTap: () => setState(() => _mobileSection = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isActive ? _DS.accent : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isActive ? _DS.accent : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(_sectionIcon(_groups[i].icon),
                    size: 13,
                    color: isActive ? Colors.white : const Color(0xFF64748B)),
                const SizedBox(width: 5),
                Text(_groups[i].title,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isActive ? Colors.white : const Color(0xFF475569),
                    )),
              ]),
            ),
          );
        },
      ),
    );
  }

  // ── Mobile: fields rendered in a single column ────────────────────────────
  Widget _buildMobileSectionFields(List<_Field> fields) {
    return Column(
      children: fields.map((f) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _buildField(f),
      )).toList(),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DESKTOP LAYOUT  (original — unchanged)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildDesktop() {
    final code   = _data['strain_code']?.toString();
    final status = _data['strain_status']?.toString();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: _buildDesktopAppBar(code, status),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildDesktopBody(),
    );
  }

  PreferredSizeWidget _buildDesktopAppBar(String? code, String? status) {
    return AppBar(
      backgroundColor: context.appSurface,
      foregroundColor: context.appTextPrimary,
      elevation: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            code != null ? 'Strain: $code' : 'Strain Detail',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          if (_data['strain_scientific_name'] != null)
            Text(
              _data['strain_scientific_name'].toString(),
              style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: context.appTextSecondary),
            ),
        ],
      ),
      actions: [
        if (!_loading) ...[
          if (status != null)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _statusColor(status).withValues(alpha:0.15),
                border: Border.all(color: _statusColor(status).withValues(alpha:0.5)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(_statusIcon(status), size: 13, color: _statusColor(status)),
                const SizedBox(width: 5),
                Text(status,
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600,
                        color: _statusColor(status))),
              ]),
            ),
          const SizedBox(width: 4),
          IconButton(
            icon: Icon(Icons.outbox_outlined, color: context.appTextSecondary),
            tooltip: 'Quick Request',
            onPressed: () => showQuickRequestDialog(
              context,
              type: 'strains',
              prefillTitle: _data['strain_code']?.toString() ?? '',
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFFC8181)),
            tooltip: 'Delete strain',
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
                  ? const SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
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
        // ── Left sidebar ────────────────────────────────────────────────────
        SizedBox(
          width: 240,
          child: Container(
            color: Colors.white,
            child: Column(children: [
              if (_sampleData.isNotEmpty) _buildSampleCard(),
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
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                      leading: Icon(_sectionIcon(group.icon), size: 18,
                          color: isExp ? _DS.accent : const Color(0xFF94A3B8)),
                      title: Text(group.title,
                          style: TextStyle(fontSize: 12,
                              fontWeight: isExp ? FontWeight.w600 : FontWeight.normal,
                              color: isExp ? _DS.accent : const Color(0xFF475569))),
                      trailing: Icon(
                          isExp ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_right_rounded,
                          size: 16,
                          color: isExp ? _DS.accent : const Color(0xFF94A3B8)),
                      onTap: () => setState(() {
                        if (isExp) {
                          _expanded.remove(i);
                        } else {
                          _expanded.add(i);
                        }
                      }),
                      selected: isExp,
                      selectedTileColor: _DS.accent.withValues(alpha:0.06),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    );
                  },
                ),
              ),
            ]),
          ),
        ),
        // ── Main content ─────────────────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...List.generate(_groups.length, (i) {
                  if (!_expanded.contains(i)) return const SizedBox.shrink();
                  return _buildSection(i, _groups[i].title, _groups[i].icon, _groups[i].fields);
                }),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Desktop: sample origin card ───────────────────────────────────────────
  Widget _buildSampleCard() {
    final code    = _sampleData['sample_code'];
    final country = _sampleData['sample_country'];
    final island  = _sampleData['sample_island'];
    final local   = _sampleData['sample_local'];
    final date    = _sampleData['sample_date'];

    final subtitle = [country, island, local, date]
        .where((v) => v != null && v.toString().isNotEmpty)
        .join(' · ');

    return Container(
      padding: const EdgeInsets.all(14),
      color: const Color(0xFFEFF6FF),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.colorize_outlined, size: 15, color: _DS.accent),
          const SizedBox(width: 6),
          const Text('Origin Sample',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                  color: _DS.accent, letterSpacing: 0.5)),
        ]),
        const SizedBox(height: 6),
        Text(code?.toString() ?? 'Sample #${_data['strain_sample_code']}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _DS.titleColor)),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(subtitle,
              style: const TextStyle(fontSize: 11, color: _DS.labelColor),
              maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _openSample,
            icon: const Icon(Icons.open_in_new, size: 13),
            label: const Text('View Sample', style: TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 6),
              side: const BorderSide(color: _DS.accent),
              foregroundColor: _DS.accent,
            ),
          ),
        ),
      ]),
    );
  }

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
            BoxShadow(color: Colors.black.withValues(alpha:0.03), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Section header
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
                  color: _DS.accent.withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_sectionIcon(iconKey), size: 16, color: _DS.accent),
              ),
              const SizedBox(width: 10),
              Text(title.toUpperCase(), style: _DS.sectionTitle),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() {
                  if (_expanded.contains(index)) {
                    _expanded.remove(index);
                  } else {
                    _expanded.add(index);
                  }
                }),
                child: Icon(Icons.keyboard_arrow_up_rounded, size: 20, color: const Color(0xFF94A3B8)),
              ),
            ]),
          ),
          // Fields
          Padding(
            padding: const EdgeInsets.all(20),
            child: LayoutBuilder(builder: (ctx, constraints) {
              final cols = constraints.maxWidth > 800 ? 3 : constraints.maxWidth > 520 ? 2 : 1;
              final fieldW = (constraints.maxWidth - (cols - 1) * 16) / cols;
              return Wrap(
                spacing: 16, runSpacing: 16,
                children: fields.map((f) => SizedBox(width: fieldW, child: _buildField(f))).toList(),
              );
            }),
          ),
        ]),
      ),
    );
  }

  // ── Shared: individual field ──────────────────────────────────────────────
  Widget _buildField(_Field f) {
    final ctrl = _ctrl[f.key] ??= TextEditingController(text: _data[f.key]?.toString() ?? '');

    if (f.key == 'strain_status') {
      return _StatusDropdown(
        label: f.label,
        value: ctrl.text.isEmpty ? null : ctrl.text,
        onChanged: (v) => setState(() => ctrl.text = v ?? ''),
      );
    }

    if (f.key == 'strain_last_transfer') {
      return TextFormField(
        controller: ctrl,
        readOnly: true,
        onTap: _showLastTransferDatePicker,
        style: const TextStyle(fontSize: 13, color: _DS.titleColor),
        decoration: InputDecoration(
          labelText: f.label,
          labelStyle: const TextStyle(fontSize: 12, color: _DS.labelColor),
          isDense: true,
          filled: true,
          fillColor: const Color(0xFFFAFAFC),
          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 16, color: _DS.labelColor),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _DS.cardBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _DS.cardBorder)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _DS.accent, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      );
    }

    if (f.key == 'strain_next_transfer') {
      return TextFormField(
        controller: ctrl,
        readOnly: true,
        style: const TextStyle(fontSize: 13, color: _DS.titleColor),
        decoration: InputDecoration(
          labelText: f.label,
          labelStyle: const TextStyle(fontSize: 12, color: _DS.labelColor),
          isDense: true,
          filled: true,
          fillColor: const Color(0xFFF0F9FF),
          suffixIcon: const Icon(Icons.auto_awesome_outlined, size: 16, color: _DS.accent),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _DS.cardBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: _DS.accent.withValues(alpha: 0.35))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _DS.accent, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      );
    }

    if (f.key == 'strain_qrcode') {
      return TextFormField(
        controller: ctrl,
        readOnly: true,
        style: const TextStyle(fontSize: 11, color: _DS.labelColor, fontFamily: 'monospace'),
        decoration: InputDecoration(
          labelText: f.label,
          labelStyle: const TextStyle(fontSize: 12, color: _DS.labelColor),
          isDense: true,
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _DS.cardBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _DS.cardBorder)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _DS.cardBorder)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          suffixIcon: IconButton(
            icon: const Icon(Icons.qr_code_outlined, size: 18, color: _DS.accent),
            tooltip: 'Show QR code',
            onPressed: ctrl.text.isEmpty ? null : () => _showQrDialog(ctrl.text),
          ),
        ),
      );
    }

    if (f.key == 'strain_periodicity') {
      return TextFormField(
        controller: ctrl,
        maxLines: 1,
        style: const TextStyle(fontSize: 13, color: _DS.titleColor),
        decoration: InputDecoration(
          labelText: f.label,
          labelStyle: const TextStyle(fontSize: 12, color: _DS.labelColor),
          isDense: true,
          filled: true,
          fillColor: const Color(0xFFFAFAFC),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _DS.cardBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _DS.cardBorder)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _DS.accent, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        onChanged: (_) => _recomputeNextTransfer(),
      );
    }

    return TextFormField(
      controller: ctrl,
      maxLines: f.lines,
      style: const TextStyle(fontSize: 13, color: _DS.titleColor),
      decoration: InputDecoration(
        labelText: f.label,
        labelStyle: const TextStyle(fontSize: 12, color: _DS.labelColor),
        isDense: true,
        filled: true,
        fillColor: const Color(0xFFFAFAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _DS.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _DS.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _DS.accent, width: 1.5),
        ),
        contentPadding: f.lines > 1
            ? const EdgeInsets.all(12)
            : const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}

