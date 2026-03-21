// printing_page.dart - Label designer and printer driver integration.
// Defines shared types: LabelField, LabelTemplate, PrinterConfig, _ConnState.
// Part files: printing_driver (ZPL/QL/USB), printing_builder_page (_BuilderTab),
// printing_builder_widgets (builder helpers), printing_widgets (templates UI,
// print dialog), printer_settings_page, templates_dialog, printing_db_field_picker.


import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/theme/theme.dart';

part 'printing_builder_page.dart';
part 'printer_settings_page.dart';
part 'templates_dialog.dart';
part 'printing_db_field_picker.dart';
part 'printing_driver.dart';
part 'printing_widgets.dart';
part 'printing_builder_widgets.dart';

const _kPaperSizes = ['62x30', '62x100', '62x29', '29x90', '38x90', '54x29'];

/// Printer reachability states — finer-grained than a simple bool so we can
/// distinguish "driver installed but printer offline/not connected" from
/// "actually ready to print".
enum _ConnState { checking, connected, driverOnly, unreachable }

/// Drag-and-drop payload: a DB field chip dragged from the fields panel onto the canvas.
typedef _FieldSpec = ({String key, String label, LabelFieldType type, bool isPlaceholder});

// ─────────────────────────────────────────────────────────────────────────────
// Data models
// ─────────────────────────────────────────────────────────────────────────────

enum LabelFieldType { text, barcode, qrcode, divider, image }

class LabelField {
  final String id;
  LabelFieldType type;
  String content;      // static text OR field key like '{strain_code}'
  double x, y, w, h;
  double fontSize;
  FontWeight fontWeight;
  TextAlign textAlign;
  Color color;
  bool isPlaceholder;  // true = bound to a real DB field

  LabelField({
    required this.id,
    required this.type,
    required this.content,
    this.x = 10,
    this.y = 10,
    this.w = 120,
    this.h = 20,
    this.fontSize = 10,
    this.fontWeight = FontWeight.normal,
    this.textAlign = TextAlign.left,
    this.color = Colors.black,
    this.isPlaceholder = false,
  });

  LabelField copyWith({
    LabelFieldType? type,
    String? content,
    double? x, double? y, double? w, double? h,
    double? fontSize,
    FontWeight? fontWeight,
    TextAlign? textAlign,
    Color? color,
    bool? isPlaceholder,
  }) {
    return LabelField(
      id: id,
      type: type ?? this.type,
      content: content ?? this.content,
      x: x ?? this.x, y: y ?? this.y, w: w ?? this.w, h: h ?? this.h,
      fontSize: fontSize ?? this.fontSize,
      fontWeight: fontWeight ?? this.fontWeight,
      textAlign: textAlign ?? this.textAlign,
      color: color ?? this.color,
      isPlaceholder: isPlaceholder ?? this.isPlaceholder,
    );
  }

  // FontWeight index → instance (w100=0 … w900=8)
  static const _kFontWeights = [
    FontWeight.w100, FontWeight.w200, FontWeight.w300, FontWeight.w400,
    FontWeight.w500, FontWeight.w600, FontWeight.w700, FontWeight.w800, FontWeight.w900,
  ];

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'content': content,
    'x': x, 'y': y, 'w': w, 'h': h,
    'fontSize': fontSize,
    'fontWeight': _kFontWeights.indexOf(fontWeight).clamp(0, 8),
    'textAlign': textAlign.index,
    'color': color.toARGB32(),
    'isPlaceholder': isPlaceholder,
  };

  factory LabelField.fromJson(Map<String, dynamic> j) => LabelField(
    id: j['id'] as String,
    type: LabelFieldType.values.firstWhere((e) => e.name == j['type'],
        orElse: () => LabelFieldType.text),
    content: j['content'] as String? ?? '',
    x: (j['x'] as num).toDouble(),
    y: (j['y'] as num).toDouble(),
    w: (j['w'] as num).toDouble(),
    h: (j['h'] as num).toDouble(),
    fontSize: (j['fontSize'] as num).toDouble(),
    fontWeight: LabelField._kFontWeights[((j['fontWeight'] as int?) ?? 3).clamp(0, 8)],
    textAlign: TextAlign.values[((j['textAlign'] as int?) ?? 0).clamp(0, TextAlign.values.length - 1)],
    color: Color((j['color'] as int?) ?? 0xFF000000),
    isPlaceholder: j['isPlaceholder'] as bool? ?? false,
  );
}

class LabelTemplate {
  String id;
  String name;
  String category;     // 'Strains' | 'Reagents' | 'Equipment' | 'Samples' | 'General'
  double labelW;       // mm
  double labelH;       // mm
  List<LabelField> fields;
  // Per-template print settings
  String paperSize;    // '62x30' | '62x100' etc.
  int dpi;             // 300 | 600
  bool autoCut;
  bool halfCut;
  bool rotate;         // 90°
  bool continuousRoll; // true = continuous roll, false = pre-sized die-cut labels
  int copies;

  LabelTemplate({
    required this.id,
    required this.name,
    this.category = 'General',
    this.labelW = 62,
    this.labelH = 30,
    List<LabelField>? fields,
    this.paperSize = '62x30',
    this.dpi = 300,
    this.autoCut = true,
    this.halfCut = false,
    this.rotate = false,
    this.continuousRoll = true,
    this.copies = 1,
  }) : fields = fields ?? [];

  LabelTemplate clone() => LabelTemplate(
    id: id, name: name, category: category, labelW: labelW, labelH: labelH,
    fields: fields.map((f) => f.copyWith()).toList(),
    paperSize: paperSize, dpi: dpi, autoCut: autoCut,
    halfCut: halfCut, rotate: rotate, continuousRoll: continuousRoll, copies: copies,
  );

  Map<String, dynamic> toDb() => {
    'tpl_id': id,
    'tpl_name': name,
    'tpl_category': category,
    'tpl_label_w': labelW,
    'tpl_label_h': labelH,
    'tpl_paper_size': paperSize,
    'tpl_dpi': dpi,
    'tpl_auto_cut': autoCut,
    'tpl_half_cut': halfCut,
    'tpl_rotate': rotate,
    'tpl_continuous_roll': continuousRoll,
    'tpl_copies': copies,
    'tpl_fields': fields.map((f) => f.toJson()).toList(),
    'tpl_updated_at': DateTime.now().toUtc().toIso8601String(),
  };

  factory LabelTemplate.fromDb(Map<String, dynamic> row) {
    final rawFields = row['tpl_fields'] as List<dynamic>? ?? [];
    return LabelTemplate(
      id: row['tpl_id'] as String,
      name: row['tpl_name'] as String,
      category: row['tpl_category'] as String? ?? 'General',
      labelW: (row['tpl_label_w'] as num?)?.toDouble() ?? 62,
      labelH: (row['tpl_label_h'] as num?)?.toDouble() ?? 30,
      paperSize: row['tpl_paper_size'] as String? ?? '62x30',
      dpi: row['tpl_dpi'] as int? ?? 300,
      autoCut: row['tpl_auto_cut'] as bool? ?? true,
      halfCut: row['tpl_half_cut'] as bool? ?? false,
      rotate: row['tpl_rotate'] as bool? ?? false,
      continuousRoll: row['tpl_continuous_roll'] as bool? ?? true,
      copies: row['tpl_copies'] as int? ?? 1,
      fields: rawFields
          .whereType<Map<String, dynamic>>()
          .map(LabelField.fromJson)
          .toList(),
    );
  }
}

class PrinterConfig {
  String protocol;         // 'zpl' | 'brother_ql' | 'brother_ql_legacy'
  String connectionType;   // 'usb' | 'wifi' | 'bluetooth'
  String deviceName;
  String ipAddress;
  String usbPath;          // '/dev/usb/lp0' on Linux/macOS, printer name on Windows

  PrinterConfig({
    this.protocol = 'zpl',
    this.connectionType = 'usb',
    this.deviceName = 'Zebra ZD421',
    this.ipAddress = '192.168.1.100',
    this.usbPath = '/dev/usb/lp0',
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Available fields by category
// ─────────────────────────────────────────────────────────────────────────────

const _kFieldsByCategory = <String, List<({String key, String label})>>{
  'Strains': [
    (key: '{strain_qrcode}',        label: 'QR Code'),
    (key: '{strain_code}',          label: 'Strain Code'),
    (key: '{strain_status}',        label: 'Status'),
    (key: '{strain_species}',       label: 'Species'),
    (key: '{strain_genus}',         label: 'Genus'),
    (key: '{strain_medium}',        label: 'Medium'),
    (key: '{strain_room}',          label: 'Room'),
    (key: '{strain_next_transfer}', label: 'Next Transfer'),
    (key: '{s_island}',             label: 'Island (Origin)'),
    (key: '{s_country}',            label: 'Country'),
  ],
  'Reagents': [
    (key: '{reagent_qrcode}',        label: 'QR Code'),
    (key: '{reagent_code}',          label: 'Reagent Code'),
    (key: '{reagent_name}',          label: 'Name'),
    (key: '{reagent_lot}',           label: 'Lot Number'),
    (key: '{reagent_expiry}',        label: 'Expiry Date'),
    (key: '{reagent_supplier}',      label: 'Supplier'),
    (key: '{reagent_location}',      label: 'Storage Location'),
    (key: '{reagent_concentration}', label: 'Concentration'),
  ],
  'Equipment': [
    (key: '{equipment_qrcode}',    label: 'QR Code'),
    (key: '{eq_code}',             label: 'Equipment Code'),
    (key: '{eq_name}',             label: 'Name'),
    (key: '{eq_serial}',           label: 'Serial Number'),
    (key: '{eq_location}',         label: 'Location'),
    (key: '{eq_calibration_due}',  label: 'Calibration Due'),
    (key: '{eq_status}',           label: 'Status'),
  ],
  'Samples': [
    (key: '{sample_code}',    label: 'Sample Code'),
    (key: '{sample_type}',    label: 'Sample Type'),
    (key: '{sample_date}',    label: 'Collection Date'),
    (key: '{sample_origin}',  label: 'Origin'),
    (key: '{sample_storage}', label: 'Storage'),
    (key: '{sample_status}',  label: 'Status'),
  ],
  'Stocks': [
    (key: '{fish_stocks_tank_id}',      label: 'Tank ID'),
    (key: '{fish_stocks_line}',         label: 'Line'),
    (key: '{fish_stocks_males}',        label: 'Males'),
    (key: '{fish_stocks_females}',      label: 'Females'),
    (key: '{fish_stocks_juveniles}',    label: 'Juveniles'),
    (key: '{fish_stocks_status}',       label: 'Status'),
    (key: '{fish_stocks_responsible}',  label: 'Responsible'),
    (key: '{fish_stocks_arrival_date}', label: 'Arrival Date'),
  ],
  'General': [
    (key: '{code}',  label: 'Code'),
    (key: '{name}',  label: 'Name'),
    (key: '{date}',  label: 'Date'),
    (key: '{notes}', label: 'Notes'),
  ],
};

List<({String key, String label})> _fieldsForCategory(String category) =>
    _kFieldsByCategory[category] ?? _kFieldsByCategory['General']!;

// ─────────────────────────────────────────────────────────────────────────────
// Complete printable columns per category (derived from core_tables_sql schema).
// Excludes PKs, FKs, timestamps, photo-URL, and boolean-only columns.
// ─────────────────────────────────────────────────────────────────────────────
const _kAllColsByCategory = <String, List<String>>{
  'Strains': [
    'strain_qrcode', 'strain_code', 'strain_status', 'strain_origin',
    'strain_situation', 'strain_toxins', 'strain_public', 'strain_private_collection',
    'strain_type_strain', 'strain_last_checked', 'strain_biosafety_level',
    'strain_access_conditions', 'strain_other_codes',
    'strain_empire', 'strain_kingdom', 'strain_phylum', 'strain_class',
    'strain_order', 'strain_family', 'strain_genus', 'strain_species',
    'strain_subspecies', 'strain_variety', 'strain_scientific_name',
    'strain_authority', 'strain_other_names', 'strain_taxonomist',
    'strain_identification_method', 'strain_identification_date',
    'strain_morphology', 'strain_cell_shape', 'strain_cell_size_um',
    'strain_motility', 'strain_pigments', 'strain_colonial_morphology',
    'strain_herbarium_code', 'strain_herbarium_name', 'strain_herbarium_status',
    'strain_herbarium_date', 'strain_herbarium_method', 'strain_herbarium_notes',
    'strain_last_transfer', 'strain_periodicity', 'strain_next_transfer',
    'strain_medium', 'strain_medium_salinity', 'strain_light_cycle',
    'strain_light_intensity_umol', 'strain_temperature_c', 'strain_co2_pct',
    'strain_aeration', 'strain_culture_vessel', 'strain_room',
    'strain_position_in_location', 'strain_cryo_date', 'strain_cryo_method',
    'strain_cryo_location', 'strain_cryo_vials', 'strain_cryo_responsible',
    'strain_isolation_responsible', 'strain_isolation_date',
    'strain_isolation_method', 'strain_deposit_date',
    'strain_seq_16s_bp', 'strain_its', 'strain_its_bands',
    'strain_genbank_16s_its', 'strain_genbank_status',
    'strain_bioactivity', 'strain_metabolites', 'strain_industrial_use',
    'strain_growth_rate', 'strain_publications', 'strain_notes',
    // Collection sample (via strain_sample_code FK)
    'sample_code', 'sample_date', 'sample_collector', 'sample_country',
    'sample_region', 'sample_local', 'sample_gps',
    'sample_latitude', 'sample_longitude', 'sample_habitat_type',
    'sample_substrate', 'sample_observations',
  ],
  'Reagents': [
    'reagent_qrcode', 'reagent_name', 'reagent_brand', 'reagent_reference',
    'reagent_cas_number', 'reagent_type', 'reagent_unit', 'reagent_quantity',
    'reagent_quantity_min', 'reagent_concentration', 'reagent_purity',
    'reagent_solvent', 'reagent_storage_temp', 'reagent_position',
    'reagent_lot_number', 'reagent_expiry_date', 'reagent_received_date',
    'reagent_opened_date', 'reagent_supplier', 'reagent_supplier_contact',
    'reagent_price_eur', 'reagent_hazard', 'reagent_sds_link',
    'reagent_project', 'reagent_responsible', 'reagent_notes',
  ],
  'Equipment': [
    'equipment_qrcode', 'equipment_name', 'equipment_type', 'equipment_brand',
    'equipment_model', 'equipment_serial_number', 'equipment_patrimony_number',
    'equipment_room', 'equipment_status', 'equipment_purchase_date',
    'equipment_warranty_until', 'equipment_last_calibration',
    'equipment_next_calibration', 'equipment_calibration_interval_days',
    'equipment_last_maintenance', 'equipment_next_maintenance',
    'equipment_maintenance_interval_days', 'equipment_responsible',
    'equipment_manual_link', 'equipment_supplier', 'equipment_supplier_contact',
    'equipment_price_eur', 'equipment_notes',
  ],
  'Samples': [
    'sample_code', 'sample_rebeca', 'sample_ccpi', 'sample_permit',
    'sample_other_code', 'sample_date', 'sample_collector', 'sample_responsible',
    'sample_country', 'sample_archipelago', 'sample_island', 'sample_region',
    'sample_municipality', 'sample_parish', 'sample_local', 'sample_gps',
    'sample_latitude', 'sample_longitude', 'sample_altitude_m',
    'sample_habitat_type', 'sample_habitat_1', 'sample_habitat_2',
    'sample_habitat_3', 'sample_substrate', 'sample_method',
    'sample_temperature', 'sample_ph', 'sample_conductivity', 'sample_oxygen',
    'sample_salinity', 'sample_radiation', 'sample_turbidity', 'sample_depth_m',
    'sample_bloom', 'sample_associated_organisms', 'sample_preservation',
    'sample_transport_time_h', 'sample_project', 'sample_observations',
  ],
  'Stocks': [
    // Stock columns
    'fish_stocks_tank_id', 'fish_stocks_tank_type', 'fish_stocks_rack',
    'fish_stocks_row', 'fish_stocks_column', 'fish_stocks_capacity',
    'fish_stocks_volume_l', 'fish_stocks_line', 'fish_stocks_males',
    'fish_stocks_females', 'fish_stocks_juveniles', 'fish_stocks_mortality',
    'fish_stocks_arrival_date', 'fish_stocks_origin', 'fish_stocks_responsible',
    'fish_stocks_status', 'fish_stocks_sentinel_status', 'fish_stocks_light_cycle',
    'fish_stocks_temperature_c', 'fish_stocks_conductivity', 'fish_stocks_ph',
    'fish_stocks_last_tank_cleaning', 'fish_stocks_cleaning_interval_days',
    'fish_stocks_food_type', 'fish_stocks_food_source', 'fish_stocks_food_amount',
    'fish_stocks_feeding_schedule', 'fish_stocks_last_health_check',
    'fish_stocks_health_status', 'fish_stocks_treatment',
    'fish_stocks_last_breeding', 'fish_stocks_cross_id',
    'fish_stocks_last_count_date', 'fish_stocks_experiment_id',
    'fish_stocks_ethics_approval', 'fish_stocks_notes',
    // Fish line (via fish_stocks_line_id FK)
    'fish_line_name', 'fish_line_alias', 'fish_line_type', 'fish_line_status',
    'fish_line_date_birth', 'fish_line_date_received', 'fish_line_source',
    'fish_line_mutation_type', 'fish_line_mutation_description', 'fish_line_transgene',
  ],
};

/// Returns the `select` string for Supabase — includes FK joins where needed.
String _selectForCategory(String category) => switch (category) {
  'Stocks'  => '*, fish_lines!fish_stocks_line_id(*)',
  'Strains' => '*, samples!strain_sample_code(*)',
  _         => '*',
};

/// Flattens one level of nested Maps (joined tables) into the top-level row.
/// e.g. {fish_lines: {fish_line_name: 'AB'}} → {fish_line_name: 'AB'}
Map<String, dynamic> _flattenJoins(dynamic rawRow) {
  final row = Map<String, dynamic>.from(rawRow as Map);
  final nested = row.entries.where((e) => e.value is Map).toList();
  for (final e in nested) {
    row.addAll(Map<String, dynamic>.from(e.value as Map));
    row.remove(e.key);
  }
  return row;
}

List<String> _allColsForCategory(String category) =>
    _kAllColsByCategory[category] ?? _kAllColsByCategory['Strains']!;

/// Converts a DB column name to a human-readable label.
/// e.g. 'strain_scientific_name' → 'Scientific Name'
///      'equipment_qrcode' → 'QR Code'
String _colLabel(String col) {
  const prefixes = ['fish_stocks_', 'fish_line_', 'equipment_', 'reagent_', 'sample_', 'strain_'];
  String base = col;
  for (final p in prefixes) {
    if (col.startsWith(p)) { base = col.substring(p.length); break; }
  }
  if (base == 'qrcode') return 'QR Code';
  return base
      .split('_')
      .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ')
      .replaceAll('Qrcode', 'QR Code');
}

/// Returns the placeholder key that a QR code field should encode by default
/// for the given category. Uses the dedicated qrcode column where one exists.
String _qrKeyForCategory(String category) => switch (category) {
  'Strains'   => '{strain_qrcode}',
  'Reagents'  => '{reagent_qrcode}',
  'Equipment' => '{equipment_qrcode}',
  'Samples'   => '{sample_code}',           // no dedicated qrcode column
  'Stocks'    => '{fish_stocks_tank_id}',   // no dedicated qrcode column
  _           => '{code}',
};

Map<String, dynamic> _sampleDataFor(String category) => switch (category) {
  'Strains' => {
    'strain_qrcode': 'STR-2024-001',
    'strain_code': 'STR-2024-001', 'strain_status': 'Active',
    'strain_species': 'Penicillium chrysogenum', 'strain_genus': 'Penicillium',
    'strain_medium': 'PDA', 'strain_room': 'Lab 1',
    'strain_next_transfer': '2025-04-01', 's_island': 'Gran Canaria', 's_country': 'Spain',
  },
  'Reagents' => {
    'reagent_qrcode': 'REA-042',
    'reagent_code': 'REA-042', 'reagent_name': 'Luria-Bertani Broth',
    'reagent_lot': 'LOT-8821', 'reagent_expiry': '2026-01-15',
    'reagent_supplier': 'Sigma-Aldrich', 'reagent_location': 'Fridge 3',
    'reagent_concentration': '25 g/L',
  },
  'Equipment' => {
    'equipment_qrcode': 'EQ-0024',
    'eq_code': 'EQ-0024', 'eq_name': 'Centrifuge 5424',
    'eq_serial': 'SN-4821922', 'eq_location': 'Lab 2 — Bench B',
    'eq_calibration_due': '2025-12-31', 'eq_status': 'Operational',
  },
  'Samples' => {
    'sample_code': 'SMP-2024-007', 'sample_type': 'Seawater',
    'sample_date': '2024-03-15', 'sample_origin': 'Tenerife, ES',
    'sample_storage': '-80°C Freezer', 'sample_status': 'In processing',
  },
  'Stocks' => {
    'fish_stocks_tank_id': 'TK-042', 'fish_stocks_line': 'AB Wildtype',
    'fish_stocks_males': '5', 'fish_stocks_females': '5',
    'fish_stocks_juveniles': '20', 'fish_stocks_status': 'Active',
    'fish_stocks_responsible': 'Dr. Smith', 'fish_stocks_arrival_date': '2024-01-15',
  },
  _ => {'code': 'ITEM-001', 'name': 'Sample Item', 'date': '2024-01-01'},
};

String _tableForEntity(String entityType) => switch (entityType) {
  'Strains'   => 'strains',
  'Samples'   => 'samples',
  'Stocks'    => 'fish_stocks',
  'Reagents'  => 'reagents',
  'Equipment' => 'equipment',
  _           => 'strains',
};



// ─────────────────────────────────────────────────────────────────────────────
// Main page
// ─────────────────────────────────────────────────────────────────────────────
class PrintStrainsPage extends StatefulWidget {
  final List<Map<String, dynamic>> initialData;
  final String entityType;

  const PrintStrainsPage({
    super.key,
    this.initialData = const [],
    this.entityType = 'Strains',
  });

  @override
  State<PrintStrainsPage> createState() => _PrintStrainsPageState();
}

class _PrintStrainsPageState extends State<PrintStrainsPage> {
  final _printer = PrinterConfig();
  LabelTemplate? _activeTemplate;
  late final List<LabelTemplate> _templates;
  _ConnState _connState = _ConnState.checking;
  Timer? _pingTimer;

  @override
  void initState() {
    super.initState();
    _templates = [];
    _activeTemplate = null;
    _loadAndInit();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) => _checkConnection());
  }

  @override
  void dispose() {
    _pingTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAndInit() async {
    await _loadPrinterConfig();
    await _loadTemplates();
    _checkConnection();
  }

  // ── Supabase template CRUD ──────────────────────────────────────────────────

  Future<void> _loadTemplates() async {
    try {
      final rows = await Supabase.instance.client
          .from('label_templates')
          .select()
          .order('tpl_created_at') as List<dynamic>;
      if (!mounted) return;
      setState(() {
        _templates.clear();
        for (final row in rows) {
          try { _templates.add(LabelTemplate.fromDb(row as Map<String, dynamic>)); }
          catch (_) {}
        }
        _activeTemplate ??= _templates.firstWhereOrNull((t) => t.category == widget.entityType)
            ?? _templates.firstOrNull;
      });
    } catch (_) {}
  }

  Future<void> _saveTemplate(LabelTemplate tpl) async {
    try {
      await Supabase.instance.client.from('label_templates').upsert(tpl.toDb());
    } catch (_) {}
  }

  void _duplicateTemplate(LabelTemplate tpl) {
    // Generate a unique name: "Name_duplicate1", "Name_duplicate2", …
    final existingNames = _templates.map((t) => t.name).toSet();
    String newName;
    int n = 1;
    do { newName = '${tpl.name}_duplicate$n'; n++; } while (existingNames.contains(newName));

    final copy = tpl.clone()
      ..id   = 'tpl_${DateTime.now().millisecondsSinceEpoch}'
      ..name = newName;
    setState(() { _templates.add(copy); _activeTemplate = copy; });
    _saveTemplate(copy);
  }

  Future<void> _deleteTemplate(LabelTemplate tpl) async {
    try {
      await Supabase.instance.client
          .from('label_templates')
          .delete()
          .eq('tpl_id', tpl.id);
    } catch (_) {}
  }

  void _openStarters() {
    showDialog(
      context: context,
      builder: (_) => _StartersDialog(
        onSelect: (tpl) {
          setState(() {
            _templates.add(tpl);
            _activeTemplate = tpl;
          });
          _saveTemplate(tpl);
        },
      ),
    );
  }

  Future<void> _loadPrinterConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _printer.protocol = prefs.getString('printer_protocol') ?? _printer.protocol;
        _printer.connectionType = prefs.getString('printer_connectionType') ?? _printer.connectionType;
        _printer.deviceName = prefs.getString('printer_deviceName') ?? _printer.deviceName;
        _printer.ipAddress = prefs.getString('printer_ipAddress') ?? _printer.ipAddress;
        _printer.usbPath = prefs.getString('printer_usbPath') ?? _printer.usbPath;
      });
    } catch (_) {}
  }

  Future<void> _savePrinterConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('printer_protocol', _printer.protocol);
      await prefs.setString('printer_connectionType', _printer.connectionType);
      await prefs.setString('printer_deviceName', _printer.deviceName);
      await prefs.setString('printer_ipAddress', _printer.ipAddress);
      await prefs.setString('printer_usbPath', _printer.usbPath);
    } catch (_) {}
  }

  Future<void> _checkConnection() async {
    if (!mounted) return;
    setState(() => _connState = _ConnState.checking);
    final state = await _checkPrinterConnection(_printer);
    if (mounted) setState(() => _connState = state);
  }

  Future<void> _showNewTemplateDialog() async {
    final nameCtrl = TextEditingController(text: 'New Template');
    String selectedCategory = widget.entityType;
    const categories = ['Strains', 'Samples', 'Reagents', 'Equipment', 'Stocks', 'General'];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppDS.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(children: [
            const Icon(Icons.add_box_outlined, size: 18, color: AppDS.accent),
            const SizedBox(width: 8),
            const Text('New Template',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppDS.textPrimary)),
          ]),
          content: SizedBox(
            width: 340,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Template Name',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                        color: AppDS.textSecondary)),
                const SizedBox(height: 6),
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  style: const TextStyle(fontSize: 13, color: AppDS.textPrimary),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: AppDS.bg,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppDS.border)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppDS.border)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppDS.accent)),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Category',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                        color: AppDS.textSecondary)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: categories.map((cat) {
                    final sel = selectedCategory == cat;
                    return GestureDetector(
                      onTap: () => setS(() => selectedCategory = cat),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: sel ? AppDS.accent.withValues(alpha: 0.15) : AppDS.bg,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: sel ? AppDS.accent : AppDS.border,
                              width: sel ? 1.5 : 1),
                        ),
                        child: Text(cat,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: sel ? AppDS.accent : AppDS.textPrimary)),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel',
                  style: TextStyle(fontSize: 13, color: AppDS.textSecondary)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: AppDS.accent,
                  foregroundColor: AppDS.bg,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Create', style: TextStyle(fontSize: 13)),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;
    final name = nameCtrl.text.trim().isEmpty ? 'New Template' : nameCtrl.text.trim();
    _openBuilder(LabelTemplate(
      id: 'tpl_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      category: selectedCategory,
      labelW: 62,
      labelH: 30,
    ));
  }

  void _openBuilder([LabelTemplate? template]) {
    final tpl = template ?? LabelTemplate(
      id: 'tpl_${DateTime.now().millisecondsSinceEpoch}',
      name: 'New Template',
      category: widget.entityType,
      labelW: 62,
      labelH: 30,
    );
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _BuilderPage(
        template: tpl,
        onSave: (saved) async {
          await Supabase.instance.client.from('label_templates').upsert(saved.toDb());
          if (!mounted) return;
          setState(() {
            final i = _templates.indexWhere((x) => x.id == saved.id);
            if (i >= 0) { _templates[i] = saved; } else { _templates.add(saved); }
            _activeTemplate = saved;
          });
        },
      ),
    ));
  }

  void _openSettings() {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _PrinterSettingsPage(
        config: _printer,
        onChanged: () { setState(() {}); _checkConnection(); },
        onSave: _savePrinterConfig,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Theme(
      data: (isDark ? ThemeData.dark() : ThemeData.light()).copyWith(
        scaffoldBackgroundColor: context.appBg,
        appBarTheme: AppBarTheme(
          backgroundColor: context.appSurface,
          foregroundColor: context.appTextPrimary,
          elevation: 0,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: Row(children: [
            const Icon(Icons.print_rounded, size: 18, color: AppDS.accent),
            const SizedBox(width: 10),
            const Text('Label Printing',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            Tooltip(
              message: switch (_connState) {
                _ConnState.checking    => 'Checking printer…',
                _ConnState.connected   => '${_printer.deviceName} — connected',
                _ConnState.driverOnly  => 'Driver found — printer is offline or not connected',
                _ConnState.unreachable => 'Printer not found — tap to retry',
              },
              child: GestureDetector(
                onTap: _checkConnection,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: switch (_connState) {
                      _ConnState.checking    => context.appTextMuted,
                      _ConnState.connected   => AppDS.green,
                      _ConnState.driverOnly  => const Color(0xFFF59E0B),
                      _ConnState.unreachable => AppDS.red,
                    },
                  ),
                ),
              ),
            ),
          ]),
          actions: [
            IconButton(
              icon: Icon(Icons.settings_outlined, size: 20, color: context.appTextSecondary),
              tooltip: 'Printer settings',
              onPressed: _openSettings,
            ),
            TextButton.icon(
              icon: Icon(Icons.library_books_outlined, size: 16, color: context.appTextSecondary),
              label: Text('Starters', style: TextStyle(fontSize: 12, color: context.appTextSecondary)),
              onPressed: _openStarters,
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8, left: 4),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppDS.accent,
                  foregroundColor: const Color(0xFF0F172A),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  minimumSize: const Size(0, 36),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _showNewTemplateDialog,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('New Template', style: TextStyle(fontSize: 13)),
              ),
            ),
          ],
        ),
        body: _TemplatesTab(
          templates: _templates,
          activeTemplate: _activeTemplate,
          printer: _printer,
          connected: _connState,
          records: widget.initialData,
          entityType: widget.entityType,
          onSelect: (t) => setState(() => _activeTemplate = t),
          onEdit: (t) { setState(() => _activeTemplate = t); _openBuilder(t); },
          onDuplicate: _duplicateTemplate,
          onDelete: (t) {
            setState(() {
              _templates.removeWhere((x) => x.id == t.id);
              if (_activeTemplate?.id == t.id) _activeTemplate = _templates.firstOrNull;
            });
            _deleteTemplate(t);
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Builder — full page (Navigator.push from AppBar "New Template" / Edit)
// ─────────────────────────────────────────────────────────────────────────────
class _BuilderPage extends StatelessWidget {
  final LabelTemplate template;
  final Future<void> Function(LabelTemplate) onSave;
  const _BuilderPage({required this.template, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBg,
      body: _BuilderTab(
        template: template,
        onSave: onSave,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Printer Settings — full page (Navigator.push from AppBar settings icon)
// ─────────────────────────────────────────────────────────────────────────────
class _PrinterSettingsPage extends StatefulWidget {
  final PrinterConfig config;
  final VoidCallback onChanged;
  final Future<void> Function() onSave;
  const _PrinterSettingsPage({
    required this.config,
    required this.onChanged,
    required this.onSave,
  });
  @override State<_PrinterSettingsPage> createState() => _PrinterSettingsPageState();
}

class _PrinterSettingsPageState extends State<_PrinterSettingsPage> {
  final _tabKey = GlobalKey<_PrinterTabState>();

  void _openDetect() {
    showDialog(
      context: context,
      builder: (_) => _InstalledPrintersDialog(
        onSelect: (info) => _tabKey.currentState?._applyDetected(info),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBg,
      appBar: AppBar(
        backgroundColor: context.appSurface,
        foregroundColor: context.appTextPrimary,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Row(children: [
          Icon(Icons.print_outlined, size: 16, color: AppDS.accent),
          SizedBox(width: 8),
          Text('Printer Settings',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.manage_search_rounded, size: 20),
            tooltip: 'Auto-detect installed printers',
            onPressed: _openDetect,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8, left: 4),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppDS.accent,
                foregroundColor: const Color(0xFF0F172A),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                minimumSize: const Size(0, 36),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                widget.onSave().then((_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Printer settings saved')),
                    );
                  }
                });
              },
              icon: const Icon(Icons.save_rounded, size: 16),
              label: const Text('Save', style: TextStyle(fontSize: 13)),
            ),
          ),
        ],
      ),
      body: _PrinterTab(key: _tabKey, config: widget.config, onChanged: widget.onChanged),
    );
  }
}
