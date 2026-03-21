import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/theme/theme.dart';

part 'printing_builder_page.dart';
part 'printer_settings_page.dart';
part 'templates_dialog.dart';
part 'printing_db_field_picker.dart';

const _kPaperSizes = ['62x30', '62x100', '62x29', '29x90', '38x90', '54x29'];

/// Printer reachability states — finer-grained than a simple bool so we can
/// distinguish "driver installed but printer offline/not connected" from
/// "actually ready to print".
enum _ConnState { checking, connected, driverOnly, unreachable }

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
// ZPL generation (Zebra Programming Language — for Wi-Fi TCP printing)
// ─────────────────────────────────────────────────────────────────────────────

/// Generates a ZPL string for all [records]. Each record produces [cfg.copies]
/// labels. Pass an empty list to produce one label from template placeholders only.
String _generateZpl(LabelTemplate tpl, List<Map<String, dynamic>> records, PrinterConfig cfg) {
  final buf = StringBuffer();
  final dotsPerMm = tpl.dpi / 25.4;
  int mm(double v) => (v * dotsPerMm).round().clamp(0, 9999);

  final printRecords = records.isEmpty ? [<String, dynamic>{}] : records;

  for (final record in printRecords) {
    for (int c = 0; c < tpl.copies; c++) {
      buf.write('^XA\n');
      buf.write('^PW${mm(tpl.labelW)}\n');
      buf.write('^LL${mm(tpl.labelH)}\n');
      buf.write('^CI28\n'); // UTF-8
      if (tpl.rotate) buf.write('^FWR\n');

      for (final f in tpl.fields) {
        // Resolve placeholders
        String value = f.content;
        if (f.isPlaceholder) {
          record.forEach((k, v) => value = value.replaceAll('{$k}', v?.toString() ?? ''));
          value = value.replaceAll(RegExp(r'\{[^}]+\}'), ''); // strip unresolved
        }
        // Sanitise: ZPL field data must not contain ^ or ~
        value = value.replaceAll('^', ' ').replaceAll('~', ' ');

        final x = mm(f.x);
        final y = mm(f.y);
        final w = mm(f.w);
        final h = mm(f.h);

        switch (f.type) {
          case LabelFieldType.text:
            final fh = mm(f.h).clamp(8, 200);
            final fw = (fh * 0.6).round();
            buf.write('^FO$x,$y^A0N,$fh,$fw^FD$value^FS\n');
          case LabelFieldType.qrcode:
            final mag = (h / 21.0).clamp(1.0, 10.0).round();
            buf.write('^FO$x,$y^BQN,2,$mag^FDQA,$value^FS\n');
          case LabelFieldType.barcode:
            buf.write('^FO$x,$y^BY2^BCN,$h,Y,N,N^FD$value^FS\n');
          case LabelFieldType.divider:
            buf.write('^FO$x,$y^GB$w,1,1^FS\n');
          case LabelFieldType.image:
            break; // image fields not supported in ZPL output
        }
      }

      buf.write('^XZ\n');
    }
  }
  return buf.toString();
}

/// Sends ZPL to a Wi-Fi printer on port 9100 (raw TCP).
Future<void> _sendZplOverWifi(String ip, String zpl) async {
  final socket = await Socket.connect(ip, 9100, timeout: const Duration(seconds: 8));
  try {
    socket.write(zpl);
    await socket.flush();
  } finally {
    await socket.close();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Brother QL raster protocol (TCP port 9100)
// Supports: QL-820NWB, QL-810W, QL-800, QL-700 and compatible models.
// ─────────────────────────────────────────────────────────────────────────────

String _resolvePlaceholders(String content, Map<String, dynamic> data) {
  String s = content;
  data.forEach((k, v) => s = s.replaceAll('{$k}', v?.toString() ?? ''));
  return s.replaceAll(RegExp(r'\{[^}]+\}'), '');
}

/// Renders a label template + data record to a rasterised [ui.Image].
Future<ui.Image> _renderLabelToImage(
    LabelTemplate tpl, Map<String, dynamic> data, int dpi) async {
  final pxPerMm = dpi / 25.4;
  final w = (tpl.labelW * pxPerMm).ceil();
  final h = (tpl.labelH * pxPerMm).ceil();

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder, Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()));

  // White background
  canvas.drawRect(Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      ui.Paint()..color = const Color(0xFFFFFFFF));

  for (final f in tpl.fields) {
    final x = f.x * pxPerMm;
    final y = f.y * pxPerMm;
    final fw = f.w * pxPerMm;
    final fh = f.h * pxPerMm;
    final content = f.isPlaceholder ? _resolvePlaceholders(f.content, data) : f.content;

    switch (f.type) {
      case LabelFieldType.text:
        final tp = TextPainter(
          text: TextSpan(
            text: content,
            style: TextStyle(
              fontSize: f.fontSize * pxPerMm / (25.4 / 72), // pt → px at target DPI
              fontWeight: f.fontWeight,
              color: f.color,
            ),
          ),
          textDirection: TextDirection.ltr,
          textAlign: f.textAlign,
        );
        tp.layout(maxWidth: fw);
        canvas.save();
        canvas.translate(x, y);
        tp.paint(canvas, Offset.zero);
        canvas.restore();
      case LabelFieldType.qrcode:
        if (content.isNotEmpty) {
          final qrPainter = QrPainter(
            data: content,
            version: QrVersions.auto,
            gapless: true,
            eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF000000)),
            dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF000000)),
          );
          canvas.save();
          canvas.translate(x, y);
          qrPainter.paint(canvas, Size(fh, fh));
          canvas.restore();
        }
      case LabelFieldType.barcode:
        _drawBarcodeOnCanvas(canvas, Rect.fromLTWH(x, y, fw, fh));
      case LabelFieldType.divider:
        canvas.drawRect(Rect.fromLTWH(x, y + fh / 2, fw, 1.0),
            ui.Paint()..color = f.color);
      case LabelFieldType.image:
        break;
    }
  }

  final picture = recorder.endRecording();
  return picture.toImage(w, h);
}

void _drawBarcodeOnCanvas(ui.Canvas canvas, Rect rect) {
  final paint = ui.Paint()..color = const Color(0xFF000000);
  final widths = [2.0, 1.0, 3.0, 1.0, 2.0, 1.0, 1.0, 3.0, 2.0, 1.0, 2.0, 1.0, 3.0, 1.0, 2.0];
  final total = widths.fold(0.0, (a, b) => a + b);
  double x = rect.left;
  bool draw = true;
  for (final w in widths) {
    final barW = w / total * rect.width;
    if (draw) { canvas.drawRect(Rect.fromLTWH(x, rect.top, barW - 0.5, rect.height), paint); }
    x += barW;
    draw = !draw;
  }
}

/// Generates a Brother QL raster data blob for all [records].
/// Send the result via [_sendBrotherQl].
Future<Uint8List> _generateBrotherQlData(
    LabelTemplate tpl, List<Map<String, dynamic>> records, PrinterConfig cfg) async {
  final printRecords = records.isEmpty ? [<String, dynamic>{}] : records;
  final buf = BytesBuilder();

  // Invalidate (200 null bytes) + Initialize (ESC @)
  buf.add(List.filled(200, 0));
  buf.add(const [0x1B, 0x40]);

  int pageNum = 0;
  for (final record in printRecords) {
    for (int c = 0; c < tpl.copies; c++, pageNum++) {
      // Switch to raster mode (ESC i a 0x01)
      buf.add(const [0x1B, 0x69, 0x61, 0x01]);

      // Print info (ESC i z) — flags | media type | width mm | length mm | ... | page#
      buf.add([
        0x1B, 0x69, 0x7A,
        0x8E,                   // flags: auto-detect
        0x0B,                   // media type: die-cut label
        tpl.labelW.round(),     // tape width in mm
        tpl.labelH.round(),     // label length in mm
        0, 0, 0, 0,
        pageNum,
        0,
      ]);

      // Auto-cut (ESC i M) if enabled
      if (tpl.autoCut) { buf.add(const [0x1B, 0x69, 0x4D, 0x40]); }

      // Render label to RGBA image
      final image = await _renderLabelToImage(tpl, record, tpl.dpi);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) continue;
      final rgba = byteData.buffer.asUint8List();
      final iw = image.width;
      final ih = image.height;

      // Brother QL uses 90 bytes per raster line for 62 mm tape (720 dots).
      // Adjust bytesPerLine for other tape widths.
      const bytesPerLine = 90;

      for (int row = 0; row < ih; row++) {
        final line = List<int>.filled(bytesPerLine, 0);
        for (int col = 0; col < iw && col < bytesPerLine * 8; col++) {
          final idx = (row * iw + col) * 4;
          final gray = (rgba[idx] * 0.299 + rgba[idx + 1] * 0.587 + rgba[idx + 2] * 0.114).round();
          if (gray < 128) {
            // Black pixel — set bit (MSB first)
            final byteIdx = col ~/ 8;
            if (byteIdx < bytesPerLine) { line[byteIdx] |= (1 << (7 - col % 8)); }
          }
        }
        buf.add([0x67, 0x00, bytesPerLine]);
        buf.add(line);
      }

      // Print + feed (0x1A) or print without feed (0x0C)
      buf.addByte(tpl.autoCut ? 0x1A : 0x0C);
    }
  }

  return buf.toBytes();
}

// ─────────────────────────────────────────────────────────────────────────────
// Brother QL legacy raster protocol (QL-500, QL-550, QL-570, QL-650TD)
// These older models omit the ESC i z print-info command, are USB-only,
// and are fixed at 300 DPI.
// ─────────────────────────────────────────────────────────────────────────────

Future<Uint8List> _generateBrotherQlLegacyData(
    LabelTemplate tpl, List<Map<String, dynamic>> records) async {
  final printRecords = records.isEmpty ? [<String, dynamic>{}] : records;
  final buf = BytesBuilder();

  // Invalidate (200 null bytes) + Initialize (ESC @)
  buf.add(List.filled(200, 0));
  buf.add(const [0x1B, 0x40]);
  // Switch to raster mode (ESC i a 0x01)
  buf.add(const [0x1B, 0x69, 0x61, 0x01]);

  // No ESC i z (print-info) — not supported on legacy models.
  // No ESC i M (auto-cut settings) — cut is triggered per-page via 0x1A.

  for (final record in printRecords) {
    for (int c = 0; c < tpl.copies; c++) {
      // Legacy models are fixed at 300 DPI
      final image = await _renderLabelToImage(tpl, record, 300);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) continue;
      final rgba = byteData.buffer.asUint8List();
      final iw = image.width;
      final ih = image.height;

      const bytesPerLine = 90; // 720 dots for 62 mm tape at 300 DPI
      for (int row = 0; row < ih; row++) {
        final line = List<int>.filled(bytesPerLine, 0);
        for (int col = 0; col < iw && col < bytesPerLine * 8; col++) {
          final idx = (row * iw + col) * 4;
          final gray = (rgba[idx] * 0.299 + rgba[idx + 1] * 0.587 + rgba[idx + 2] * 0.114).round();
          if (gray < 128) {
            final byteIdx = col ~/ 8;
            if (byteIdx < bytesPerLine) { line[byteIdx] |= (1 << (7 - col % 8)); }
          }
        }
        buf.add([0x67, 0x00, bytesPerLine]);
        buf.add(line);
      }
      // 0x1A = print + cut, 0x0C = print without cut
      buf.addByte(tpl.autoCut ? 0x1A : 0x0C);
    }
  }
  return buf.toBytes();
}

/// Sends Brother QL raster data to the printer over raw TCP port 9100.
Future<void> _sendBrotherQl(String ip, Uint8List data) async {
  final socket = await Socket.connect(ip, 9100, timeout: const Duration(seconds: 8));
  try {
    socket.add(data);
    await socket.flush();
  } finally {
    await socket.close();
  }
}

/// Sends raw bytes to a USB-connected printer.
/// - Linux/macOS: writes directly to the device file (e.g. /dev/usb/lp0).
/// - Windows: spools to the print queue via `COPY /B`.
Future<void> _sendViaUsb(String path, Uint8List data) async {
  if (Platform.isLinux || Platform.isMacOS) {
    final raf = await File(path).open(mode: FileMode.writeOnly);
    try { await raf.writeFrom(data); } finally { await raf.close(); }
  } else if (Platform.isWindows) {
    final tmp = File('${Directory.systemTemp.path}\\bluelims_print.prn');
    await tmp.writeAsBytes(data);
    try {
      final r = await Process.run('cmd', ['/c', 'COPY /B "${tmp.path}" "$path"'], runInShell: true);
      if (r.exitCode != 0) throw Exception('USB print failed: ${r.stderr}');
    } finally {
      await tmp.delete();
    }
  } else {
    throw UnsupportedError('USB printing is not supported on this platform.');
  }
}

/// Checks whether the configured printer is reachable.
///
/// Returns [_ConnState.connected] if the printer is ready to receive jobs,
/// [_ConnState.driverOnly] if the driver/port is registered but the device is
/// offline or not physically connected (Windows USB only), and
/// [_ConnState.unreachable] if the printer cannot be found at all.
Future<_ConnState> _checkPrinterConnection(PrinterConfig cfg) async {
  try {
    if (cfg.connectionType == 'usb') {
      if (Platform.isLinux || Platform.isMacOS) {
        // On Linux/macOS the device file (e.g. /dev/usb/lp0) only exists when
        // the USB device is physically enumerated — so existsSync() is reliable.
        return File(cfg.usbPath).existsSync()
            ? _ConnState.connected
            : _ConnState.unreachable;
      } else if (Platform.isWindows) {
        // Use WMI Win32_Printer to distinguish between:
        //   • driver installed + printer actually online  → connected
        //   • driver installed + printer offline/not plugged → driverOnly
        //   • no driver / unknown name                    → unreachable
        final name = cfg.usbPath.replaceAll("'", "''"); // escape WMI filter
        final filter = "Name='$name'";
        final script =
            "\$p = Get-WmiObject Win32_Printer -Filter \"$filter\" 2>\$null; "
            "if (\$null -ne \$p) { "
            "  if (\$p.WorkOffline -eq \$true -or \$p.PrinterStatus -eq 7) { 'driver_only' } "
            "  else { 'ready' } "
            "} else { 'not_found' }";
        final r = await Process.run(
          'powershell',
          ['-Command', script],
          runInShell: true,
        );
        final out = r.stdout.toString().trim();
        if (out.contains('ready')) return _ConnState.connected;
        if (out.contains('driver_only')) return _ConnState.driverOnly;
        return _ConnState.unreachable;
      }
      return _ConnState.unreachable;
    } else {
      // Wi-Fi / Bluetooth: attempt a TCP handshake on port 9100
      final socket = await Socket.connect(
          cfg.ipAddress, 9100, timeout: const Duration(seconds: 3));
      await socket.close();
      return _ConnState.connected;
    }
  } catch (_) {
    return _ConnState.unreachable;
  }
}

/// Dispatches to ZPL or Brother QL, then routes to USB / Wi-Fi / Bluetooth.
Future<void> _sendToPrinter(
    LabelTemplate tpl, List<Map<String, dynamic>> records, PrinterConfig cfg) async {
  if (cfg.protocol == 'brother_ql_legacy') {
    // Legacy QL models (QL-500/550/570/650TD) are USB-only
    final data = await _generateBrotherQlLegacyData(tpl, records);
    await _sendViaUsb(cfg.usbPath, data);
  } else if (cfg.connectionType == 'usb') {
    final Uint8List data;
    if (cfg.protocol == 'brother_ql') {
      data = await _generateBrotherQlData(tpl, records, cfg);
    } else {
      data = Uint8List.fromList(_generateZpl(tpl, records, cfg).codeUnits);
    }
    await _sendViaUsb(cfg.usbPath, data);
  } else if (cfg.protocol == 'brother_ql') {
    final data = await _generateBrotherQlData(tpl, records, cfg);
    await _sendBrotherQl(cfg.ipAddress, data);
  } else {
    final zpl = _generateZpl(tpl, records, cfg);
    await _sendZplOverWifi(cfg.ipAddress, zpl);
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
        onSave: (saved) {
          setState(() {
            final i = _templates.indexWhere((x) => x.id == saved.id);
            if (i >= 0) { _templates[i] = saved; } else { _templates.add(saved); }
            _activeTemplate = saved;
          });
          _saveTemplate(saved);
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
  final void Function(LabelTemplate) onSave;
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
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: const Text('Printer settings saved'),
                      backgroundColor: const Color(0xFF1E293B),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ));
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

// ─────────────────────────────────────────────────────────────────────────────
// Tab 1 — Templates (grouped by category)
// ─────────────────────────────────────────────────────────────────────────────
class _TemplatesTab extends StatelessWidget {
  final List<LabelTemplate> templates;
  final LabelTemplate? activeTemplate;
  final PrinterConfig printer;
  final _ConnState connected;
  final List<Map<String, dynamic>> records;
  final String entityType;
  final void Function(LabelTemplate) onSelect;
  final void Function(LabelTemplate) onEdit;
  final void Function(LabelTemplate) onDelete;

  const _TemplatesTab({
    required this.templates, required this.activeTemplate,
    required this.printer, required this.connected,
    required this.records, required this.entityType,
    required this.onSelect, required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final Map<String, List<LabelTemplate>> byCategory = {};
    for (final t in templates) {
      byCategory.putIfAbsent(t.category, () => []).add(t);
    }

    final dotColor = switch (connected) {
      _ConnState.checking    => context.appTextMuted,
      _ConnState.connected   => AppDS.green,
      _ConnState.driverOnly  => const Color(0xFFF59E0B),
      _ConnState.unreachable => AppDS.red,
    };
    final connLabel = switch (connected) {
      _ConnState.checking    => 'Checking…',
      _ConnState.connected   => 'Connected',
      _ConnState.driverOnly  => 'Driver found — offline',
      _ConnState.unreachable => 'Not found',
    };

    return Column(children: [
      // Printer status bar
      Container(
        color: context.appSurface,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 8, height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
          ),
          const SizedBox(width: 8),
          Text(printer.deviceName,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.appTextPrimary)),
          const SizedBox(width: 6),
          Text('${printer.connectionType.toUpperCase()} · ${activeTemplate?.paperSize ?? '62x30'} mm · ${activeTemplate?.dpi ?? 300} dpi',
              style: TextStyle(fontSize: 11, color: context.appTextSecondary)),
          const SizedBox(width: 6),
          Text(connLabel,
              style: TextStyle(fontSize: 10, color: dotColor, fontWeight: FontWeight.w600)),
          const Spacer(),
          if (activeTemplate?.autoCut ?? false) ...[
            _Pill('Auto-cut', Icons.content_cut_rounded, AppDS.accent),
            const SizedBox(width: 6),
          ],
          if (activeTemplate?.rotate ?? false)
            _Pill('Rotated', Icons.rotate_90_degrees_ccw_rounded, AppDS.sky),
        ]),
      ),
      Divider(height: 1, color: context.appBorder),
      Expanded(
        child: templates.isEmpty
            ? Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.view_quilt_outlined, size: 48, color: context.appTextMuted),
                  const SizedBox(height: 12),
                  Text('No templates yet',
                      style: TextStyle(fontSize: 14, color: context.appTextMuted)),
                  const SizedBox(height: 6),
                  Text('Use "Starters" to add a pre-built template, or "New Template" to build from scratch.',
                      style: TextStyle(fontSize: 12, color: context.appTextMuted)),
                ]),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final category in byCategory.keys) ...[
                    _CategoryHeader(category),
                    const SizedBox(height: 10),
                    for (final t in byCategory[category]!)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _TemplateCard(
                          template: t,
                          isActive: activeTemplate?.id == t.id,
                          onSelect: () => onSelect(t),
                          onEdit: () => onEdit(t),
                          onDelete: () => onDelete(t),
                          onPrint: () => _showPrintDialog(context, t),
                        ),
                      ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
      ),
    ]);
  }

  void _showPrintDialog(BuildContext context, LabelTemplate t) {
    showDialog(
      context: context,
      builder: (ctx) => _PrintDialog(
        template: t,
        printer: printer,
        initialRecords: records,
        entityType: t.category,
      ),
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  final String category;
  const _CategoryHeader(this.category);

  static const _icons = <String, IconData>{
    'Strains':   Icons.science_outlined,
    'Reagents':  Icons.water_drop_outlined,
    'Equipment': Icons.build_outlined,
    'Samples':   Icons.inventory_2_outlined,
    'Stocks':    Icons.set_meal_rounded,
    'General':   Icons.label_outline,
  };

  @override
  Widget build(BuildContext context) {
    final icon = _icons[category] ?? Icons.label_outline;
    return Row(children: [
      Icon(icon, size: 13, color: context.appTextSecondary),
      const SizedBox(width: 6),
      Text(category.toUpperCase(),
          style: TextStyle(fontSize: 10, letterSpacing: 1.1,
              color: context.appTextSecondary, fontWeight: FontWeight.w700)),
      const SizedBox(width: 10),
      Expanded(child: Divider(color: context.appBorder)),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Print Dialog — batch select, preview, real ZPL/TCP printing
// ─────────────────────────────────────────────────────────────────────────────
class _PrintDialog extends StatefulWidget {
  final LabelTemplate template;
  final PrinterConfig printer;
  final List<Map<String, dynamic>> initialRecords;
  final String entityType;

  const _PrintDialog({
    required this.template,
    required this.printer,
    this.initialRecords = const [],
    this.entityType = 'General',
  });

  @override
  State<_PrintDialog> createState() => _PrintDialogState();
}

class _PrintDialogState extends State<_PrintDialog> {
  List<Map<String, dynamic>> _records = [];
  late List<bool> _selected;
  int _previewIndex = 0;
  bool _loading = false;
  bool _isPrinting = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _records = List.from(widget.initialRecords);
    _selected = List.filled(_records.length, true);
  }

  List<Map<String, dynamic>> get _selectedRecords =>
      [for (int i = 0; i < _records.length; i++) if (_selected[i]) _records[i]];

  int get _totalLabels => (_selectedRecords.isEmpty ? 1 : _selectedRecords.length) * widget.template.copies;

  Map<String, dynamic> get _previewData {
    if (_records.isEmpty) return _sampleDataFor(widget.entityType);
    return _records[_previewIndex.clamp(0, _records.length - 1)];
  }

  Future<void> _loadFromDb() async {
    setState(() { _loading = true; _status = null; });
    try {
      final rows = await Supabase.instance.client
          .from(_tableForEntity(widget.entityType))
          .select() as List<dynamic>;
      setState(() {
        _records = rows.cast<Map<String, dynamic>>();
        _selected = List.filled(_records.length, true);
        _previewIndex = 0;
        _loading = false;
      });
    } catch (e) {
      setState(() { _loading = false; _status = 'Failed to load: $e'; });
    }
  }

  Future<void> _doPrint() async {
    if (_isPrinting) return;
    final proto = widget.printer.protocol == 'brother_ql' ? 'Brother QL' : 'ZPL';
    setState(() { _isPrinting = true; _status = 'Generating $proto data…'; });
    try {
      final batch = _selectedRecords.isEmpty ? <Map<String, dynamic>>[] : _selectedRecords;
      setState(() => _status = 'Connecting to ${widget.printer.ipAddress}…');
      await _sendToPrinter(widget.template, batch, widget.printer);
      final n = _totalLabels;
      setState(() {
        _isPrinting = false;
        _status = 'Sent $n label${n != 1 ? 's' : ''} to printer ✓';
      });
    } catch (e) {
      setState(() {
        _isPrinting = false;
        _status = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasRecords = _records.isNotEmpty;
    final isError = _status != null && _status!.startsWith('Error');
    final isDone = _status != null && _status!.contains('✓');

    return Dialog(
      backgroundColor: context.appSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 560),
        child: Column(children: [
          // ── Header ──────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
            child: Row(children: [
              const Icon(Icons.print_rounded, size: 18, color: AppDS.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.template.name,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.appTextPrimary)),
                  Text('${widget.template.labelW.toInt()}×${widget.template.labelH.toInt()} mm · ${widget.entityType}',
                      style: TextStyle(fontSize: 11, color: context.appTextSecondary)),
                ]),
              ),
              IconButton(
                icon: Icon(Icons.close, size: 18, color: context.appTextSecondary),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),
          Divider(height: 1, color: context.appBorder),

          // ── Body ────────────────────────────────────────────────────────
          Expanded(
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Left: preview + navigation
              Container(
                width: 220,
                color: const Color(0xFF0A0F1A),
                child: Column(children: [
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 12)],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: _PreviewCanvas(template: widget.template, scale: 3.0, sampleData: _previewData),
                          ),
                          if (!hasRecords) ...[
                            const SizedBox(height: 10),
                            Text('Sample preview', style: TextStyle(fontSize: 10, color: context.appTextSecondary)),
                          ],
                        ]),
                      ),
                    ),
                  ),
                  // Record navigation
                  if (hasRecords)
                    Container(
                      color: context.appSurface,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: Row(children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left_rounded, size: 18),
                          color: context.appTextSecondary,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          onPressed: _previewIndex > 0
                              ? () => setState(() => _previewIndex--)
                              : null,
                        ),
                        Expanded(
                          child: Text(
                            '${_previewIndex + 1} / ${_records.length}',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 11, color: context.appTextSecondary),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right_rounded, size: 18),
                          color: context.appTextSecondary,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          onPressed: _previewIndex < _records.length - 1
                              ? () => setState(() => _previewIndex++)
                              : null,
                        ),
                      ]),
                    ),
                ],
              )),
              VerticalDivider(width: 1, color: context.appBorder),

              // Right: record list or empty state
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: AppDS.accent, strokeWidth: 2))
                    : hasRecords
                        ? _RecordList(
                            records: _records,
                            selected: _selected,
                            previewIndex: _previewIndex,
                            onToggle: (i) => setState(() => _selected[i] = !_selected[i]),
                            onToggleAll: () => setState(() {
                              final allOn = _selected.every((s) => s);
                              for (int i = 0; i < _selected.length; i++) { _selected[i] = !allOn; }
                            }),
                            onTapRow: (i) => setState(() => _previewIndex = i),
                          )
                        : _EmptyRecordsPanel(
                            entityType: widget.entityType,
                            onLoad: _loadFromDb,
                          ),
              ),
            ]),
          ),
          Divider(height: 1, color: context.appBorder),

          // ── Footer ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Row(children: [
              // Status
              Expanded(
                child: _status != null
                    ? Text(_status!,
                        style: TextStyle(
                          fontSize: 11,
                          color: isError ? AppDS.red : isDone ? AppDS.green : context.appTextSecondary,
                        ))
                    : Text(
                        hasRecords
                            ? '${_selectedRecords.length} of ${_records.length} records · $_totalLabels label${_totalLabels != 1 ? 's' : ''}'
                            : '1 label (sample data)',
                        style: TextStyle(fontSize: 11, color: context.appTextSecondary),
                      ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close', style: TextStyle(color: context.appTextSecondary)),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor: AppDS.accent, foregroundColor: AppDS.bg,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                icon: _isPrinting
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: AppDS.bg, strokeWidth: 2))
                    : const Icon(Icons.print_rounded, size: 15),
                label: Text(_isPrinting ? 'Printing…' : 'Print', style: const TextStyle(fontSize: 13)),
                onPressed: _isPrinting ? null : _doPrint,
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _RecordList extends StatelessWidget {
  final List<Map<String, dynamic>> records;
  final List<bool> selected;
  final int previewIndex;
  final void Function(int) onToggle;
  final VoidCallback onToggleAll;
  final void Function(int) onTapRow;

  const _RecordList({
    required this.records, required this.selected,
    required this.previewIndex, required this.onToggle,
    required this.onToggleAll, required this.onTapRow,
  });

  // Pick the most meaningful display field from a record
  String _recordLabel(Map<String, dynamic> r) {
    for (final k in ['strain_code', 'reagent_code', 'eq_code', 'sample_code', 'code', 'name', 'id']) {
      if (r[k] != null) return r[k].toString();
    }
    return r.values.firstOrNull?.toString() ?? '—';
  }

  String _recordSubLabel(Map<String, dynamic> r) {
    for (final k in ['strain_species', 'reagent_name', 'eq_name', 'sample_type', 'name', 'type']) {
      if (r[k] != null) return r[k].toString();
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final allSelected = selected.every((s) => s);
    return Column(children: [
      // Select all row
      InkWell(
        onTap: onToggleAll,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          color: context.appSurface,
          child: Row(children: [
            Icon(allSelected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                size: 17, color: allSelected ? AppDS.accent : context.appTextSecondary),
            const SizedBox(width: 10),
            Text(allSelected ? 'Deselect all' : 'Select all',
                style: TextStyle(fontSize: 12, color: context.appTextSecondary)),
            const Spacer(),
            Text('${selected.where((s) => s).length}/${records.length}',
                style: TextStyle(fontSize: 11, color: context.appTextSecondary)),
          ]),
        ),
      ),
      Divider(height: 1, color: context.appBorder),
      Expanded(
        child: ListView.builder(
          itemCount: records.length,
          itemBuilder: (ctx, i) {
            final isPreview = i == previewIndex;
            return InkWell(
              onTap: () => onTapRow(i),
              child: Container(
                color: isPreview ? AppDS.accent.withValues(alpha: 0.08) : Colors.transparent,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => onToggle(i),
                    child: Icon(
                      selected[i] ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                      size: 16, color: selected[i] ? AppDS.accent : context.appTextSecondary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_recordLabel(records[i]),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                            color: isPreview ? AppDS.accent : ctx.appTextPrimary),
                        overflow: TextOverflow.ellipsis),
                    if (_recordSubLabel(records[i]).isNotEmpty)
                      Text(_recordSubLabel(records[i]),
                          style: TextStyle(fontSize: 10, color: ctx.appTextSecondary),
                          overflow: TextOverflow.ellipsis),
                  ])),
                  if (isPreview)
                    const Icon(Icons.visibility_rounded, size: 13, color: AppDS.accent),
                ]),
              ),
            );
          },
        ),
      ),
    ]);
  }
}

class _EmptyRecordsPanel extends StatelessWidget {
  final String entityType;
  final VoidCallback onLoad;
  const _EmptyRecordsPanel({required this.entityType, required this.onLoad});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.table_rows_outlined, size: 40, color: context.appTextSecondary),
          const SizedBox(height: 14),
          Text('No records loaded', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.appTextPrimary)),
          const SizedBox(height: 6),
          Text('Load $entityType from the database to print with real data,\nor print now using sample placeholder values.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: context.appTextSecondary)),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
                foregroundColor: AppDS.accent, side: const BorderSide(color: AppDS.accent)),
            icon: const Icon(Icons.download_rounded, size: 15),
            label: Text('Load all $entityType', style: const TextStyle(fontSize: 12)),
            onPressed: onLoad,
          ),
        ]),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _Pill(this.label, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final LabelTemplate template;
  final bool isActive;
  final VoidCallback onSelect, onEdit, onDelete, onPrint;
  const _TemplateCard({
    required this.template, required this.isActive,
    required this.onSelect, required this.onEdit,
    required this.onDelete, required this.onPrint,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelect,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: context.appSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? AppDS.accent : context.appBorder,
            width: isActive ? 1.5 : 1,
          ),
          boxShadow: isActive ? [BoxShadow(color: AppDS.accent.withValues(alpha: 0.15), blurRadius: 12)] : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            // Preview thumbnail
            Container(
              width: 90, height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: context.appBorder),
              ),
              clipBehavior: Clip.antiAlias,
              child: FittedBox(
                fit: BoxFit.contain,
                child: _PreviewCanvas(
                  template: template, scale: 1.5,
                  sampleData: _sampleDataFor(template.category),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(template.name,
                    style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: isActive ? AppDS.accent : context.appTextPrimary,
                    )),
              ]),
              const SizedBox(height: 3),
              Text('${template.labelW.toInt()}×${template.labelH.toInt()} mm · ${template.fields.length} fields',
                  style: TextStyle(fontSize: 11, color: context.appTextSecondary)),
            ])),
            if (isActive) const Icon(Icons.check_circle_rounded, color: AppDS.accent, size: 16),
            const SizedBox(width: 8),
            _IconBtn(icon: Icons.edit_outlined, onTap: onEdit, tooltip: 'Edit'),
            _IconBtn(icon: Icons.print_rounded, onTap: onPrint, tooltip: 'Print'),
            _IconBtn(icon: Icons.delete_outline_rounded, onTap: onDelete,
                tooltip: 'Delete', color: AppDS.red),
          ]),
        ),
      ),
    );
  }
}



class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final Color color;
  const _IconBtn({required this.icon, required this.onTap, required this.tooltip, this.color = AppDS.textSecondary});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 17, color: color),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Field renderer — used in both builder canvas and preview
// ─────────────────────────────────────────────────────────────────────────────
class _FieldRenderer extends StatelessWidget {
  final LabelField field;
  final double scale;
  final Map<String, dynamic>? data;

  const _FieldRenderer({required this.field, this.scale = 1, this.data});

  String get _resolvedContent {
    if (data == null) return field.content;
    String s = field.content;
    data!.forEach((k, v) {
      s = s.replaceAll('{$k}', v?.toString() ?? '');
    });
    return s;
  }

  @override
  Widget build(BuildContext context) {
    return switch (field.type) {
      LabelFieldType.text => Align(
        alignment: Alignment.topLeft,
        child: Text(_resolvedContent,
          style: TextStyle(
            // Convert pt → canvas px so the font is proportional to the label size
            fontSize: (field.fontSize * scale * (25.4 / 72)).clamp(4.0, 200.0),
            fontWeight: field.fontWeight,
            color: field.color,
          ),
          textAlign: field.textAlign,
          overflow: TextOverflow.clip,
        ),
      ),
      LabelFieldType.qrcode => Center(
        child: QrImageView(
          data: _resolvedContent.isEmpty ? 'QR' : _resolvedContent,
          version: QrVersions.auto,
          size: field.h * scale * 0.9,
          eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
          dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
          backgroundColor: Colors.white,
        ),
      ),
      LabelFieldType.barcode => Center(child: CustomPaint(
        painter: _BarcodePlaceholderPainter(),
        size: Size(field.w * scale, field.h * scale * 0.8),
      )),
      LabelFieldType.divider => Container(
        height: 1,
        margin: EdgeInsets.symmetric(vertical: (field.h * scale / 2 - 0.5).clamp(0, 100)),
        color: field.color,
      ),
      LabelFieldType.image => Container(
        color: Colors.grey.shade200,
        child: const Icon(Icons.image_outlined, size: 16, color: Colors.grey),
      ),
    };
  }
}

class _BarcodePlaceholderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.black;
    final widths = [2.0, 1.0, 3.0, 1.0, 2.0, 1.0, 1.0, 3.0, 2.0, 1.0, 2.0, 1.0, 3.0, 1.0, 2.0];
    double x = 0;
    bool draw = true;
    for (final w in widths) {
      final barW = w / widths.fold(0.0, (a, b) => a + b) * size.width;
      if (draw) canvas.drawRect(Rect.fromLTWH(x, 0, barW - 0.5, size.height), p);
      x += barW;
      draw = !draw;
    }
  }
  @override bool shouldRepaint(_) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Preview canvas (read-only — used in template cards & print dialog)
// ─────────────────────────────────────────────────────────────────────────────
class _PreviewCanvas extends StatelessWidget {
  final LabelTemplate template;
  final double scale;
  final Map<String, dynamic>? sampleData;

  const _PreviewCanvas({required this.template, this.scale = 2.0, this.sampleData});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: template.labelW * scale,
      height: template.labelH * scale,
      color: Colors.white,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: template.fields.map((f) => Positioned(
          left: f.x * scale, top: f.y * scale,
          child: SizedBox(
            width: f.w * scale, height: f.h * scale,
            child: _FieldRenderer(field: f, scale: scale, data: sampleData),
          ),
        )).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Extension helpers
// ─────────────────────────────────────────────────────────────────────────────
extension _IterableFirstOrNull<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}
