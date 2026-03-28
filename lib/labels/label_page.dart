// label_page.dart — Label designer and printer driver integration.
// Defines shared types: LabelField, LabelTemplate, PrinterConfig, _ConnState.
//
// Folder structure:
//   templates/    — main labels page: template listing, preview canvas
//   builder/      — label designer: canvas, palette, properties, DB field picker
//   print/        — print page: record list, filters, print dispatch UI
//   printer_drivers/ — all PC→printer communication: drivers, USB, settings

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/theme/theme.dart';
import '../camera/qr_scanner/qr_code_rules.dart';
import '../supabase/supabase_manager.dart';

// printer_drivers — all PC→printer communication
part 'printer_drivers/zpl_driver.dart';
part 'printer_drivers/brother_ql_570.dart';
part 'printer_drivers/brother_ql_700.dart';
part 'printer_drivers/printer_machine_driver.dart';
part 'printer_drivers/label_printer_settings_page.dart';

// templates — main labels page
part 'templates/label_widgets.dart';
part 'templates/label_preview_canvas.dart';
part 'templates/label_templates_dialog.dart';

// builder — label designer
part 'builder/label_builder_page.dart';
part 'builder/label_db_field_picker.dart';
part 'builder/label_builder_widgets.dart';
part 'builder/label_builder_properties.dart';

// print — print page
part 'print/label_print_page.dart';
part 'print/label_print_filters.dart';
part 'print/label_print_records.dart';
part 'print/label_quick_print_dialog.dart';

const _kPaperSizes = ['62x30', '62x100', '62x29', '29x62', '29x90', '38x90', '54x29'];

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
  String cutMode;      // 'none' | 'between' | 'end'
  bool halfCut;
  bool rotate;         // 90°
  int copies;
  double topOffsetMm;  // shift content up by this many mm to compensate for printer top feed

  LabelTemplate({
    required this.id,
    required this.name,
    this.category = 'General',
    this.labelW = 62,
    this.labelH = 30,
    List<LabelField>? fields,
    this.paperSize = '62x30',
    this.dpi = 300,
    this.cutMode = 'between',
    this.halfCut = false,
    this.rotate = false,
    this.copies = 1,
    this.topOffsetMm = 0.0,
  }) : fields = fields ?? [];

  LabelTemplate clone() => LabelTemplate(
    id: id, name: name, category: category, labelW: labelW, labelH: labelH,
    fields: fields.map((f) => f.copyWith()).toList(),
    paperSize: paperSize, dpi: dpi, cutMode: cutMode,
    halfCut: halfCut, rotate: rotate, copies: copies,
    topOffsetMm: topOffsetMm,
  );

  Map<String, dynamic> toDb() => {
    'tpl_id': id,
    'tpl_name': name,
    'tpl_category': category,
    'tpl_label_w': labelW,
    'tpl_label_h': labelH,
    'tpl_paper_size': paperSize,
    'tpl_dpi': dpi,
    'tpl_cut_mode': cutMode,
    'tpl_top_offset_mm': topOffsetMm,
    'tpl_half_cut': halfCut,
    'tpl_rotate': rotate,
    'tpl_copies': copies,
    'tpl_fields': fields.map((f) => f.toJson()).toList(),
    'tpl_updated_at': DateTime.now().toUtc().toIso8601String(),
  };

  factory LabelTemplate.fromDb(Map<String, dynamic> row) {
    final rawFields = row['tpl_fields'] as List<dynamic>? ?? [];
    // Migrate from old bool tpl_auto_cut if tpl_cut_mode not yet stored.
    final cutModeRaw = row['tpl_cut_mode'] as String?;
    final cutMode = cutModeRaw ??
        ((row['tpl_auto_cut'] as bool? ?? true) ? 'between' : 'none');
    return LabelTemplate(
      id: row['tpl_id'] as String,
      name: row['tpl_name'] as String,
      category: row['tpl_category'] as String? ?? 'General',
      labelW: (row['tpl_label_w'] as num?)?.toDouble() ?? 62,
      labelH: (row['tpl_label_h'] as num?)?.toDouble() ?? 30,
      paperSize: row['tpl_paper_size'] as String? ?? '62x30',
      dpi: row['tpl_dpi'] as int? ?? 300,
      cutMode: cutMode,
      topOffsetMm: (row['tpl_top_offset_mm'] as num?)?.toDouble() ?? 0.0,
      halfCut: row['tpl_half_cut'] as bool? ?? false,
      rotate: row['tpl_rotate'] as bool? ?? false,
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
  bool   continuousRoll;   // true = continuous roll, false = die-cut pre-sized

  PrinterConfig({
    this.protocol = 'zpl',
    this.connectionType = 'usb',
    this.deviceName = 'Zebra ZD421',
    this.ipAddress = '192.168.1.100',
    this.usbPath = '/dev/usb/lp0',
    this.continuousRoll = true,
  });
}

/// A named printer profile that bundles all connection + quality settings.
/// Multiple profiles can exist; one is "active" at a time.
class PrinterProfile {
  String id;
  String name;
  String protocol;         // 'zpl' | 'brother_ql' | 'brother_ql_legacy'
  String connectionType;   // 'usb' | 'wifi' | 'bluetooth'
  String deviceName;
  String ipAddress;
  String usbPath;
  int    dpi;              // 300 | 600
  String cutMode;          // 'none' | 'between' | 'end'
  bool   halfCut;
  bool   continuousRoll;   // true = continuous roll, false = die-cut pre-sized
  double topOffsetMm;      // shift content up by this many mm to compensate for printer top feed

  PrinterProfile({
    String? id,
    this.name = 'New Printer',
    this.protocol = 'zpl',
    this.connectionType = 'usb',
    this.deviceName = 'Zebra ZD421',
    this.ipAddress = '192.168.1.100',
    this.usbPath = '',
    this.dpi = 300,
    this.cutMode = 'between',
    this.halfCut = false,
    this.continuousRoll = true,
    this.topOffsetMm = 0.0,
  }) : id = id ?? 'p_${DateTime.now().millisecondsSinceEpoch}';

  /// Returns a bare PrinterConfig for driver routing.
  PrinterConfig toPrinterConfig() => PrinterConfig(
    protocol: protocol, connectionType: connectionType,
    deviceName: deviceName, ipAddress: ipAddress, usbPath: usbPath,
    continuousRoll: continuousRoll,
  );

  /// Stamps this profile's quality settings onto a template clone for printing.
  LabelTemplate applyTo(LabelTemplate tpl) {
    final c = tpl.clone();
    c.dpi = dpi; c.cutMode = cutMode; c.halfCut = halfCut;
    c.topOffsetMm = topOffsetMm;
    return c;
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'protocol': protocol,
    'connectionType': connectionType, 'deviceName': deviceName,
    'ipAddress': ipAddress, 'usbPath': usbPath,
    'dpi': dpi, 'cutMode': cutMode, 'halfCut': halfCut,
    'continuousRoll': continuousRoll, 'topOffsetMm': topOffsetMm,
  };

  factory PrinterProfile.fromJson(Map<String, dynamic> j) => PrinterProfile(
    id:             j['id']             as String?,
    name:           j['name']           as String? ?? 'Printer',
    protocol:       j['protocol']       as String? ?? 'zpl',
    connectionType: j['connectionType'] as String? ?? 'usb',
    deviceName:     j['deviceName']     as String? ?? 'Zebra ZD421',
    ipAddress:      j['ipAddress']      as String? ?? '192.168.1.100',
    usbPath:        j['usbPath']        as String? ?? '',
    dpi:            j['dpi']            as int?    ?? 300,
    // Migrate from old autoCut bool if cutMode not yet stored.
    cutMode:        j['cutMode'] as String? ??
                    ((j['autoCut'] as bool? ?? true) ? 'between' : 'none'),
    halfCut:        j['halfCut']        as bool?   ?? false,
    continuousRoll: j['continuousRoll'] as bool?   ?? true,
    topOffsetMm:    (j['topOffsetMm']   as num?)?.toDouble() ?? 0.0,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Available fields by category
// ─────────────────────────────────────────────────────────────────────────────

const _kFieldsByCategory = <String, List<({String key, String label})>>{
  'Strains': [
    (key: '{__qr__}',               label: 'QR Code'),
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
    (key: '{__qr__}',                label: 'QR Code'),
    (key: '{reagent_code}',          label: 'Reagent Code'),
    (key: '{reagent_name}',          label: 'Name'),
    (key: '{reagent_lot}',           label: 'Lot Number'),
    (key: '{reagent_expiry}',        label: 'Expiry Date'),
    (key: '{reagent_supplier}',      label: 'Supplier'),
    (key: '{reagent_location}',      label: 'Storage Location'),
    (key: '{reagent_concentration}', label: 'Concentration'),
  ],
  'Equipment': [
    (key: '{__qr__}',              label: 'QR Code'),
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
    '__qr__', 'strain_code', 'strain_status', 'strain_origin',
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
    '__qr__', 'reagent_name', 'reagent_brand', 'reagent_reference',
    'reagent_cas_number', 'reagent_type', 'reagent_unit', 'reagent_quantity',
    'reagent_quantity_min', 'reagent_concentration', 'reagent_purity',
    'reagent_solvent', 'reagent_storage_temp', 'reagent_position',
    'reagent_lot_number', 'reagent_expiry_date', 'reagent_received_date',
    'reagent_opened_date', 'reagent_supplier', 'reagent_supplier_contact',
    'reagent_price_eur', 'reagent_hazard', 'reagent_sds_link',
    'reagent_project', 'reagent_responsible', 'reagent_notes',
  ],
  'Equipment': [
    '__qr__', 'equipment_name', 'equipment_type', 'equipment_brand',
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
    '__qr__', 'sample_code', 'sample_rebeca', 'sample_ccpi', 'sample_permit',
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
    '__qr__',
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
  if (col == '__qr__') return 'QR Code';
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

/// Returns the placeholder key that a QR code field should encode.
/// All categories use the computed bluelims:// deep-link injected as __qr__.
String _qrKeyForCategory(String category) => '{__qr__}';

Map<String, dynamic> _sampleDataFor(String category) => switch (category) {
  'Strains' => {
    '__qr__': 'bluelims://demo/strains/1',
    'strain_code': 'STR-2024-001', 'strain_status': 'Active',
    'strain_species': 'Penicillium chrysogenum', 'strain_genus': 'Penicillium',
    'strain_medium': 'PDA', 'strain_room': 'Lab 1',
    'strain_next_transfer': '2025-04-01', 's_island': 'Gran Canaria', 's_country': 'Spain',
  },
  'Reagents' => {
    '__qr__': 'bluelims://demo/reagents/42',
    'reagent_code': 'REA-042', 'reagent_name': 'Luria-Bertani Broth',
    'reagent_lot': 'LOT-8821', 'reagent_expiry': '2026-01-15',
    'reagent_supplier': 'Sigma-Aldrich', 'reagent_location': 'Fridge 3',
    'reagent_concentration': '25 g/L',
  },
  'Equipment' => {
    '__qr__': 'bluelims://demo/machines/24',
    'eq_code': 'EQ-0024', 'eq_name': 'Centrifuge 5424',
    'eq_serial': 'SN-4821922', 'eq_location': 'Lab 2 — Bench B',
    'eq_calibration_due': '2025-12-31', 'eq_status': 'Operational',
  },
  'Samples' => {
    '__qr__': 'bluelims://demo/samples/1',
    'sample_code': 'SMP-2024-007', 'sample_type': 'Seawater',
    'sample_date': '2024-03-15', 'sample_origin': 'Tenerife, ES',
    'sample_storage': '-80°C Freezer', 'sample_status': 'In processing',
  },
  'Stocks' => {
    '__qr__': 'bluelims://demo/fish_stocks/42',
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
// QR injection helpers — compute bluelims:// URLs for categories without a
// dedicated qrcode DB column (Samples, Stocks, General).
// Categories that store qrcode in the DB (Strains/Reagents/Equipment) are
// left untouched; their existing DB value is already canonical.
// ─────────────────────────────────────────────────────────────────────────────

String _projectRef() => SupabaseManager.projectRef ?? 'local';

String _qrTypeForCategory(String category) => switch (category) {
  'Strains'   => 'strains',
  'Reagents'  => 'reagents',
  'Equipment' => 'machines',
  'Samples'   => 'samples',
  'Stocks'    => 'fish_stocks',
  _           => '',
};

String _idColForCategory(String category) => switch (category) {
  'Strains'   => 'strain_id',
  'Reagents'  => 'reagent_id',
  'Equipment' => 'equipment_id',
  'Samples'   => 'sample_id',
  'Stocks'    => 'fish_stocks_id',
  _           => 'id',
};

/// Injects `__qr__` (bluelims:// deep-link URL) into every row for the given
/// category using its primary-key column. Works for all categories.
void _injectQr(List<Map<String, dynamic>> rows, String category) {
  final type = _qrTypeForCategory(category);
  if (type.isEmpty || !QrRules.validTypes.contains(type)) return;
  final ref = _projectRef();
  final idCol = _idColForCategory(category);
  for (final row in rows) {
    final raw = row[idCol];
    if (raw == null) continue;
    final id = raw is int ? raw : int.tryParse(raw.toString());
    if (id != null && id > 0) row['__qr__'] = QrRules.build(ref, type, id);
  }
}

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
  final _profiles = <PrinterProfile>[];
  PrinterProfile? _activeProfile;
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
    await _loadProfiles();
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

  Future<void> _loadProfiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList('printer_profiles_v2') ?? [];
      List<PrinterProfile> loaded = raw.map((s) {
        try { return PrinterProfile.fromJson(jsonDecode(s) as Map<String, dynamic>); }
        catch (_) { return null; }
      }).whereType<PrinterProfile>().toList();

      // Migrate legacy single-printer keys → one profile
      if (loaded.isEmpty) {
        final proto = prefs.getString('printer_protocol');
        if (proto != null) {
          loaded = [PrinterProfile(
            name:           prefs.getString('printer_deviceName') ?? 'Printer',
            protocol:       proto,
            connectionType: prefs.getString('printer_connectionType') ?? 'usb',
            deviceName:     prefs.getString('printer_deviceName') ?? 'Zebra ZD421',
            ipAddress:      prefs.getString('printer_ipAddress') ?? '192.168.1.100',
            usbPath:        prefs.getString('printer_usbPath') ?? '',
          )];
        }
      }

      final activeId = prefs.getString('printer_active_profile_id');
      if (!mounted) return;
      setState(() {
        _profiles
          ..clear()
          ..addAll(loaded);
        _activeProfile = _profiles.firstWhereOrNull((p) => p.id == activeId)
            ?? _profiles.firstOrNull;
      });
    } catch (_) {}
  }

  Future<void> _saveProfiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('printer_profiles_v2',
          _profiles.map((p) => jsonEncode(p.toJson())).toList());
      if (_activeProfile != null) {
        await prefs.setString('printer_active_profile_id', _activeProfile!.id);
      }
    } catch (_) {}
  }

  Future<void> _checkConnection() async {
    if (!mounted) return;
    setState(() => _connState = _ConnState.checking);
    final cfg = _activeProfile?.toPrinterConfig() ?? PrinterConfig();
    final state = await _checkPrinterConnection(cfg);
    if (mounted) setState(() => _connState = state);
  }

  Future<void> _showNewTemplateDialog() async {
    final nameCtrl = TextEditingController(text: 'New Template');
    String selectedCategory = widget.entityType;
    String selectedPaperSize = '62x29';
    const categories = ['Strains', 'Samples', 'Reagents', 'Equipment', 'Stocks', 'General'];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: ctx.appSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(children: [
            const Icon(Icons.add_box_outlined, size: 18, color: AppDS.accent),
            const SizedBox(width: 8),
            Text('New Template',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ctx.appTextPrimary)),
          ]),
          content: SizedBox(
            width: 340,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Template Name',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                        color: ctx.appTextSecondary)),
                const SizedBox(height: 6),
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  style: TextStyle(fontSize: 13, color: ctx.appTextPrimary),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: ctx.appBg,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: ctx.appBorder)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: ctx.appBorder)),
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
                        color: ctx.appTextSecondary)),
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
                          color: sel ? AppDS.accent.withValues(alpha: 0.15) : ctx.appBg,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: sel ? AppDS.accent : ctx.appBorder,
                              width: sel ? 1.5 : 1),
                        ),
                        child: Text(cat,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: sel ? AppDS.accent : ctx.appTextPrimary)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Text('Label Size',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                        color: ctx.appTextSecondary)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _kPaperSizes.map((size) {
                    final sel = selectedPaperSize == size;
                    return GestureDetector(
                      onTap: () => setS(() => selectedPaperSize = size),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: sel ? AppDS.accent.withValues(alpha: 0.15) : ctx.appBg,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: sel ? AppDS.accent : ctx.appBorder,
                              width: sel ? 1.5 : 1),
                        ),
                        child: Text('${size.replaceAll('x', '×')} mm',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: sel ? AppDS.accent : ctx.appTextPrimary)),
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
              child: Text('Cancel',
                  style: TextStyle(fontSize: 13, color: ctx.appTextSecondary)),
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
    final sizeParts = selectedPaperSize.split('x');
    final labelW = double.tryParse(sizeParts[0]) ?? 62;
    final labelH = double.tryParse(sizeParts[1]) ?? 30;
    _openBuilder(LabelTemplate(
      id: 'tpl_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      category: selectedCategory,
      paperSize: selectedPaperSize,
      labelW: labelW,
      labelH: labelH,
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
        profiles: _profiles,
        activeProfile: _activeProfile,
        onProfileChanged: (p) {
          setState(() => _activeProfile = p);
          _saveProfiles();
          _checkConnection();
        },
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
        profiles: _profiles,
        activeProfileId: _activeProfile?.id,
        onChanged: (profiles, activeId) {
          setState(() {
            _profiles
              ..clear()
              ..addAll(profiles);
            _activeProfile = _profiles.firstWhereOrNull((p) => p.id == activeId)
                ?? _profiles.firstOrNull;
          });
          _saveProfiles();
          _checkConnection();
        },
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
            const SizedBox(width: 12),
            // Profile switcher
            if (_profiles.isNotEmpty)
              _ProfileSwitcherChip(
                profiles: _profiles,
                activeProfile: _activeProfile,
                onSelect: (p) {
                  setState(() => _activeProfile = p);
                  _saveProfiles();
                  _checkConnection();
                },
              ),
            const SizedBox(width: 10),
            // 3-dot connection indicator
            GestureDetector(
              onTap: _checkConnection,
              child: Tooltip(
                message: switch (_connState) {
                  _ConnState.checking    => 'Checking printer…',
                  _ConnState.connected   => 'Connected',
                  _ConnState.driverOnly  => 'Driver installed — printer offline',
                  _ConnState.unreachable => 'Printer not found — tap to retry',
                },
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  _ConnDot(AppDS.green,              lit: _connState == _ConnState.connected),
                  const SizedBox(width: 4),
                  _ConnDot(const Color(0xFFF59E0B),  lit: _connState == _ConnState.driverOnly),
                  const SizedBox(width: 4),
                  _ConnDot(AppDS.red,                lit: _connState == _ConnState.unreachable),
                ]),
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
          profiles: _profiles,
          activeProfile: _activeProfile,
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
          onProfileChanged: (p) {
            setState(() => _activeProfile = p);
            _saveProfiles();
            _checkConnection();
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
  final List<PrinterProfile> profiles;
  final PrinterProfile? activeProfile;
  final void Function(PrinterProfile) onProfileChanged;
  const _BuilderPage({
    required this.template, required this.onSave,
    required this.profiles, required this.activeProfile,
    required this.onProfileChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBg,
      body: _BuilderTab(
        template: template,
        onSave: onSave,
        profiles: profiles,
        activeProfile: activeProfile,
        onProfileChanged: onProfileChanged,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Printer Settings — full page (Navigator.push from AppBar settings icon)
// ─────────────────────────────────────────────────────────────────────────────
class _PrinterSettingsPage extends StatefulWidget {
  final List<PrinterProfile> profiles;
  final String? activeProfileId;
  final void Function(List<PrinterProfile>, String?) onChanged;
  const _PrinterSettingsPage({
    required this.profiles,
    required this.activeProfileId,
    required this.onChanged,
  });
  @override State<_PrinterSettingsPage> createState() => _PrinterSettingsPageState();
}

class _PrinterSettingsPageState extends State<_PrinterSettingsPage> {
  late final List<PrinterProfile> _profiles;
  String? _activeId;

  @override
  void initState() {
    super.initState();
    _profiles = List.of(widget.profiles);
    _activeId = widget.activeProfileId;
  }

  void _notify() => widget.onChanged(List.of(_profiles), _activeId);

  void _openDetect() {
    showDialog(
      context: context,
      builder: (_) => _InstalledPrintersDialog(
        onSelect: (info) {
          final profile = PrinterProfile(
            name:           info.matchedModel ?? info.name,
            protocol:       info.protocol,
            connectionType: info.protocol == 'brother_ql_legacy' ? 'usb' : info.connectionType,
            deviceName:     info.matchedModel ?? info.name,
            ipAddress:      info.ipAddress ?? '192.168.1.100',
            usbPath:        info.connectionType == 'usb' ? info.name : '',
          );
          setState(() {
            _profiles.add(profile);
            _activeId ??= profile.id;
          });
          _notify();
        },
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
          Text('Printer Profiles',
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
                final profile = PrinterProfile();
                setState(() {
                  _profiles.add(profile);
                  _activeId ??= profile.id;
                });
                _notify();
                _openEditDialog(profile);
              },
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Add Profile', style: TextStyle(fontSize: 13)),
            ),
          ),
        ],
      ),
      body: _ProfileListTab(
        profiles: _profiles,
        activeId: _activeId,
        onSetActive: (id) { setState(() => _activeId = id); _notify(); },
        onEdit: (p) => _openEditDialog(p),
        onDelete: (p) {
          setState(() {
            _profiles.removeWhere((x) => x.id == p.id);
            if (_activeId == p.id) _activeId = _profiles.firstOrNull?.id;
          });
          _notify();
        },
      ),
    );
  }

  void _openEditDialog(PrinterProfile profile) {
    showDialog(
      context: context,
      builder: (_) => _ProfileEditDialog(
        profile: profile,
        onSave: (updated) {
          setState(() {
            final i = _profiles.indexWhere((p) => p.id == updated.id);
            if (i >= 0) _profiles[i] = updated;
          });
          _notify();
        },
      ),
    );
  }
}
