import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../strains/strains_page.dart';

class SampleDetailPage extends StatefulWidget {
  final dynamic sampleId;
  final VoidCallback? onSaved;

  const SampleDetailPage({super.key, required this.sampleId, this.onSaved});

  @override
  State<SampleDetailPage> createState() => _SampleDetailPageState();
}

class _SampleDetailPageState extends State<SampleDetailPage> {
  final supabase = Supabase.instance.client;

  Map<String, dynamic> _data = {};
  List<Map<String, dynamic>> _strains = [];

  bool _loading = true;
  bool _saving = false;

  final Map<String, TextEditingController> _ctrl = {};

  // ───────────────────────── FIELD MODEL ─────────────────────────

  static const _fields = <Field>[
    Field('number', 'Nº', false),
    Field('rebeca', 'REBECA', true),
    Field('ccpi', 'CCPI', true),
    Field('date', 'Date', true),
    Field('country', 'Country', true),
    Field('archipelago', 'Archipelago', true),
    Field('island', 'Island', true),
    Field('municipality', 'Municipality', true),
    Field('local', 'Local', true),
    Field('habitat_type', 'Habitat Type', true),
    Field('habitat_1', 'Habitat 1', true),
    Field('habitat_2', 'Habitat 2', true),
    Field('habitat_3', 'Habitat 3', true),
    Field('method', 'Method', true),
    Field('photos', 'Photos', true),
    Field('gps', 'GPS', true),
    Field('temperature', '°C', true),
    Field('ph', 'pH', true),
    Field('conductivity', 'Conductivity (µS/cm)', true),
    Field('oxygen', 'O₂ (mg/L)', true),
    Field('salinity', 'Salinity', true),
    Field('radiation', 'Solar Radiation', true),
    Field('responsible', 'Responsible', true),
    Field('observations', 'Observations', true),
  ];

  // ───────────────────────── LIFECYCLE ─────────────────────────

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

  // ───────────────────────── DATA LOAD ─────────────────────────

  Future<void> _load() async {
    if (!mounted) return;

    setState(() => _loading = true);

    try {
      final sample = await supabase
          .from('samples')
          .select()
          .eq('id', widget.sampleId)
          .single();

      final strains = await supabase
          .from('strains')
          .select('id, code, status, genus, species')
          .eq('sample_id', widget.sampleId)
          .order('code');

      if (!mounted) return;

      _data = Map<String, dynamic>.from(sample);
      _strains = List<Map<String, dynamic>>.from(strains);

      _initControllers();
    } catch (e) {
      _snack('Error loading sample: $e');
    }

    if (mounted) setState(() => _loading = false);
  }

  void _initControllers() {
    for (final f in _fields) {
      _ctrl.putIfAbsent(
        f.key,
        () => TextEditingController(),
      );

      _ctrl[f.key]!.text = _data[f.key]?.toString() ?? '';
    }
  }

  // ───────────────────────── SAVE ─────────────────────────

  Future<void> _save() async {
    setState(() => _saving = true);

    try {
      final update = <String, dynamic>{};

      for (final f in _fields) {
        if (f.editable) {
          final text = _ctrl[f.key]!.text.trim();
          update[f.key] = text.isEmpty ? null : text;
        }
      }

      await supabase.from('samples').update(update).eq('id', widget.sampleId);

      widget.onSaved?.call();
      _snack('Saved successfully.');
    } catch (e) {
      _snack('Save error: $e');
    }

    if (mounted) setState(() => _saving = false);
  }

  // ───────────────────────── NAVIGATION ─────────────────────────

  Future<void> _openStrains() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StrainsPage(filterSampleId: widget.sampleId),
      ),
    );

    _load();
  }

  Future<void> _addStrain() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StrainsPage(
          filterSampleId: widget.sampleId,
          autoOpenNewStrainForSample: widget.sampleId,
        ),
      ),
    );

    _load();
  }

  // ───────────────────────── UI HELPERS ─────────────────────────

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  int _columns(double width) {
    if (width > 1100) return 4;
    if (width > 800) return 3;
    if (width > 500) return 2;
    return 1;
  }

  // ───────────────────────── BUILD ─────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _data['rebeca'] != null
              ? 'Sample: ${_data['rebeca']}'
              : 'Sample Detail',
        ),
        actions: [
          if (!_loading)
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
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
                  _buildFieldsCard(),
                  const SizedBox(height: 24),
                  _buildStrainsSection(),
                ],
              ),
            ),
    );
  }

  // ───────────────────────── WIDGETS ─────────────────────────

  Widget _buildFieldsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, c) {
            final cols = _columns(c.maxWidth);
            final itemWidth = (c.maxWidth - (cols - 1) * 16) / cols;

            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: _fields.map((f) {
                return SizedBox(
                  width: itemWidth,
                  child: TextField(
                    controller: _ctrl[f.key],
                    readOnly: !f.editable,
                    maxLines: f.key == 'observations' ? 3 : 1,
                    decoration: InputDecoration(
                      labelText: f.label,
                      border: const OutlineInputBorder(),
                      filled: !f.editable,
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStrainsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Strains from this Sample',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: _addStrain,
              icon: const Icon(Icons.add),
              label: const Text('Add Strain'),
            ),
            const SizedBox(width: 8),
            if (_strains.isNotEmpty)
              OutlinedButton.icon(
                onPressed: _openStrains,
                icon: const Icon(Icons.open_in_new),
                label: const Text('View All Strains'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_strains.isEmpty)
          _emptyStrains()
        else
          _strainsList(),
      ],
    );
  }

  Widget _emptyStrains() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.grey),
            SizedBox(width: 8),
            Text('No strains yet. Add the first strain from this sample.'),
          ],
        ),
      );

  Widget _strainsList() => Card(
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _strains.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final s = _strains[i];

            return ListTile(
              leading: const Icon(Icons.science_outlined),
              title: Text(s['code'] ?? 'No code'),
              subtitle: Text(
                [s['genus'], s['species']]
                    .where((e) => e != null)
                    .join(' '),
              ),
              trailing: Chip(label: Text(s['status'] ?? 'unknown')),
              onTap: _openStrains,
            );
          },
        ),
      );
}

// ───────────────────────── FIELD CLASS ─────────────────────────

class Field {
  final String key;
  final String label;
  final bool editable;

  const Field(this.key, this.label, this.editable);
}