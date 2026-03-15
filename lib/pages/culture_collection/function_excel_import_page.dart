import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:flutter/scheduler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DB field lists for mapping dropdowns
// All names now match the actual DB column names (with table prefix).
// ─────────────────────────────────────────────────────────────────────────────

const _sampleDbFields = [
  '— ignore —',
  'sample_code', 'sample_rebeca', 'sample_ccpi', 'sample_permit',
  'sample_other_code', 'sample_date', 'sample_collector', 'sample_responsible',
  'sample_country', 'sample_archipelago', 'sample_island', 'sample_region',
  'sample_municipality', 'sample_parish', 'sample_local',
  'sample_gps', 'sample_latitude', 'sample_longitude', 'sample_altitude_m',
  'sample_habitat_type', 'sample_habitat_1', 'sample_habitat_2', 'sample_habitat_3',
  'sample_substrate', 'sample_method',
  'sample_temperature', 'sample_ph', 'sample_conductivity', 'sample_oxygen',
  'sample_salinity', 'sample_radiation', 'sample_turbidity', 'sample_depth_m',
  'sample_bloom', 'sample_associated_organisms',
  'sample_photos', 'sample_preservation', 'sample_transport_time_h',
  'sample_project', 'sample_observations',
];

const _strainDbFields = [
  '— ignore —',
  'strain_code', 'strain_sample_code', 'strain_origin', 'strain_status', 'strain_toxins',
  'strain_situation', 'strain_last_checked', 'strain_public',
  'strain_private_collection', 'strain_type_strain', 'strain_biosafety_level',
  'strain_access_conditions', 'strain_other_codes',
  // Taxonomy
  'strain_empire', 'strain_kingdom', 'strain_phylum',
  'strain_class', 'strain_order', 'strain_family',
  'strain_genus', 'strain_species', 'strain_subspecies', 'strain_variety',
  'strain_scientific_name', 'strain_authority', 'strain_other_names',
  'strain_taxonomist', 'strain_identification_method', 'strain_identification_date',
  // Morphology
  'strain_morphology', 'strain_cell_shape', 'strain_cell_size_um',
  'strain_motility', 'strain_pigments', 'strain_colonial_morphology',
  // Photos
  'strain_photo', 'strain_public_photo', 'strain_microscopy_photo',
  // Herbarium
  'strain_herbarium_code', 'strain_herbarium_name', 'strain_herbarium_status',
  'strain_herbarium_date', 'strain_herbarium_method', 'strain_herbarium_notes',
  // Culture maintenance
  'strain_last_transfer', 'strain_periodicity', 'strain_next_transfer',
  'strain_medium', 'strain_medium_salinity', 'strain_light_cycle',
  'strain_light_intensity_umol', 'strain_temperature_c', 'strain_co2_pct',
  'strain_aeration', 'strain_culture_vessel', 'strain_room',
  // Cryopreservation
  'strain_cryo_date', 'strain_cryo_method', 'strain_cryo_location',
  'strain_cryo_vials', 'strain_cryo_responsible',
  // Isolation
  'strain_isolation_responsible', 'strain_isolation_date',
  'strain_isolation_method', 'strain_deposit_date',
  // Molecular — prokaryotes
  'strain_seq_16s_bp', 'strain_its', 'strain_its_bands', 'strain_cloned_gel',
  'strain_genbank_16s_its', 'strain_genbank_status',
  'strain_genome_pct', 'strain_genome_cont', 'strain_genome_16s', 'strain_gca_accession',
  // Molecular — eukaryotes
  'strain_seq_18s_bp', 'strain_genbank_18s',
  'strain_its2_bp', 'strain_genbank_its2',
  'strain_rbcl_bp', 'strain_genbank_rbcl',
  'strain_tufa_bp', 'strain_genbank_tufa',
  'strain_cox1_bp', 'strain_genbank_cox1',
  // Bioactivity & references
  'strain_bioactivity', 'strain_metabolites', 'strain_industrial_use',
  'strain_growth_rate', 'strain_publications', 'strain_external_links',
  'strain_notes', 'strain_qrcode',
// Sample-linked mirror fields (read-only)
'sample_code','sample_rebeca', 'sample_ccpi', 'sample_permit',
'sample_other_code', 'sample_date', 'sample_collector', 'sample_responsible',
'sample_country', 'sample_archipelago', 'sample_island', 'sample_region',
'sample_municipality','sample_parish', 'sample_local', 'sample_gps', 'sample_latitude',
'sample_longitude', 'sample_altitude_m', 'sample_habitat_type', 'sample_habitat_1',
'sample_habitat_2', 'sample_habitat_3', 'sample_substrate', 'sample_method',
'sample_temperature', 'sample_ph', 'sample_conductivity', 'sample_oxygen',
'sample_salinity', 'sample_radiation', 'sample_turbidity', 'sample_depth_m',
'sample_bloom', 'sample_associated_organisms', 'sample_photos', 'sample_preservation',
'sample_transport_time_h', 'sample_project', 'sample_observations', 'sample_created_at',
];

// ─────────────────────────────────────────────────────────────────────────────
// Auto-mapping dictionaries  (Excel header lowercase → DB field)
// ─────────────────────────────────────────────────────────────────────────────

const Map<String, String> _sampleAutoMap = {
  'Sample Number': 'sample_code', 'no': 'sample_code', 'n': 'sample_code',
  '#': 'sample_code', 'number': 'sample_code', 'sample_code': 'sample_code',
  'rebeca': 'sample_rebeca', 'ccpi': 'sample_ccpi',
  'permit': 'sample_permit', 'collection permit': 'sample_permit',
  'data': 'sample_date', 'date': 'sample_date', 'collection date': 'sample_date',
  'collector': 'sample_collector',
  'country': 'sample_country', 'país': 'sample_country', 'pais': 'sample_country',
  'archipelago': 'sample_archipelago', 'arquipélago': 'sample_archipelago',
  'ilha': 'sample_island', 'island': 'sample_island',
  'region': 'sample_region',
  'concelho': 'sample_municipality', 'municipality': 'sample_municipality',
  'parish': 'sample_parish', 'freguesia': 'sample_parish',
  'local': 'sample_local',
  'gps': 'sample_gps',
  'latitude': 'sample_latitude', 'lat': 'sample_latitude',
  'longitude': 'sample_longitude', 'lon': 'sample_longitude', 'lng': 'sample_longitude',
  'altitude': 'sample_altitude_m', 'altitude (m)': 'sample_altitude_m',
  'habitat_type': 'sample_habitat_type', 'habitat type': 'sample_habitat_type',
  'habitat_1': 'sample_habitat_1', 'habitat 1': 'sample_habitat_1',
  'habitat_2': 'sample_habitat_2', 'habitat 2': 'sample_habitat_2',
  'habitat_3': 'sample_habitat_3', 'habitat 3': 'sample_habitat_3',
  'substrate': 'sample_substrate',
  'método': 'sample_method', 'metodo': 'sample_method', 'method': 'sample_method',
  'fotos': 'sample_photos', 'photos': 'sample_photos',
  '°c': 'sample_temperature', 'ºc': 'sample_temperature',
  'temp': 'sample_temperature', 'temperature': 'sample_temperature',
  'ph': 'sample_ph',
  'condutividade (µs/cm)': 'sample_conductivity', 'conductivity': 'sample_conductivity',
  'us/cm': 'sample_conductivity', 'µs/cm': 'sample_conductivity',
  'o2 (mg/l)': 'sample_oxygen', 'oxygen': 'sample_oxygen', 'o2': 'sample_oxygen',
  'salinidade': 'sample_salinity', 'salinity': 'sample_salinity',
  'radiação': 'sample_radiation', 'radiation': 'sample_radiation',
  'solar radiation': 'sample_radiation',
  'turbidity': 'sample_turbidity', 'turbidez': 'sample_turbidity',
  'depth': 'sample_depth_m', 'depth (m)': 'sample_depth_m',
  'bloom': 'sample_bloom',
  'preservation': 'sample_preservation',
  'project': 'sample_project', 'projeto': 'sample_project',
  'responsável': 'sample_responsible', 'responsible': 'sample_responsible',
  'sampling responsible': 'sample_responsible',
  'observações': 'sample_observations', 'observations': 'sample_observations',
};

const Map<String, String> _strainAutoMap = {
  'code': 'strain_code', 'strain code': 'strain_code',
  'origin': 'strain_origin',
  'status': 'strain_status',
  'toxins': 'strain_toxins',
  'situation': 'strain_situation',
  'last checked': 'strain_last_checked', 'lastchecked': 'strain_last_checked',
  'public': 'strain_public',
  'private collection': 'strain_private_collection',
  'typestrain': 'strain_type_strain', 'type strain': 'strain_type_strain',
  'biosafety': 'strain_biosafety_level', 'biosafety level': 'strain_biosafety_level',
  // Taxonomy
  'empire': 'strain_empire',
  'kingdom': 'strain_kingdom',
  'phylum': 'strain_phylum',
  'class': 'strain_class',
  'order': 'strain_order',
  'family': 'strain_family',
  'genus': 'strain_genus',
  'specie': 'strain_species', 'species': 'strain_species',
  'subspecies': 'strain_subspecies',
  'variety': 'strain_variety',
  'scientific name': 'strain_scientific_name', 'scientific_name': 'strain_scientific_name',
  'authority': 'strain_authority',
  'old identification': 'strain_other_names', 'old_identification': 'strain_other_names',
  'other names': 'strain_other_names',
  'photo': 'strain_photo',
  'publicphoto': 'strain_public_photo', 'public photo': 'strain_public_photo',
  'taxonomist': 'strain_taxonomist',
  // Herbarium (RTP maps)
  'ruy telles palhinha  (code)': 'strain_herbarium_code',
  'rtp code': 'strain_herbarium_code',
  'ruy telles palhinha (status)': 'strain_herbarium_status',
  'rtp status': 'strain_herbarium_status',
  // Culture maintenance
  'last transfer': 'strain_last_transfer',
  'time (days)': 'strain_periodicity', 'time days': 'strain_periodicity',
  'periodicity': 'strain_periodicity', 'cycle days': 'strain_periodicity',
  'next transfer': 'strain_next_transfer',
  'medium': 'strain_medium', 'room': 'strain_room',
  'light cycle': 'strain_light_cycle',
  'temperature c': 'strain_temperature_c', 'incubation temp': 'strain_temperature_c',
  // Isolation
  'isolation responsible': 'strain_isolation_responsible',
  'isolation date': 'strain_isolation_date',
  'isolation method': 'strain_isolation_method',
  'deposit date': 'strain_deposit_date',
  // Molecular — prokaryotes
  '16s (bp)': 'strain_seq_16s_bp', '16s': 'strain_seq_16s_bp',
  'its': 'strain_its',
  'its bands (amplified/ sequenced)': 'strain_its_bands', 'its bands': 'strain_its_bands',
  'cloned / gelextraction': 'strain_cloned_gel', 'cloned': 'strain_cloned_gel',
  'genbank (16s+its)': 'strain_genbank_16s_its',
  'genbank status': 'strain_genbank_status',
  'genome (%)': 'strain_genome_pct',
  'genome (cont.)': 'strain_genome_cont', 'genome cont': 'strain_genome_cont',
  'genome (16s)': 'strain_genome_16s',
  'gca_acession': 'strain_gca_accession', 'gca accession': 'strain_gca_accession',
  // Molecular — eukaryotes
  '18s (bp)': 'strain_seq_18s_bp', '18s': 'strain_seq_18s_bp',
  'genbank (18s)': 'strain_genbank_18s',
  'its2 (bp)': 'strain_its2_bp',
  'genbank (its2)': 'strain_genbank_its2',
  'rbcl (bp)': 'strain_rbcl_bp',
  'genbank (rbcl)': 'strain_genbank_rbcl',
  'tufa (bp)': 'strain_tufa_bp',
  'genbank (tufa)': 'strain_genbank_tufa',
  'cox1 (bp)': 'strain_cox1_bp',
  'genbank (cox1)': 'strain_genbank_cox1',
  // Bioactivity
  'bioactivity': 'strain_bioactivity',
  'metabolites': 'strain_metabolites',
  'publications': 'strain_publications',
  'qrcode': 'strain_qrcode',
  // Sample-linked columns embedded in strains sheet (mirror fields, prefixed s_)
  'sample number': 'strain_sample_code', 'sample': 'strain_sample_code',
  'sample_code': 'strain_sample_code', 'nº': 'strain_sample_code'
};

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

List<String> _detectHeaders(Sheet sheet) {
  for (final row in sheet.rows) {
    final cells = row.map((c) => c?.value?.toString().trim() ?? '').toList();
    if (cells.any((c) => c.isNotEmpty)) return cells;
  }
  return [];
}

List<Map<String, String>> _parseWithMapping(Sheet sheet, Map<int, String> colMap) {
  final rows = sheet.rows;
  if (rows.isEmpty) return [];
  int dataStartRow = 0;
  for (int i = 0; i < rows.length; i++) {
    if (rows[i].any((c) => c?.value != null)) {
      dataStartRow = i + 1;
      break;
    }
  }
  final result = <Map<String, String>>[];
  for (int r = dataStartRow; r < rows.length; r++) {
    final row = rows[r];
    final record = <String, String>{};
    for (final e in colMap.entries) {
      if (e.value == '— ignore —') continue;
      final idx = e.key;
      final val = idx < row.length ? (row[idx]?.value?.toString().trim() ?? '') : '';
      if (val.isNotEmpty) record[e.value] = val;
    }
    if (record.isNotEmpty) result.add(record);
  }
  return result;
}

String _colLetter(int index) {
  String result = '';
  int i = index;
  do {
    result = String.fromCharCode(65 + (i % 26)) + result;
    i = i ~/ 26 - 1;
  } while (i >= 0);
  return result;
}

// ─────────────────────────────────────────────────────────────────────────────
// Main wizard widget
// Steps: 0=file  1=sheets  2=columns  3=link-field  4=preview  5=importing  6=done
// ─────────────────────────────────────────────────────────────────────────────
class ExcelImportPage extends StatefulWidget {
  /// 'samples' | 'strains' | 'both'
  final String mode;
  const ExcelImportPage({super.key, required this.mode});

  @override
  State<ExcelImportPage> createState() => _ExcelImportPageState();
}

class _ExcelImportPageState extends State<ExcelImportPage> {
  int _step = 0;

  // 0 — mode selection (shown only when ExcelImportPage is opened without a
  //     fixed mode, e.g. from a generic Import button).
  // We promote mode selection to the first visible step when mode == 'both'
  // and the user hasn't explicitly chosen yet.
  late String _importMode; // 'samples' | 'strains' | 'both'

  Excel? _excel;
  String _fileName = '';
  List<String> _sheetNames = [];
  String? _selectedSampleSheet;
  String? _selectedStrainSheet;

  Map<int, String> _sampleColMap = {};
  Map<int, String> _strainColMap = {};
  List<String> _sampleHeaders = [];
  List<String> _strainHeaders = [];

  // ── Link field state ────────────────────────────────────────────────────────
  /// Which mapped field in the SAMPLE sheet is the primary key
  String _sampleLinkField = 'sample_code';

  /// Which mapped field in the STRAIN sheet contains the matching value
  String _strainLinkField = 'strain_sample_code';

  List<String> _sampleLinkSampleValues = [];
  List<String> _strainLinkSampleValues = [];

  List<Map<String, String>> _parsedSamples = [];
  List<Map<String, String>> _parsedStrains = [];

  int _mappingTab = 0;
  int _previewTab = 0;
  String _importLog = '';

  final _previewHScroll = ScrollController();
  final _previewHOffset = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    _importMode = widget.mode;
  }

  @override
  void dispose() {
    _previewHScroll.dispose();
    _previewHOffset.dispose();
    super.dispose();
  }

  // ── Step 0: pick file ───────────────────────────────────────────────────────
  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final bytes = result.files.first.bytes;
    if (bytes == null) return;

    final excel = Excel.decodeBytes(bytes);
    setState(() {
      _excel = excel;
      _fileName = result.files.first.name;
      _sheetNames = excel.tables.keys.toList();
      _step = 1;
      for (final s in _sheetNames) {
        final sl = s.toLowerCase();
        if (sl.contains('sample') || sl.contains('amostr')) _selectedSampleSheet = s;
        if (sl.contains('strain') || sl.contains('cepa') || sl.contains('cult')) _selectedStrainSheet = s;
      }
    });
  }

  // ── Step 1 → 2: detect headers and build auto-mappings ─────────────────────
  void _buildMappings() {
    _sampleColMap = {};
    _strainColMap = {};
    _sampleHeaders = [];
    _strainHeaders = [];

    final importSamples = _importMode != 'strains';
    final importStrains = _importMode != 'samples';

    if (importSamples && _selectedSampleSheet != null) {
      _sampleHeaders = _detectHeaders(_excel!.tables[_selectedSampleSheet]!);
      for (int i = 0; i < _sampleHeaders.length; i++) {
        final n = _sampleHeaders[i].toLowerCase().trim();
        _sampleColMap[i] = _sampleAutoMap[n] ?? '— ignore —';
      }
    }
    if (importStrains && _selectedStrainSheet != null) {
      _strainHeaders = _detectHeaders(_excel!.tables[_selectedStrainSheet]!);
      for (int i = 0; i < _strainHeaders.length; i++) {
        final n = _strainHeaders[i].toLowerCase().trim();
        _strainColMap[i] = _strainAutoMap[n] ?? '— ignore —';
      }
    }
    setState(() {
      _step = 2;
      _mappingTab = 0;
    });
  }

  // ── Step 2 → 3: parse with current mappings then show link-field chooser ───
  void _goToLinkStep() {
    final importSamples = _importMode != 'strains';
    final importStrains = _importMode != 'samples';

    _parsedSamples = (importSamples && _selectedSampleSheet != null)
        ? _parseWithMapping(_excel!.tables[_selectedSampleSheet]!, _sampleColMap)
        : [];
    _parsedStrains = (importStrains && _selectedStrainSheet != null)
        ? _parseWithMapping(_excel!.tables[_selectedStrainSheet]!, _strainColMap)
        : [];

    _sampleLinkSampleValues = _parsedSamples
        .map((r) => r[_sampleLinkField] ?? '')
        .where((v) => v.isNotEmpty)
        .toSet()
        .take(6)
        .toList();
    _strainLinkSampleValues = _parsedStrains
        .map((r) => r[_strainLinkField] ?? '')
        .where((v) => v.isNotEmpty)
        .toSet()
        .take(6)
        .toList();

    setState(() => _step = 3);
  }

  void _refreshLinkPreviews() {
    _sampleLinkSampleValues = _parsedSamples
        .map((r) => r[_sampleLinkField] ?? '')
        .where((v) => v.isNotEmpty)
        .toSet()
        .take(6)
        .toList();
    _strainLinkSampleValues = _parsedStrains
        .map((r) => r[_strainLinkField] ?? '')
        .where((v) => v.isNotEmpty)
        .toSet()
        .take(6)
        .toList();
    setState(() {});
  }

  void _confirmLink() => setState(() => _step = 4);

  // ── Step 4 → 5: import ─────────────────────────────────────────────────────
  Future<void> _runImport() async {
    setState(() => _step = 5);
    final sb = StringBuffer();
    final db = Supabase.instance.client;
    final importSamples = _importMode != 'strains';
    final importStrains = _importMode != 'samples';

    try {
  // ── Get next available sample number ────────────────────────────────
  // (used only for internal sequencing, not sample_code)
  int nextNumber = 1;
  final maxRes = await db
      .from('samples')
      .select('sample_code')
      .order('sample_code', ascending: false)
      .limit(1);
  if ((maxRes as List).isNotEmpty && maxRes[0]['sample_code'] != null) {
    nextNumber = (maxRes[0]['sample_code'] as num).toInt() + 1;
  }

  // ── Build sample_code → sample_id map from existing samples ───────
  final existingSamples = await db.from('samples').select('sample_code');
  final numberToId = <String, dynamic>{};
  for (final s in (existingSamples as List)) {
    final code = s['sample_code']?.toString();
    if (code != null && code.isNotEmpty) {
      numberToId[code] = s['sample_code'];
    }
  }

  // ── Import samples ─────────────────────────────────────────────────
  if (importSamples) {
    for (final sample in _parsedSamples) {
      final linkVal = sample[_sampleLinkField]?.toString();

      // If no sample_code, insert sample normally without linking
      if (linkVal == null || linkVal.isEmpty) {
        final row = _sampleRowFromMap(sample, nextNumber);
        final res = await db
            .from('samples')
            .insert(row)
            .select('sample_code')
            .single();
        sb.writeln('✓ Sample #${res['sample_code']} imported (no sample_code).');
        nextNumber++;
        continue;
      }

      // If code exists and already in DB, skip
      if (numberToId.containsKey(linkVal)) {
        sb.writeln('⚠ Sample #$linkVal already exists — skipped.');
        continue;
      }

      // Insert sample with code
      final row = _sampleRowFromMap(sample, nextNumber);
      final res = await db
          .from('samples')
          .insert(row)
          .select('sample_code')
          .single();

      numberToId[linkVal] = res['sample_code'];
      sb.writeln('✓ Sample #${res['sample_code']} (SAMPLE=$linkVal) imported.');
      nextNumber++;
    }
  }

  // ── Import strains ─────────────────────────────────────────────────
  if (importStrains) {
    for (final strain in _parsedStrains) {
      final code = strain['strain_code']?.toString() ?? '(no code)';
      dynamic sampleId;

      final linkVal = strain[_strainLinkField]?.toString();

      // If no link or empty, insert strain without sample_id
      if (linkVal == null || linkVal.isEmpty) {
        await db.from('strains').upsert(
            _strainRowFromMap(strain, null),
            onConflict: 'strain_code');
        sb.writeln('✓ Strain $code imported (no sample link).');
        continue;
      }

      // Link to sample if exists
      sampleId = numberToId[linkVal];
      if (sampleId != null) {
        await db.from('strains').upsert(
            _strainRowFromMap(strain, sampleId),
            onConflict: 'strain_code');
        sb.writeln('✓ Strain $code → Sample $sampleId imported.');
      } else {
        sb.writeln('⚠ Sample "$linkVal" not found — strain inserted without sample link.');
        await db.from('strains').upsert(
            _strainRowFromMap(strain, null),
            onConflict: 'strain_code');
      }
    }
  }

  sb.writeln('\n✅ Import complete.');
} catch (e) {
  sb.writeln('\n❌ Error in strain import: $e');
}

    setState(() {
      _importLog = sb.toString();
      _step = 6;
    });
  }

  // ── Value sanitisers ────────────────────────────────────────────────────────
  static const _emptyPlaceholders = {
    '-', '—', '–', 'n/a', 'na', 'none', 'null', '.', '/', '?', 'nd', 'n.d.', 'nd.'
  };

  String? _clean(String? raw) {
    if (raw == null) return null;
    final t = raw.trim();
    if (t.isEmpty) return null;
    if (_emptyPlaceholders.contains(t.toLowerCase())) return null;
    return t;
  }

  String? _cleanDate(String? raw) {
    final v = _clean(raw);
    if (v == null) return null;
    final iso = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    final dmy = RegExp(r'^\d{1,2}[/\-]\d{1,2}[/\-]\d{2,4}$');
    final ymd = RegExp(r'^\d{4}[/\-]\d{1,2}[/\-]\d{1,2}$');
    if (iso.hasMatch(v) || dmy.hasMatch(v) || ymd.hasMatch(v)) return v;
    return null;
  }

  double? _cleanDouble(String? raw) {
    final v = _clean(raw);
    if (v == null) return null;
    return double.tryParse(v.replaceAll(',', '.'));
  }

  int? _cleanInt(String? raw) {
    final v = _clean(raw);
    if (v == null) return null;
    return int.tryParse(v);
  }

  // ── Row builders ────────────────────────────────────────────────────────────
  Map<String, dynamic> _sampleRowFromMap(Map<String, String> m, int number) {
    return {
      'sample_code': _clean(m['sample_code']),
      'sample_rebeca': _clean(m['sample_rebeca']),
      'sample_ccpi': _clean(m['sample_ccpi']),
      'sample_permit': _clean(m['sample_permit']),
      'sample_other_code': _clean(m['sample_other_code']),
      'sample_date': _cleanDate(m['sample_date']),
      'sample_collector': _clean(m['sample_collector']),
      'sample_responsible': _clean(m['sample_responsible']),
      'sample_country': _clean(m['sample_country']),
      'sample_archipelago': _clean(m['sample_archipelago']),
      'sample_island': _clean(m['sample_island']),
      'sample_region': _clean(m['sample_region']),
      'sample_municipality': _clean(m['sample_municipality']),
      'sample_parish': _clean(m['sample_parish']),
      'sample_local': _clean(m['sample_local']),
      'sample_gps': _clean(m['sample_gps']),
      'sample_latitude': _cleanDouble(m['sample_latitude']),
      'sample_longitude': _cleanDouble(m['sample_longitude']),
      'sample_altitude_m': _cleanDouble(m['sample_altitude_m']),
      'sample_habitat_type': _clean(m['sample_habitat_type']),
      'sample_habitat_1': _clean(m['sample_habitat_1']),
      'sample_habitat_2': _clean(m['sample_habitat_2']),
      'sample_habitat_3': _clean(m['sample_habitat_3']),
      'sample_substrate': _clean(m['sample_substrate']),
      'sample_method': _clean(m['sample_method']),
      'sample_temperature': _cleanDouble(m['sample_temperature']),
      'sample_ph': _cleanDouble(m['sample_ph']),
      'sample_conductivity': _cleanDouble(m['sample_conductivity']),
      'sample_oxygen': _cleanDouble(m['sample_oxygen']),
      'sample_salinity': _cleanDouble(m['sample_salinity']),
      'sample_radiation': _cleanDouble(m['sample_radiation']),
      'sample_turbidity': _cleanDouble(m['sample_turbidity']),
      'sample_depth_m': _cleanDouble(m['sample_depth_m']),
      'sample_bloom': _clean(m['sample_bloom']),
      'sample_photos': _clean(m['sample_photos']),
      'sample_preservation': _clean(m['sample_preservation']),
      'sample_project': _clean(m['sample_project']),
      'sample_observations': _clean(m['sample_observations']),
    }..removeWhere((k, v) => v == null);
  }

  Map<String, dynamic> _strainRowFromMap(
      Map<String, String> m, dynamic sampleId) {
    return {
      'strain_sample_code': _clean( m['strain_sample_code']),
      'strain_code': _clean(m['strain_code']),
      'strain_origin': _clean(m['strain_origin']),
      'strain_status': _clean(m['strain_status']),
      'strain_toxins': _clean(m['strain_toxins']),
      'strain_situation': _clean(m['strain_situation']),
      'strain_last_checked': _cleanDate(m['strain_last_checked']),
      'strain_public': _clean(m['strain_public']),
      'strain_private_collection': _clean(m['strain_private_collection']),
      'strain_type_strain': _clean(m['strain_type_strain']),
      'strain_biosafety_level': _clean(m['strain_biosafety_level']),
      'strain_access_conditions': _clean(m['strain_access_conditions']),
      'strain_other_codes': _clean(m['strain_other_codes']),
      // Taxonomy
      'strain_empire': _clean(m['strain_empire']),
      'strain_kingdom': _clean(m['strain_kingdom']),
      'strain_phylum': _clean(m['strain_phylum']),
      'strain_class': _clean(m['strain_class']),
      'strain_order': _clean(m['strain_order']),
      'strain_family': _clean(m['strain_family']),
      'strain_genus': _clean(m['strain_genus']),
      'strain_species': _clean(m['strain_species']),
      'strain_subspecies': _clean(m['strain_subspecies']),
      'strain_variety': _clean(m['strain_variety']),
      'strain_scientific_name': _clean(m['strain_scientific_name']),
      'strain_authority': _clean(m['strain_authority']),
      'strain_other_names': _clean(m['strain_other_names']),
      'strain_taxonomist': _clean(m['strain_taxonomist']),
      'strain_identification_method': _clean(m['strain_identification_method']),
      'strain_identification_date': _cleanDate(m['strain_identification_date']),
      // Morphology
      'strain_morphology': _clean(m['strain_morphology']),
      'strain_cell_shape': _clean(m['strain_cell_shape']),
      'strain_cell_size_um': _clean(m['strain_cell_size_um']),
      'strain_motility': _clean(m['strain_motility']),
      'strain_pigments': _clean(m['strain_pigments']),
      // Photos
      'strain_photo': _clean(m['strain_photo']),
      'strain_public_photo': _clean(m['strain_public_photo']),
      'strain_microscopy_photo': _clean(m['strain_microscopy_photo']),
      // Herbarium
      'strain_herbarium_code': _clean(m['strain_herbarium_code']),
      'strain_herbarium_name': _clean(m['strain_herbarium_name']),
      'strain_herbarium_status': _clean(m['strain_herbarium_status']),
      'strain_herbarium_date': _cleanDate(m['strain_herbarium_date']),
      'strain_herbarium_method': _clean(m['strain_herbarium_method']),
      'strain_herbarium_notes': _clean(m['strain_herbarium_notes']),
      // Culture maintenance
      'strain_last_transfer': _cleanDate(m['strain_last_transfer']),
      'strain_periodicity': _cleanInt(m['strain_periodicity']),
      'strain_next_transfer': _cleanDate(m['strain_next_transfer']),
      'strain_medium': _clean(m['strain_medium']),
      'strain_medium_salinity': _clean(m['strain_medium_salinity']),
      'strain_light_cycle': _clean(m['strain_light_cycle']),
      'strain_light_intensity_umol': _cleanDouble(m['strain_light_intensity_umol']),
      'strain_temperature_c': _cleanDouble(m['strain_temperature_c']),
      'strain_co2_pct': _cleanDouble(m['strain_co2_pct']),
      'strain_aeration': _clean(m['strain_aeration']),
      'strain_culture_vessel': _clean(m['strain_culture_vessel']),
      'strain_room': _clean(m['strain_room']),
      // Cryopreservation
      'strain_cryo_date': _cleanDate(m['strain_cryo_date']),
      'strain_cryo_method': _clean(m['strain_cryo_method']),
      'strain_cryo_location': _clean(m['strain_cryo_location']),
      'strain_cryo_vials': _cleanInt(m['strain_cryo_vials']),
      'strain_cryo_responsible': _clean(m['strain_cryo_responsible']),
      // Isolation
      'strain_isolation_responsible': _clean(m['strain_isolation_responsible']),
      'strain_isolation_date': _cleanDate(m['strain_isolation_date']),
      'strain_isolation_method': _clean(m['strain_isolation_method']),
      'strain_deposit_date': _cleanDate(m['strain_deposit_date']),
      // Molecular — prokaryotes
      'strain_seq_16s_bp': _cleanInt(m['strain_seq_16s_bp']),
      'strain_its': _clean(m['strain_its']),
      'strain_its_bands': _clean(m['strain_its_bands']),
      'strain_cloned_gel': _clean(m['strain_cloned_gel']),
      'strain_genbank_16s_its': _clean(m['strain_genbank_16s_its']),
      'strain_genbank_status': _clean(m['strain_genbank_status']),
      'strain_genome_pct': _cleanDouble(m['strain_genome_pct']),
      'strain_genome_cont': _cleanInt(m['strain_genome_cont']),
      'strain_genome_16s': _clean(m['strain_genome_16s']),
      'strain_gca_accession': _clean(m['strain_gca_accession']),
      // Molecular — eukaryotes
      'strain_seq_18s_bp': _cleanInt(m['strain_seq_18s_bp']),
      'strain_genbank_18s': _clean(m['strain_genbank_18s']),
      'strain_its2_bp': _cleanInt(m['strain_its2_bp']),
      'strain_genbank_its2': _clean(m['strain_genbank_its2']),
      'strain_rbcl_bp': _cleanInt(m['strain_rbcl_bp']),
      'strain_genbank_rbcl': _clean(m['strain_genbank_rbcl']),
      'strain_tufa_bp': _cleanInt(m['strain_tufa_bp']),
      'strain_genbank_tufa': _clean(m['strain_genbank_tufa']),
      'strain_cox1_bp': _cleanInt(m['strain_cox1_bp']),
      'strain_genbank_cox1': _clean(m['strain_genbank_cox1']),
      // Bioactivity & references
      'strain_bioactivity': _clean(m['strain_bioactivity']),
      'strain_metabolites': _clean(m['strain_metabolites']),
      'strain_industrial_use': _clean(m['strain_industrial_use']),
      'strain_growth_rate': _clean(m['strain_growth_rate']),
      'strain_publications': _clean(m['strain_publications']),
      'strain_external_links': _clean(m['strain_external_links']),
      'strain_notes': _clean(m['strain_notes']),
      'strain_qrcode': _clean(m['strain_qrcode']),
    }..removeWhere((k, v) => v == null);
  }

  // ── BUILD ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    const labels = ['File', 'Sheets', 'Columns', 'Link', 'Preview', 'Import', 'Done'];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import from Excel'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(32),
          child: _StepIndicator(current: _step, labels: labels),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: [
          _buildStep0(),
          _buildStep1(),
          _buildStep2(),
          _buildStep3(),
          _buildStep4(),
          _buildStep5(),
          _buildStep6(),
        ][_step.clamp(0, 6)],
      ),
    );
  }

  // ── Step 0: pick file + choose import mode ──────────────────────────────────
  Widget _buildStep0() => Center(
        key: const ValueKey(0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.table_chart_outlined, size: 72, color: Colors.grey.shade400),
              const SizedBox(height: 20),
              const Text('Import from Excel',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Select what to import, then choose your .xlsx / .xls file.',
                  style: TextStyle(color: Colors.grey.shade600), textAlign: TextAlign.center),
              const SizedBox(height: 28),

              // ── Import mode selector ──────────────────────────────────────
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('What to import',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ),
              const SizedBox(height: 10),
              _ImportModeCard(
                mode: 'samples',
                label: 'Samples only',
                description: 'Import collection sample data — location, habitat, physical-chemical parameters.',
                icon: Icons.colorize_outlined,
                selected: _importMode == 'samples',
                onTap: () => setState(() => _importMode = 'samples'),
              ),
              const SizedBox(height: 8),
              _ImportModeCard(
                mode: 'strains',
                label: 'Strains only',
                description: 'Import strain culture data — taxonomy, maintenance, molecular.',
                icon: Icons.science_outlined,
                selected: _importMode == 'strains',
                onTap: () => setState(() => _importMode = 'strains'),
              ),
              const SizedBox(height: 8),
              _ImportModeCard(
                mode: 'both',
                label: 'Samples + Strains',
                description: 'Import both sheets from the same workbook and link them automatically.',
                icon: Icons.table_chart_outlined,
                selected: _importMode == 'both',
                onTap: () => setState(() => _importMode = 'both'),
              ),

              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.upload_file),
                label: const Text('Browse & Select File'),
              ),
            ]),
          ),
        ),
      );

  // ── Step 1: pick sheets ─────────────────────────────────────────────────────
  Widget _buildStep1() => Center(
        key: const ValueKey(1),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    const Icon(Icons.insert_drive_file_outlined),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(_fileName,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold))),
                  ]),
                  Text('${_sheetNames.length} sheet(s) found · importing: $_importMode',
                      style: TextStyle(
                          color: Colors.grey.shade600, fontSize: 13)),
                  const SizedBox(height: 24),
                  if (_importMode != 'strains') ...[
                    DropdownButtonFormField<String>(
                      initialValue: _selectedSampleSheet,
                      decoration: const InputDecoration(
                          labelText: 'Samples Sheet',
                          prefixIcon: Icon(Icons.colorize_outlined),
                          border: OutlineInputBorder()),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('— none —')),
                        ..._sheetNames.map((s) =>
                            DropdownMenuItem(value: s, child: Text(s)))
                      ],
                      onChanged: (v) =>
                          setState(() => _selectedSampleSheet = v),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_importMode != 'samples') ...[
                    DropdownButtonFormField<String>(
                      initialValue: _selectedStrainSheet,
                      decoration: const InputDecoration(
                          labelText: 'Strains Sheet',
                          prefixIcon: Icon(Icons.science_outlined),
                          border: OutlineInputBorder()),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('— none —')),
                        ..._sheetNames.map((s) =>
                            DropdownMenuItem(value: s, child: Text(s)))
                      ],
                      onChanged: (v) =>
                          setState(() => _selectedStrainSheet = v),
                    ),
                    const SizedBox(height: 16),
                  ],
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _step = 0),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back'),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: (_selectedSampleSheet != null ||
                            _selectedStrainSheet != null)
                        ? _buildMappings
                        : null,
                    icon: const Icon(Icons.table_rows_outlined),
                    label: const Text('Next — Map Columns'),
                  ),
                ]),
          ),
        ),
      );

  // ── Step 2: column mapping ──────────────────────────────────────────────────
  Widget _buildStep2() {
    final hasSamples = _sampleHeaders.isNotEmpty;
    final hasStrains = _strainHeaders.isNotEmpty;

    return Column(
      key: const ValueKey(2),
      children: [
        _actionBar(
          info: 'Verify column mappings. Amber = not auto-recognised.',
          backStep: 1,
          nextLabel: 'Next — Choose Link Field',
          onNext: _goToLinkStep,
        ),
        if (hasSamples && hasStrains)
          Material(
            child: TabBar(
              controller: TabController(length: 2, vsync: _FakeVsync()),
              onTap: (i) => setState(() => _mappingTab = i),
              tabs: [
                Tab(text: 'Samples (${_sampleHeaders.length} cols)'),
                Tab(text: 'Strains (${_strainHeaders.length} cols)'),
              ],
            ),
          ),
        Expanded(
          child: _mappingTab == 0 && hasSamples
              ? _buildMappingTable(_sampleHeaders, _sampleColMap,
                  _sampleDbFields, isSample: true)
              : hasStrains
                  ? _buildMappingTable(_strainHeaders, _strainColMap,
                      _strainDbFields, isSample: false)
                  : const Center(child: Text('No columns detected.')),
        ),
      ],
    );
  }

  Widget _buildMappingTable(List<String> headers, Map<int, String> colMap,
      List<String> dbFields, {required bool isSample}) {
    final unmapped =
        colMap.values.where((v) => v == '— ignore —').length;
    return Column(
      children: [
        if (unmapped > 0)
          Container(
            width: double.infinity,
            color: Colors.amber.shade100,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Colors.amber, size: 18),
              const SizedBox(width: 8),
              Text(
                  '$unmapped column(s) not auto-recognised — assign them or leave as ignore.',
                  style: const TextStyle(fontSize: 13)),
            ]),
          ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: headers.length,
            separatorBuilder: (_, _) =>
                const Divider(height: 1, indent: 16, endIndent: 16),
            itemBuilder: (ctx, i) {
              final header = headers[i];
              final mapped = colMap[i] ?? '— ignore —';
              final isIgnored = mapped == '— ignore —';
              return Container(
                color: isIgnored ? Colors.amber.shade50 : null,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 6),
                child: Row(children: [
                  Container(
                    width: 32,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(6)),
                    child: Text(_colLetter(i),
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                              header.isEmpty ? '(empty)' : header,
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color:
                                      header.isEmpty ? Colors.grey : null)),
                          Text('Column ${_colLetter(i)}',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500)),
                        ]),
                  ),
                  const Icon(Icons.arrow_forward,
                      size: 16, color: Colors.grey),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 4,
                    child: DropdownButtonFormField<String>(
                      initialValue:
                          dbFields.contains(mapped) ? mapped : '— ignore —',
                      isExpanded: true,
                      isDense: true,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        filled: isIgnored,
                        fillColor:
                            isIgnored ? Colors.amber.shade50 : null,
                      ),
                      items: dbFields
                          .map((f) => DropdownMenuItem(
                                value: f,
                                child: Text(f,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: f == '— ignore —'
                                            ? Colors.grey
                                            : null)),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() {
                        if (isSample) {
                          _sampleColMap[i] = v ?? '— ignore —';
                        } else {
                          _strainColMap[i] = v ?? '— ignore —';
                        }
                      }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                      isIgnored ? Icons.block : Icons.check_circle,
                      size: 18,
                      color: isIgnored
                          ? Colors.amber.shade700
                          : Colors.green),
                ]),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Step 3: link field chooser ──────────────────────────────────────────────
  Widget _buildStep3() {
    final sampleFields = _parsedSamples.isNotEmpty
        ? (_parsedSamples.expand((r) => r.keys).toSet().toList()..sort())
        : <String>[];
    final strainFields = _parsedStrains.isNotEmpty
        ? (_parsedStrains.expand((r) => r.keys).toSet().toList()..sort())
        : <String>[];

    final bothSheets =
        _parsedSamples.isNotEmpty && _parsedStrains.isNotEmpty;

    final sampleVals = _parsedSamples
        .map((r) => r[_sampleLinkField] ?? '')
        .where((v) => v.isNotEmpty)
        .toSet();
    final strainVals = _parsedStrains
        .map((r) => r[_strainLinkField] ?? '')
        .where((v) => v.isNotEmpty)
        .toSet();
    final matches = sampleVals.intersection(strainVals).length;
    final hasGoodMatch = matches > 0;

    return Column(
      key: const ValueKey(3),
      children: [
        _actionBar(
          info: 'Choose which field links strains to their sample.',
          backStep: 2,
          nextLabel: 'Next — Preview Data',
          onNext: hasGoodMatch || !bothSheets ? _confirmLink : null,
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Card(
                        color:
                            Theme.of(context).colorScheme.primaryContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Icon(Icons.link,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary),
                                  const SizedBox(width: 8),
                                  Text('Sample ↔ Strain Link Field',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onPrimaryContainer)),
                                ]),
                                const SizedBox(height: 8),
                                Text(
                                  'Select which field in each sheet shares the same value to link strains to their sample.\n'
                                  'Typically this is the Sample Code — mapped to "sample_code" in the samples sheet '
                                  'and "strain_sample_code" in the strains sheet.',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimaryContainer),
                                ),
                              ]),
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (!bothSheets)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                                'Only one sheet selected — no linking needed.'),
                          ),
                        )
                      else ...[
                        Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Row(children: [
                                            Icon(
                                                Icons.colorize_outlined,
                                                size: 18,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary),
                                            const SizedBox(width: 6),
                                            const Text('Samples sheet',
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold)),
                                          ]),
                                          const SizedBox(height: 4),
                                          Text(
                                              'Which field is the sample identifier?',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors
                                                      .grey.shade600)),
                                          const SizedBox(height: 12),
                                          DropdownButtonFormField<String>(
                                            initialValue: sampleFields
                                                    .contains(
                                                        _sampleLinkField)
                                                ? _sampleLinkField
                                                : null,
                                            isExpanded: true,
                                            decoration:
                                                const InputDecoration(
                                              labelText: 'Identifier field',
                                              border: OutlineInputBorder(),
                                            ),
                                            items: sampleFields
                                                .map((f) => DropdownMenuItem(
                                                      value: f,
                                                      child: Text(f,
                                                          style: const TextStyle(
                                                              fontSize:
                                                                  13)),
                                                    ))
                                                .toList(),
                                            onChanged: (v) {
                                              if (v == null) return;
                                              setState(() =>
                                                  _sampleLinkField = v);
                                              _refreshLinkPreviews();
                                            },
                                          ),
                                          if (_sampleLinkSampleValues
                                              .isNotEmpty) ...[
                                            const SizedBox(height: 10),
                                            Text('Sample values:',
                                                style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors
                                                        .grey.shade500)),
                                            const SizedBox(height: 4),
                                            Wrap(
                                              spacing: 4,
                                              runSpacing: 4,
                                              children:
                                                  _sampleLinkSampleValues
                                                      .map((v) => Chip(
                                                            label: Text(v,
                                                                style: const TextStyle(
                                                                    fontSize:
                                                                        11)),
                                                            visualDensity:
                                                                VisualDensity
                                                                    .compact,
                                                            padding:
                                                                EdgeInsets
                                                                    .zero,
                                                          ))
                                                      .toList(),
                                            ),
                                          ],
                                        ]),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 40),
                                child: Icon(Icons.compare_arrows,
                                    size: 32,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary),
                              ),
                              Expanded(
                                child: Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Row(children: [
                                            Icon(Icons.science_outlined,
                                                size: 18,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary),
                                            const SizedBox(width: 6),
                                            const Text('Strains sheet',
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold)),
                                          ]),
                                          const SizedBox(height: 4),
                                          Text(
                                              'Which field contains the matching sample value?',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors
                                                      .grey.shade600)),
                                          const SizedBox(height: 12),
                                          DropdownButtonFormField<String>(
                                            initialValue: strainFields
                                                    .contains(
                                                        _strainLinkField)
                                                ? _strainLinkField
                                                : null,
                                            isExpanded: true,
                                            decoration:
                                                const InputDecoration(
                                              labelText: 'Link field',
                                              border: OutlineInputBorder(),
                                            ),
                                            items: strainFields
                                                .map((f) => DropdownMenuItem(
                                                      value: f,
                                                      child: Text(f,
                                                          style: const TextStyle(
                                                              fontSize:
                                                                  13)),
                                                    ))
                                                .toList(),
                                            onChanged: (v) {
                                              if (v == null) return;
                                              setState(() =>
                                                  _strainLinkField = v);
                                              _refreshLinkPreviews();
                                            },
                                          ),
                                          if (_strainLinkSampleValues
                                              .isNotEmpty) ...[
                                            const SizedBox(height: 10),
                                            Text('Sample values:',
                                                style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors
                                                        .grey.shade500)),
                                            const SizedBox(height: 4),
                                            Wrap(
                                              spacing: 4,
                                              runSpacing: 4,
                                              children:
                                                  _strainLinkSampleValues
                                                      .map((v) => Chip(
                                                            label: Text(v,
                                                                style: const TextStyle(
                                                                    fontSize:
                                                                        11)),
                                                            visualDensity:
                                                                VisualDensity
                                                                    .compact,
                                                            padding:
                                                                EdgeInsets
                                                                    .zero,
                                                          ))
                                                      .toList(),
                                            ),
                                          ],
                                        ]),
                                  ),
                                ),
                              ),
                            ]),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: hasGoodMatch
                                ? Colors.green.shade50
                                : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: hasGoodMatch
                                    ? Colors.green.shade300
                                    : Colors.red.shade300),
                          ),
                          child: Row(children: [
                            Icon(
                                hasGoodMatch
                                    ? Icons.check_circle
                                    : Icons.warning_rounded,
                                color: hasGoodMatch
                                    ? Colors.green
                                    : Colors.red),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                hasGoodMatch
                                    ? '$matches strain(s) matched to a sample using the selected fields. '
                                        'Unmatched strains will auto-create a new sample if they carry sample data, or be left unlinked.'
                                    : 'No matches found between the two fields. Check that values share the same format (e.g. both "12", not one "12" and one "Sample 12").',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: hasGoodMatch
                                      ? Colors.green.shade800
                                      : Colors.red.shade800,
                                ),
                              ),
                            ),
                          ]),
                        ),
                      ],
                    ]),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Step 4: preview ─────────────────────────────────────────────────────────
  Widget _buildStep4() {
    final hasSamples = _parsedSamples.isNotEmpty;
    final hasStrains = _parsedStrains.isNotEmpty;
    return Column(
      key: const ValueKey(4),
      children: [
        _actionBar(
          info:
              '${_parsedSamples.length} samples · ${_parsedStrains.length} strains ready to import.',
          backStep: 3,
          nextLabel: 'Import All',
          onNext: _runImport,
          nextIcon: Icons.upload,
        ),
        if (hasSamples && hasStrains)
          Material(
            child: TabBar(
              controller: TabController(length: 2, vsync: _FakeVsync()),
              onTap: (i) => setState(() => _previewTab = i),
              tabs: [
                Tab(text: 'Samples (${_parsedSamples.length})'),
                Tab(text: 'Strains (${_parsedStrains.length})'),
              ],
            ),
          ),
        Expanded(
          child: _previewTab == 0 && hasSamples
              ? _buildPreviewGrid(_parsedSamples)
              : hasStrains
                  ? _buildPreviewGrid(_parsedStrains)
                  : const Center(child: Text('No data.')),
        ),
      ],
    );
  }

  Widget _buildPreviewGrid(List<Map<String, String>> rows) {
    if (rows.isEmpty) return const Center(child: Text('No rows.'));
    final cols = rows.expand((r) => r.keys).toSet().toList();
    final totalWidth = cols.length * 150.0;

    return Column(
      children: [
        Scrollbar(
          controller: _previewHScroll,
          thumbVisibility: true,
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              _previewHOffset.value = _previewHScroll.hasClients
                  ? _previewHScroll.offset
                  : 0;
              return false;
            },
            child: SingleChildScrollView(
              controller: _previewHScroll,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: totalWidth,
                child: Container(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  height: 38,
                  child: Row(
                      children: cols
                          .map((c) => _pCell(c, isHeader: true))
                          .toList()),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: rows.length,
            itemExtent: 34,
            itemBuilder: (ctx, i) => ValueListenableBuilder<double>(
              valueListenable: _previewHOffset,
              builder: (ctx, offset, _) => OverflowBox(
                alignment: Alignment.topLeft,
                minWidth: totalWidth,
                maxWidth: totalWidth,
                child: Transform.translate(
                  offset: Offset(-offset, 0),
                  child: SizedBox(
                    width: totalWidth,
                    child: Container(
                      color: i.isEven
                          ? Theme.of(context).colorScheme.surface
                          : Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withOpacity(0.3),
                      child: Row(
                          children: cols
                              .map((c) => _pCell(rows[i][c] ?? ''))
                              .toList()),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _pCell(String text, {bool isHeader = false}) => Container(
        width: 150,
        height: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
            border: Border(right: BorderSide(color: Colors.grey.shade200))),
        alignment: Alignment.centerLeft,
        child: Text(text,
            style: TextStyle(
                fontSize: 12,
                fontWeight:
                    isHeader ? FontWeight.bold : FontWeight.normal,
                color: isHeader
                    ? Theme.of(context).colorScheme.onPrimaryContainer
                    : null),
            overflow: TextOverflow.ellipsis),
      );

  // ── Step 5: importing ───────────────────────────────────────────────────────
  Widget _buildStep5() => const Center(
        key: ValueKey(5),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(),
          SizedBox(height: 20),
          Text('Importing…', style: TextStyle(fontSize: 16)),
        ]),
      );

  // ── Step 6: result log ──────────────────────────────────────────────────────
  Widget _buildStep6() {
    final success = _importLog.contains('✅');
    return Padding(
      key: const ValueKey(6),
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(success ? Icons.check_circle : Icons.error,
              color: success ? Colors.green : Colors.red, size: 32),
          const SizedBox(width: 12),
          Text(success ? 'Import Complete' : 'Finished with Errors',
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 16),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Text(_importLog,
                  style: const TextStyle(
                      fontFamily: 'monospace',
                      color: Colors.greenAccent,
                      fontSize: 13)),
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, true),
          icon: const Icon(Icons.check),
          label: const Text('Done — Back to Data'),
        ),
      ]),
    );
  }

  // ── Shared action bar ───────────────────────────────────────────────────────
  Widget _actionBar({
    required String info,
    required int backStep,
    required String nextLabel,
    required VoidCallback? onNext,
    IconData nextIcon = Icons.arrow_forward,
  }) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        Expanded(child: Text(info, style: const TextStyle(fontSize: 13))),
        OutlinedButton(
            onPressed: () => setState(() => _step = backStep),
            child: const Text('Back')),
        const SizedBox(width: 8),
        FilledButton.icon(
            onPressed: onNext,
            icon: Icon(nextIcon),
            label: Text(nextLabel)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Import mode selection card
// ─────────────────────────────────────────────────────────────────────────────
class _ImportModeCard extends StatelessWidget {
  final String mode;
  final String label;
  final String description;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ImportModeCard({
    required this.mode,
    required this.label,
    required this.description,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: selected
              ? primary.withOpacity(0.08)
              : const Color(0xFFF8FAFC),
          border: Border.all(
              color: selected ? primary : const Color(0xFFCBD5E1),
              width: selected ? 2 : 1),
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Icon(icon, color: selected ? primary : Colors.grey.shade500, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color:
                              selected ? primary : const Color(0xFF334155))),
                  Text(description,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600)),
                ]),
          ),
          if (selected)
            Icon(Icons.check_circle_rounded, color: primary, size: 20),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step indicator
// ─────────────────────────────────────────────────────────────────────────────
class _StepIndicator extends StatelessWidget {
  final int current;
  final List<String> labels;
  const _StepIndicator({required this.current, required this.labels});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 12, right: 12),
      child: Row(
        children: List.generate(labels.length, (i) {
          final done = i < current;
          final active = i == current;
          final color = active
              ? Theme.of(context).colorScheme.primary
              : done
                  ? Colors.green
                  : Colors.grey.shade400;
          return Expanded(
            child: Row(children: [
              if (i > 0)
                Expanded(
                    child: Container(
                        height: 2,
                        color: done ? Colors.green : Colors.grey.shade300)),
              Column(mainAxisSize: MainAxisSize.min, children: [
                CircleAvatar(
                  radius: 10,
                  backgroundColor: color,
                  child: done
                      ? const Icon(Icons.check, size: 12, color: Colors.white)
                      : Text('${i + 1}',
                          style: const TextStyle(
                              fontSize: 9,
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 2),
                Text(labels[i],
                    style: TextStyle(
                        fontSize: 9,
                        color: color,
                        fontWeight: active
                            ? FontWeight.bold
                            : FontWeight.normal)),
              ]),
            ]),
          );
        }),
      ),
    );
  }
}

class _FakeVsync implements TickerProvider {
  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);
}