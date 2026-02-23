import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../samples/sample_detail_page.dart';

class StrainDetailPage extends StatefulWidget {
  final dynamic strainId;
  final VoidCallback? onSaved;

  const StrainDetailPage({super.key, required this.strainId, this.onSaved});

  @override
  State<StrainDetailPage> createState() => _StrainDetailPageState();
}

class _StrainDetailPageState extends State<StrainDetailPage> {
  Map<String, dynamic> _data = {};
  Map<String, dynamic> _sampleData = {};
  bool _loading = true;
  bool _saving = false;

  // Field groups for organized layout
  static const _groups = [
    (
      'Identity',
      [
        ('code',              'Code',                 true),
        ('origin',            'Origin',               true),
        ('status',            'Status',               true),
        ('toxins',            'Toxins',               true),
        ('situation',         'Situation',            true),
        ('last_checked',      'Last Checked',         true),
        ('public',            'Public',               true),
        ('private_collection','Private Collection',   true),
        ('type_strain',       'Type Strain',          true),
      ]
    ),
    (
      'Taxonomy',
      [
        ('empire',            'Empire',               true),
        ('class_name',        'Class',                true),
        ('order_name',        'Order',                true),
        ('family',            'Family',               true),
        ('genus',             'Genus',                true),
        ('species',           'Species',              true),
        ('scientific_name',   'Scientific Name',      true),
        ('authority',         'Authority',            true),
        ('old_identification','Old Identification',   true),
        ('taxonomist',        'Taxonomist',           true),
        ('other_names',       'Other Names',          true),
      ]
    ),
    (
      'Ruy Telles Palhinha',
      [
        ('rtp_code',          'RTP Code',             true),
        ('rtp_status',        'RTP Status',           true),
      ]
    ),
    (
      'Culture Maintenance',
      [
        ('last_transfer',         'Last Transfer',         true),
        ('time_days',             'Time (Days)',           true),
        ('next_transfer',         'Next Transfer',         true),
        ('medium',                'Medium',                true),
        ('room',                  'Room',                  true),
        ('isolation_responsible', 'Isolation Responsible', true),
        ('isolation_date',        'Isolation Date',        true),
        ('deposit_date',          'Deposit Date',          true),
      ]
    ),
    (
      'Media & Taxonomy Images',
      [
        ('photo',             'Photo URL',            true),
        ('public_photo',      'Public Photo URL',     true),
      ]
    ),
    (
      'Molecular Data — Prokaryotes',
      [
        ('seq_16s_bp',        '16S (bp)',              true),
        ('its',               'ITS',                  true),
        ('its_bands',         'ITS Bands',            true),
        ('cloned_gel',        'Cloned/GelExtraction', true),
        ('genbank_16s_its',   'GenBank (16S+ITS)',     true),
        ('genbank_status',    'GenBank Status',        true),
        ('genome_pct',        'Genome (%)',            true),
        ('genome_cont',       'Genome (Cont.)',        true),
        ('genome_16s',        'Genome (16S)',          true),
        ('gca_accession',     'GCA Accession',         true),
      ]
    ),
    (
      'Molecular Data — Eukaryotes',
      [
        ('seq_18s_bp',        '18S (bp)',              true),
        ('genbank_18s',       'GenBank (18S)',         true),
        ('its2_bp',           'ITS2 (bp)',             true),
        ('genbank_its2',      'GenBank (ITS2)',        true),
        ('rbcl_bp',           'rbcL (bp)',             true),
        ('genbank_rbcl',      'GenBank (rbcL)',        true),
      ]
    ),
    (
      'Other',
      [
        ('publications',      'Publications',         true),
        ('qrcode',            'QR Code',              true),
      ]
    ),
  ];

  final Map<String, TextEditingController> _ctrl = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _ctrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await Supabase.instance.client
          .from('strains')
          .select('*, samples(*)')
          .eq('id', widget.strainId)
          .single();

      _data = Map<String, dynamic>.from(res);
      _sampleData = Map<String, dynamic>.from(_data['samples'] ?? {});
      _data.remove('samples');

      // Init controllers for all editable fields
      for (final group in _groups) {
        for (final field in group.$2) {
          final key = field.$1;
          _ctrl[key] = TextEditingController(text: _data[key]?.toString() ?? '');
        }
      }
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final update = <String, dynamic>{};
      for (final group in _groups) {
        for (final field in group.$2) {
          if (field.$3) {
            final v = _ctrl[field.$1]!.text;
            update[field.$1] = v.isEmpty ? null : v;
          }
        }
      }
      await Supabase.instance.client
          .from('strains')
          .update(update)
          .eq('id', widget.strainId);
      _snack('Saved.');
      widget.onSaved?.call();
    } catch (e) {
      _snack('Save error: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _openSample() {
    final sampleId = _data['sample_id'];
    if (sampleId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SampleDetailPage(sampleId: sampleId),
      ),
    );
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_data['code'] != null ? 'Strain: ${_data['code']}' : 'Strain Detail'),
        actions: [
          if (!_loading)
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save),
              label: const Text('Save'),
            ),
          const SizedBox(width: 12),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Origin sample banner ─────────────────────────────
                  if (_sampleData.isNotEmpty)
                    Card(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      child: ListTile(
                        leading: Icon(Icons.colorize_outlined,
                            color: Theme.of(context).colorScheme.primary),
                        title: Text(
                          'Origin Sample: ${_sampleData['rebeca'] ?? _data['sample_id']}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text([
                          _sampleData['country'],
                          _sampleData['island'],
                          _sampleData['local'],
                          _sampleData['date'],
                        ].where((v) => v != null).join(' · ')),
                        trailing: OutlinedButton.icon(
                          onPressed: _openSample,
                          icon: const Icon(Icons.open_in_new, size: 16),
                          label: const Text('View Sample'),
                        ),
                      ),
                    ),

                  const SizedBox(height: 20),

                  // ── Field groups ─────────────────────────────────────
                  ..._groups.map((group) => _buildGroup(group.$1, group.$2)),
                ],
              ),
            ),
    );
  }

  Widget _buildGroup(String title, List<(String, String, bool)> fields) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  )),
              const Divider(),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (ctx, constraints) {
                  final cols = constraints.maxWidth > 800 ? 3 : constraints.maxWidth > 500 ? 2 : 1;
                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: fields.map((f) {
                      final key = f.$1;
                      final label = f.$2;
                      return SizedBox(
                        width: (constraints.maxWidth - 32) / cols - 8,
                        child: TextField(
                          controller: _ctrl[key],
                          maxLines: key == 'publications' || key == 'observations' ? 3 : 1,
                          decoration: InputDecoration(
                            labelText: label,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}