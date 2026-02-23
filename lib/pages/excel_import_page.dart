import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:flutter/scheduler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DB field lists for mapping dropdowns
// ─────────────────────────────────────────────────────────────────────────────

const _sampleDbFields = [
  '— ignore —',
  'number', 'rebeca', 'ccpi', 'date', 'country', 'archipelago', 'island',
  'municipality', 'local', 'habitat_type', 'habitat_1', 'habitat_2',
  'habitat_3', 'method', 'photos', 'gps', 'temperature', 'ph',
  'conductivity', 'oxygen', 'salinity', 'radiation', 'responsible',
  'observations',
];

const _strainDbFields = [
  '— ignore —',
  'code', 'origin', 'status', 'toxins', 'situation', 'last_checked',
  'public', 'private_collection', 'type_strain',
  'empire', 'class_name', 'order_name', 'family', 'genus', 'species',
  'scientific_name', 'authority', 'old_identification', 'photo',
  'public_photo', 'taxonomist', 'rtp_code', 'rtp_status',
  'last_transfer', 'time_days', 'next_transfer', 'medium', 'room',
  'isolation_responsible', 'isolation_date', 'deposit_date', 'other_names',
  'seq_16s_bp', 'its', 'its_bands', 'cloned_gel', 'genbank_16s_its',
  'genbank_status', 'genome_pct', 'genome_cont', 'genome_16s', 'gca_accession',
  'seq_18s_bp', 'genbank_18s', 'its2_bp', 'genbank_its2', 'rbcl_bp',
  'genbank_rbcl', 'publications', 'qrcode',
  // sample-linked fields embedded in strain sheet (read-only mirrors)
  'sample_number',
  's_rebeca', 's_ccpi', 's_date', 's_country', 's_archipelago',
  's_island', 's_municipality', 's_local', 's_habitat_type', 's_habitat_1',
  's_habitat_2', 's_habitat_3', 's_method', 's_photos', 's_gps',
  's_temperature', 's_ph', 's_conductivity', 's_oxygen', 's_salinity',
  's_radiation', 's_responsible', 's_observations',
];

// ─────────────────────────────────────────────────────────────────────────────
// Auto-mapping dictionaries  (Excel header lowercase → DB field)
// ─────────────────────────────────────────────────────────────────────────────

const Map<String, String> _sampleAutoMap = {
  'nº': 'number', 'no': 'number', 'n': 'number', '#': 'number', 'number': 'number',
  'rebeca': 'rebeca', 'ccpi': 'ccpi',
  'data': 'date', 'date': 'date',
  'country': 'country', 'país': 'country', 'pais': 'country',
  'archipelago': 'archipelago', 'arquipélago': 'archipelago',
  'ilha': 'island', 'island': 'island',
  'concelho': 'municipality', 'municipality': 'municipality',
  'local': 'local',
  'habitat_type': 'habitat_type', 'habitat type': 'habitat_type',
  'habitat_1': 'habitat_1', 'habitat 1': 'habitat_1',
  'habitat_2': 'habitat_2', 'habitat 2': 'habitat_2',
  'habitat_3': 'habitat_3', 'habitat 3': 'habitat_3',
  'método': 'method', 'metodo': 'method', 'method': 'method',
  'fotos': 'photos', 'photos': 'photos', 'gps': 'gps',
  '°c': 'temperature', 'ºc': 'temperature', 'temp': 'temperature', 'temperature': 'temperature',
  'ph': 'ph',
  'condutividade (µs/cm)': 'conductivity', 'conductivity': 'conductivity',
  'us/cm': 'conductivity', 'µs/cm': 'conductivity',
  'o2 (mg/l)': 'oxygen', 'oxygen': 'oxygen', 'o2': 'oxygen',
  'salinidade': 'salinity', 'salinity': 'salinity',
  'radiação': 'radiation', 'radiation': 'radiation', 'solar radiation': 'radiation',
  'responsável': 'responsible', 'responsible': 'responsible',
  'observações': 'observations', 'observations': 'observations',
};

const Map<String, String> _strainAutoMap = {
  'code': 'code', 'origin': 'origin', 'status': 'status', 'toxins': 'toxins',
  'situation': 'situation',
  'last checked': 'last_checked', 'lastchecked': 'last_checked',
  'public': 'public', 'private collection': 'private_collection',
  'typestrain': 'type_strain', 'type strain': 'type_strain',
  'empire': 'empire', 'class': 'class_name', 'order': 'order_name',
  'family': 'family', 'genus': 'genus',
  'specie': 'species', 'species': 'species',
  'scientific name': 'scientific_name', 'authority': 'authority',
  'old identification': 'old_identification',
  'photo': 'photo', 'publicphoto': 'public_photo', 'public photo': 'public_photo',
  'taxonomist': 'taxonomist',
  'ruy telles palhinha  (code)': 'rtp_code', 'rtp code': 'rtp_code',
  'ruy telles palhinha (status)': 'rtp_status', 'rtp status': 'rtp_status',
  'last transfer': 'last_transfer',
  'time (days)': 'time_days', 'time days': 'time_days',
  'next transfer': 'next_transfer', 'medium': 'medium', 'room': 'room',
  'isolation responsible': 'isolation_responsible',
  'isolation date': 'isolation_date', 'deposit date': 'deposit_date',
  'other names': 'other_names',
  '16s (bp)': 'seq_16s_bp', '16s': 'seq_16s_bp', 'its': 'its',
  'its bands (amplified/ sequenced)': 'its_bands', 'its bands': 'its_bands',
  'cloned / gelextraction': 'cloned_gel', 'cloned': 'cloned_gel',
  'genbank (16s+its)': 'genbank_16s_its', 'genbank status': 'genbank_status',
  'genome (%)': 'genome_pct',
  'genome (cont.)': 'genome_cont', 'genome cont': 'genome_cont',
  'genome (16s)': 'genome_16s',
  'gca_acession': 'gca_accession', 'gca accession': 'gca_accession',
  '18s (bp)': 'seq_18s_bp', '18s': 'seq_18s_bp',
  'genbank (18s)': 'genbank_18s', 'its2 (bp)': 'its2_bp',
  'genbank (its2)': 'genbank_its2', 'rbcl (bp)': 'rbcl_bp',
  'genbank (rbcl)': 'genbank_rbcl',
  // sample-linked columns in strains sheet
  'sample number': 'sample_number', 'sample': 'sample_number',
  'sample_number': 'sample_number', 'nº': 'sample_number',
  'rebeca': 's_rebeca', 'sample rebeca': 's_rebeca',
  'ccpi': 's_ccpi', 'date': 's_date', 'country': 's_country',
  'archipelago': 's_archipelago', 'island': 's_island', 'ilha': 's_island',
  'municipality': 's_municipality', 'concelho': 's_municipality',
  'local': 's_local', 'habitat_type': 's_habitat_type', 'habitat type': 's_habitat_type',
  'habitat_1': 's_habitat_1', 'habitat_2': 's_habitat_2', 'habitat_3': 's_habitat_3',
  'method': 's_method', 'método': 's_method', 'photos': 's_photos', 'gps': 's_gps',
  'ºc': 's_temperature', '°c': 's_temperature',
  'ph': 's_ph', 'us/cm': 's_conductivity', 'µs/cm': 's_conductivity',
  'o2 (mg/l)': 's_oxygen', 'salinity': 's_salinity', 'solar radiation': 's_radiation',
  'sampling responsable': 's_responsible', 'sampling responsible': 's_responsible',
  'observations': 's_observations',
  'publications': 'publications', 'qrcode': 'qrcode',
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
    if (rows[i].any((c) => c?.value != null)) { dataStartRow = i + 1; break; }
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
  final String mode; // 'samples' | 'strains' | 'both'
  const ExcelImportPage({super.key, required this.mode});

  @override
  State<ExcelImportPage> createState() => _ExcelImportPageState();
}

class _ExcelImportPageState extends State<ExcelImportPage> {
  int _step = 0;

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
  // Which DB field in the SAMPLE sheet is the primary key
  String _sampleLinkField = 'number';
  // Which DB field in the STRAIN sheet contains the matching value
  String _strainLinkField = 'sample_number';
  // Preview of unique values from each side (shown for confirmation)
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

    if (_selectedSampleSheet != null) {
      _sampleHeaders = _detectHeaders(_excel!.tables[_selectedSampleSheet]!);
      for (int i = 0; i < _sampleHeaders.length; i++) {
        final n = _sampleHeaders[i].toLowerCase().trim();
        _sampleColMap[i] = _sampleAutoMap[n] ?? '— ignore —';
      }
    }
    if (_selectedStrainSheet != null) {
      _strainHeaders = _detectHeaders(_excel!.tables[_selectedStrainSheet]!);
      for (int i = 0; i < _strainHeaders.length; i++) {
        final n = _strainHeaders[i].toLowerCase().trim();
        _strainColMap[i] = _strainAutoMap[n] ?? '— ignore —';
      }
    }
    setState(() { _step = 2; _mappingTab = 0; });
  }

  // ── Step 2 → 3: parse with current mappings then show link-field chooser ───
  void _goToLinkStep() {
    // Parse both sheets now so we can show sample values for confirmation
    _parsedSamples = _selectedSampleSheet != null
        ? _parseWithMapping(_excel!.tables[_selectedSampleSheet]!, _sampleColMap)
        : [];
    _parsedStrains = _selectedStrainSheet != null
        ? _parseWithMapping(_excel!.tables[_selectedStrainSheet]!, _strainColMap)
        : [];

    // Collect the first ~6 unique values from each link field for preview
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

  // When link fields change, refresh sample values
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

  // ── Step 3 → 4: confirm link and go to preview ─────────────────────────────
  void _confirmLink() {
    setState(() => _step = 4);
  }

  // ── Step 4 → 5: import ─────────────────────────────────────────────────────
  Future<void> _runImport() async {
    setState(() => _step = 5);
    final sb = StringBuffer();
    final db = Supabase.instance.client;

    try {
      // Get next available sample number
      final maxRes = await db
          .from('samples')
          .select('number')
          .order('number', ascending: false)
          .limit(1);
      int nextNumber = 1;
      if ((maxRes as List).isNotEmpty && maxRes[0]['number'] != null) {
        nextNumber = (maxRes[0]['number'] as num).toInt() + 1;
      }

      // Build number → id map from existing samples
      final existingSamples = await db.from('samples').select('id, number');
      final numberToId = <String, dynamic>{};
      for (final s in (existingSamples as List)) {
        if (s['number'] != null) numberToId[s['number'].toString()] = s['id'];
      }

      // ── Import samples ──────────────────────────────────────────────────────
      for (final sample in _parsedSamples) {
        final linkVal = sample[_sampleLinkField]?.toString();
        if (linkVal != null && numberToId.containsKey(linkVal)) {
          sb.writeln('⚠ Sample #$linkVal already exists — skipped.');
          continue;
        }
        final row = _sampleRowFromMap(sample, nextNumber);
        final res = await db
            .from('samples')
            .insert(row)
            .select('id, number, rebeca')
            .single();
        numberToId[res['number'].toString()] = res['id'];
        sb.writeln('✓ Sample #${res['number']} (REBECA=${res['rebeca'] ?? '—'}) imported.');
        nextNumber++;
      }

      // ── Import strains ──────────────────────────────────────────────────────
      for (final strain in _parsedStrains) {
        final code = strain['code'] ?? '(no code)';
        dynamic sampleId;

        // Use only the user-chosen link field to find the sample
        final linkVal = strain[_strainLinkField]?.toString();
        if (linkVal != null && linkVal.isNotEmpty) {
          sampleId = numberToId[linkVal];
          if (sampleId == null) {
            // Sample not found by number — auto-create from embedded sample fields
            final autoSample = _autoSampleFromStrain(strain, nextNumber);
            if (autoSample.isNotEmpty) {
              final res = await db
                  .from('samples')
                  .insert(autoSample)
                  .select('id, number')
                  .single();
              sampleId = res['id'];
              numberToId[res['number'].toString()] = sampleId;
              sb.writeln('  → Auto-created Sample #${res['number']} (link value "$linkVal" not found) for strain $code.');
              nextNumber++;
            } else {
              sb.writeln('  → Sample "$linkVal" not found and no sample data available for strain $code — sample_id left null.');
            }
          }
        } else {
          // No link value at all — auto-create if sample fields present
          final autoSample = _autoSampleFromStrain(strain, nextNumber);
          if (autoSample.isNotEmpty) {
            final res = await db
                .from('samples')
                .insert(autoSample)
                .select('id, number')
                .single();
            sampleId = res['id'];
            numberToId[res['number'].toString()] = sampleId;
            sb.writeln('  → Auto-created Sample #${res['number']} (no link value) for strain $code.');
            nextNumber++;
          } else {
            sb.writeln('  → No link value and no sample data for strain $code — sample_id left null.');
          }
        }

        await db
            .from('strains')
            .upsert(_strainRowFromMap(strain, sampleId), onConflict: 'code');
        sb.writeln('✓ Strain $code → Sample ${sampleId ?? 'null'} imported.');
      }

      sb.writeln('\n✅ Import complete.');
    } catch (e) {
      sb.writeln('\n❌ Error: $e');
    }

    setState(() {
      _importLog = sb.toString();
      _step = 6;
    });
  }

  // ── Row builders ────────────────────────────────────────────────────────────
  // ── Value sanitiser ──────────────────────────────────────────────────────────
  // Converts common Excel placeholder values to null so Postgres never receives
  // "-", "—", "n/a", "na", "none", "null", "." etc. for typed columns.
  static const _emptyPlaceholders = {'-', '—', '–', 'n/a', 'na', 'none', 'null', '.', '/', '?', 'nd', 'n.d.', 'nd.'};

  /// Returns null if the value is empty or a known placeholder, otherwise the trimmed value.
  String? _clean(String? raw) {
    if (raw == null) return null;
    final t = raw.trim();
    if (t.isEmpty) return null;
    if (_emptyPlaceholders.contains(t.toLowerCase())) return null;
    return t;
  }

  /// Like _clean but also returns null if the value can't be parsed as a date
  /// (catches things like "0", "00/00/0000", etc. that would fail in Postgres).
  String? _cleanDate(String? raw) {
    final v = _clean(raw);
    if (v == null) return null;
    // Accept ISO dates (2023-04-01), dd/mm/yyyy, dd-mm-yyyy, yyyy/mm/dd
    final iso = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    final dmy = RegExp(r'^\d{1,2}[/\-]\d{1,2}[/\-]\d{2,4}$');
    final ymd = RegExp(r'^\d{4}[/\-]\d{1,2}[/\-]\d{1,2}$');
    if (iso.hasMatch(v) || dmy.hasMatch(v) || ymd.hasMatch(v)) return v;
    return null; // unrecognised format → null rather than letting Postgres fail
  }

  /// Like _clean but returns null if not parseable as a number.
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

  Map<String, dynamic> _sampleRowFromMap(Map<String, String> m, int number) {
    return {
      'number': _cleanInt(m['number']) ?? number,
      'rebeca': _clean(m['rebeca']), 'ccpi': _clean(m['ccpi']),
      'date': _cleanDate(m['date']),
      'country': _clean(m['country']), 'archipelago': _clean(m['archipelago']),
      'island': _clean(m['island']), 'municipality': _clean(m['municipality']),
      'local': _clean(m['local']),
      'habitat_type': _clean(m['habitat_type']),
      'habitat_1': _clean(m['habitat_1']), 'habitat_2': _clean(m['habitat_2']),
      'habitat_3': _clean(m['habitat_3']),
      'method': _clean(m['method']), 'photos': _clean(m['photos']),
      'gps': _clean(m['gps']),
      'temperature': _cleanDouble(m['temperature']),
      'ph': _cleanDouble(m['ph']),
      'conductivity': _cleanDouble(m['conductivity']),
      'oxygen': _cleanDouble(m['oxygen']),
      'salinity': _cleanDouble(m['salinity']),
      'radiation': _cleanDouble(m['radiation']),
      'responsible': _clean(m['responsible']),
      'observations': _clean(m['observations']),
    }..removeWhere((k, v) => v == null);
  }

  Map<String, dynamic> _autoSampleFromStrain(Map<String, String> s, int number) {
    return {
      'number': number,
      'rebeca': _clean(s['s_rebeca']), 'ccpi': _clean(s['s_ccpi']),
      'date': _cleanDate(s['s_date']),
      'country': _clean(s['s_country']), 'archipelago': _clean(s['s_archipelago']),
      'island': _clean(s['s_island']), 'municipality': _clean(s['s_municipality']),
      'local': _clean(s['s_local']), 'habitat_type': _clean(s['s_habitat_type']),
      'habitat_1': _clean(s['s_habitat_1']), 'habitat_2': _clean(s['s_habitat_2']),
      'habitat_3': _clean(s['s_habitat_3']), 'method': _clean(s['s_method']),
      'photos': _clean(s['s_photos']), 'gps': _clean(s['s_gps']),
      'temperature': _cleanDouble(s['s_temperature']),
      'ph': _cleanDouble(s['s_ph']),
      'conductivity': _cleanDouble(s['s_conductivity']),
      'oxygen': _cleanDouble(s['s_oxygen']),
      'salinity': _cleanDouble(s['s_salinity']),
      'radiation': _cleanDouble(s['s_radiation']),
      'responsible': _clean(s['s_responsible']),
      'observations': _clean(s['s_observations']),
    }..removeWhere((k, v) => v == null);
  }

  Map<String, dynamic> _strainRowFromMap(Map<String, String> m, dynamic sampleId) {
    return {
      'sample_id': sampleId,
      'code': _clean(m['code']), 'origin': _clean(m['origin']),
      'status': _clean(m['status']), 'toxins': _clean(m['toxins']),
      'situation': _clean(m['situation']),
      'last_checked': _cleanDate(m['last_checked']),
      'public': _clean(m['public']),
      'private_collection': _clean(m['private_collection']),
      'type_strain': _clean(m['type_strain']),
      'empire': _clean(m['empire']), 'class_name': _clean(m['class_name']),
      'order_name': _clean(m['order_name']), 'family': _clean(m['family']),
      'genus': _clean(m['genus']), 'species': _clean(m['species']),
      'scientific_name': _clean(m['scientific_name']),
      'authority': _clean(m['authority']),
      'old_identification': _clean(m['old_identification']),
      'photo': _clean(m['photo']), 'public_photo': _clean(m['public_photo']),
      'taxonomist': _clean(m['taxonomist']),
      'rtp_code': _clean(m['rtp_code']), 'rtp_status': _clean(m['rtp_status']),
      'last_transfer': _cleanDate(m['last_transfer']),
      'time_days': _cleanInt(m['time_days']),
      'next_transfer': _cleanDate(m['next_transfer']),
      'medium': _clean(m['medium']), 'room': _clean(m['room']),
      'isolation_responsible': _clean(m['isolation_responsible']),
      'isolation_date': _cleanDate(m['isolation_date']),
      'deposit_date': _cleanDate(m['deposit_date']),
      'other_names': _clean(m['other_names']),
      'seq_16s_bp': _cleanInt(m['seq_16s_bp']),
      'its': _clean(m['its']), 'its_bands': _clean(m['its_bands']),
      'cloned_gel': _clean(m['cloned_gel']),
      'genbank_16s_its': _clean(m['genbank_16s_its']),
      'genbank_status': _clean(m['genbank_status']),
      'genome_pct': _cleanDouble(m['genome_pct']),
      'genome_cont': _cleanInt(m['genome_cont']),
      'genome_16s': _clean(m['genome_16s']),
      'gca_accession': _clean(m['gca_accession']),
      'seq_18s_bp': _cleanInt(m['seq_18s_bp']),
      'genbank_18s': _clean(m['genbank_18s']),
      'its2_bp': _cleanInt(m['its2_bp']),
      'genbank_its2': _clean(m['genbank_its2']),
      'rbcl_bp': _cleanInt(m['rbcl_bp']),
      'genbank_rbcl': _clean(m['genbank_rbcl']),
      'publications': _clean(m['publications']),
      'qrcode': _clean(m['qrcode']),
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

  // ── Step 0: pick file ───────────────────────────────────────────────────────
  Widget _buildStep0() => Center(
        key: const ValueKey(0),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.table_chart_outlined, size: 72, color: Colors.grey.shade400),
          const SizedBox(height: 20),
          const Text('Select Excel File', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Accepts .xlsx or .xls', style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 32),
          FilledButton.icon(onPressed: _pickFile, icon: const Icon(Icons.upload_file), label: const Text('Browse')),
        ]),
      );

  // ── Step 1: pick sheets ─────────────────────────────────────────────────────
  Widget _buildStep1() => Center(
        key: const ValueKey(1),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                const Icon(Icons.insert_drive_file_outlined),
                const SizedBox(width: 8),
                Expanded(child: Text(_fileName, style: const TextStyle(fontWeight: FontWeight.bold))),
              ]),
              Text('${_sheetNames.length} sheet(s) found', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              const SizedBox(height: 24),
              if (widget.mode != 'strains') ...[
                DropdownButtonFormField<String>(
                  initialValue: _selectedSampleSheet,
                  decoration: const InputDecoration(labelText: 'Samples Sheet', prefixIcon: Icon(Icons.colorize_outlined), border: OutlineInputBorder()),
                  items: [const DropdownMenuItem(value: null, child: Text('— none —')), ..._sheetNames.map((s) => DropdownMenuItem(value: s, child: Text(s)))],
                  onChanged: (v) => setState(() => _selectedSampleSheet = v),
                ),
                const SizedBox(height: 16),
              ],
              if (widget.mode != 'samples') ...[
                DropdownButtonFormField<String>(
                  initialValue: _selectedStrainSheet,
                  decoration: const InputDecoration(labelText: 'Strains Sheet', prefixIcon: Icon(Icons.science_outlined), border: OutlineInputBorder()),
                  items: [const DropdownMenuItem(value: null, child: Text('— none —')), ..._sheetNames.map((s) => DropdownMenuItem(value: s, child: Text(s)))],
                  onChanged: (v) => setState(() => _selectedStrainSheet = v),
                ),
                const SizedBox(height: 16),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: (_selectedSampleSheet != null || _selectedStrainSheet != null) ? _buildMappings : null,
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
              ? _buildMappingTable(_sampleHeaders, _sampleColMap, _sampleDbFields, isSample: true)
              : hasStrains
                  ? _buildMappingTable(_strainHeaders, _strainColMap, _strainDbFields, isSample: false)
                  : const Center(child: Text('No columns detected.')),
        ),
      ],
    );
  }

  Widget _buildMappingTable(List<String> headers, Map<int, String> colMap, List<String> dbFields, {required bool isSample}) {
    final unmapped = colMap.values.where((v) => v == '— ignore —').length;
    return Column(
      children: [
        if (unmapped > 0)
          Container(
            width: double.infinity,
            color: Colors.amber.shade100,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 18),
              const SizedBox(width: 8),
              Text('$unmapped column(s) not auto-recognised — assign them or leave as ignore.',
                  style: const TextStyle(fontSize: 13)),
            ]),
          ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: headers.length,
            separatorBuilder: (_, _) => const Divider(height: 1, indent: 16, endIndent: 16),
            itemBuilder: (ctx, i) {
              final header = headers[i];
              final mapped = colMap[i] ?? '— ignore —';
              final isIgnored = mapped == '— ignore —';
              return Container(
                color: isIgnored ? Colors.amber.shade50 : null,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(children: [
                  Container(
                    width: 32, height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(6)),
                    child: Text(_colLetter(i), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text(header.isEmpty ? '(empty)' : header,
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: header.isEmpty ? Colors.grey : null)),
                      Text('Column ${_colLetter(i)}', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                    ]),
                  ),
                  const Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 4,
                    child: DropdownButtonFormField<String>(
                      initialValue: dbFields.contains(mapped) ? mapped : '— ignore —',
                      isExpanded: true,
                      isDense: true,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        filled: isIgnored,
                        fillColor: isIgnored ? Colors.amber.shade50 : null,
                      ),
                      items: dbFields.map((f) => DropdownMenuItem(
                        value: f,
                        child: Text(f, style: TextStyle(fontSize: 12, color: f == '— ignore —' ? Colors.grey : null)),
                      )).toList(),
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
                  Icon(isIgnored ? Icons.block : Icons.check_circle,
                      size: 18, color: isIgnored ? Colors.amber.shade700 : Colors.green),
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
    // Fields available from each parsed sheet (only mapped ones, not ignored)
    final sampleFields = _parsedSamples.isNotEmpty
        ? (_parsedSamples.expand((r) => r.keys).toSet().toList()..sort())
        : <String>[];
    final strainFields = _parsedStrains.isNotEmpty
        ? (_parsedStrains.expand((r) => r.keys).toSet().toList()..sort())
        : <String>[];

    final bothSheets = _parsedSamples.isNotEmpty && _parsedStrains.isNotEmpty;

    // Check if the selected fields actually have overlapping values
    final sampleVals = _parsedSamples.map((r) => r[_sampleLinkField] ?? '').where((v) => v.isNotEmpty).toSet();
    final strainVals = _parsedStrains.map((r) => r[_strainLinkField] ?? '').where((v) => v.isNotEmpty).toSet();
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
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

                  // ── Explanation card ──────────────────────────────────────
                  Card(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Icon(Icons.link, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 8),
                          Text('Sample ↔ Strain Link Field',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15,
                                  color: Theme.of(context).colorScheme.onPrimaryContainer)),
                        ]),
                        const SizedBox(height: 8),
                        Text(
                          'Select which field in each sheet shares the same value to link strains to their sample.\n'
                          'Typically this is the Sample Number — the field labelled "Nº" or "number" in the samples sheet '
                          'and "Sample" or "Sample Number" in the strains sheet.',
                          style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onPrimaryContainer),
                        ),
                      ]),
                    ),
                  ),

                  const SizedBox(height: 24),

                  if (!bothSheets)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Only one sheet selected — no linking needed.'),
                      ),
                    )
                  else ...[

                    // ── Two-column picker ─────────────────────────────────
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [

                      // Samples side
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                              Row(children: [
                                Icon(Icons.colorize_outlined, size: 18,
                                    color: Theme.of(context).colorScheme.primary),
                                const SizedBox(width: 6),
                                const Text('Samples sheet', style: TextStyle(fontWeight: FontWeight.bold)),
                              ]),
                              const SizedBox(height: 4),
                              Text('Which field is the sample identifier?',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                initialValue: sampleFields.contains(_sampleLinkField) ? _sampleLinkField : null,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Identifier field',
                                  border: OutlineInputBorder(),
                                ),
                                items: sampleFields.map((f) => DropdownMenuItem(
                                  value: f,
                                  child: Text(f, style: const TextStyle(fontSize: 13)),
                                )).toList(),
                                onChanged: (v) {
                                  if (v == null) return;
                                  setState(() => _sampleLinkField = v);
                                  _refreshLinkPreviews();
                                },
                              ),
                              if (_sampleLinkSampleValues.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text('Sample values:', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 4, runSpacing: 4,
                                  children: _sampleLinkSampleValues.map((v) => Chip(
                                    label: Text(v, style: const TextStyle(fontSize: 11)),
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                  )).toList(),
                                ),
                              ],
                            ]),
                          ),
                        ),
                      ),

                      // Arrow
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 40),
                        child: Icon(Icons.compare_arrows, size: 32, color: Theme.of(context).colorScheme.primary),
                      ),

                      // Strains side
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                              Row(children: [
                                Icon(Icons.science_outlined, size: 18,
                                    color: Theme.of(context).colorScheme.primary),
                                const SizedBox(width: 6),
                                const Text('Strains sheet', style: TextStyle(fontWeight: FontWeight.bold)),
                              ]),
                              const SizedBox(height: 4),
                              Text('Which field contains the matching sample value?',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                initialValue: strainFields.contains(_strainLinkField) ? _strainLinkField : null,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Link field',
                                  border: OutlineInputBorder(),
                                ),
                                items: strainFields.map((f) => DropdownMenuItem(
                                  value: f,
                                  child: Text(f, style: const TextStyle(fontSize: 13)),
                                )).toList(),
                                onChanged: (v) {
                                  if (v == null) return;
                                  setState(() => _strainLinkField = v);
                                  _refreshLinkPreviews();
                                },
                              ),
                              if (_strainLinkSampleValues.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text('Sample values:', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 4, runSpacing: 4,
                                  children: _strainLinkSampleValues.map((v) => Chip(
                                    label: Text(v, style: const TextStyle(fontSize: 11)),
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                  )).toList(),
                                ),
                              ],
                            ]),
                          ),
                        ),
                      ),
                    ]),

                    const SizedBox(height: 20),

                    // ── Match result banner ───────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: hasGoodMatch ? Colors.green.shade50 : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: hasGoodMatch ? Colors.green.shade300 : Colors.red.shade300),
                      ),
                      child: Row(children: [
                        Icon(hasGoodMatch ? Icons.check_circle : Icons.warning_rounded,
                            color: hasGoodMatch ? Colors.green : Colors.red),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            hasGoodMatch
                                ? '$matches strain(s) matched to a sample using the selected fields. '
                                  'Unmatched strains will auto-create a new sample if they have sample data, or be left unlinked.'
                                : 'No matches found between the two fields. Check that the values are the same format (e.g. both "12" not one "12" and one "Sample 12").',
                            style: TextStyle(
                              fontSize: 13,
                              color: hasGoodMatch ? Colors.green.shade800 : Colors.red.shade800,
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
          info: '${_parsedSamples.length} samples · ${_parsedStrains.length} strains ready to import.',
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
              tabs: [Tab(text: 'Samples (${_parsedSamples.length})'), Tab(text: 'Strains (${_parsedStrains.length})')],
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
              _previewHOffset.value =
                  _previewHScroll.hasClients ? _previewHScroll.offset : 0;
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
                  child: Row(children: cols.map((c) => _pCell(c, isHeader: true)).toList()),
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
                          : Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                      child: Row(children: cols.map((c) => _pCell(rows[i][c] ?? '')).toList()),
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
        width: 150, height: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.grey.shade200))),
        alignment: Alignment.centerLeft,
        child: Text(text,
            style: TextStyle(fontSize: 12, fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
                color: isHeader ? Theme.of(context).colorScheme.onPrimaryContainer : null),
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
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 16),
        Expanded(
          child: Container(
            decoration: BoxDecoration(color: Colors.grey.shade900, borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Text(_importLog,
                  style: const TextStyle(fontFamily: 'monospace', color: Colors.greenAccent, fontSize: 13)),
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
        OutlinedButton(onPressed: () => setState(() => _step = backStep), child: const Text('Back')),
        const SizedBox(width: 8),
        FilledButton.icon(onPressed: onNext, icon: Icon(nextIcon), label: Text(nextLabel)),
      ]),
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
              : done ? Colors.green : Colors.grey.shade400;
          return Expanded(
            child: Row(children: [
              if (i > 0) Expanded(child: Container(height: 2, color: done ? Colors.green : Colors.grey.shade300)),
              Column(mainAxisSize: MainAxisSize.min, children: [
                CircleAvatar(
                  radius: 10, backgroundColor: color,
                  child: done
                      ? const Icon(Icons.check, size: 12, color: Colors.white)
                      : Text('${i + 1}', style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 2),
                Text(labels[i], style: TextStyle(fontSize: 9, color: color, fontWeight: active ? FontWeight.bold : FontWeight.normal)),
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