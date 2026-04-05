// driver_brother_ql_570.dart — Part of label_page.dart.
// Brother QL legacy raster protocol driver.
// Covers: QL-500, QL-550, QL-570, QL-650TD.
// Fixed at 300 DPI, USB only.
//
// These models use the older Brother raster command set. Per Brother's
// "Brother QL Series Command Reference" (October 3, 2011, version 6.0),
// legacy QL jobs should send:
// - ESC i z print information
// - ESC i M auto-cut mode where supported
// - ESC i A cut-every-N where supported
// - ESC i K expanded mode where supported
// - ESC i d feed margin
// - raster graphics transfer with the legacy byte order 67 00 5A for 90-byte lines
//
// All QL-570-class media handling and send orchestration live in this file.
// Nothing is shared with driver_brother_ql_700.dart.

part of '../label_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Driver info
// ─────────────────────────────────────────────────────────────────────────────

/// Supported tape widths (mm) for QL-570 and compatible legacy models.
const _kQl570SupportedWidths = [12, 17, 23, 29, 38, 50, 54, 58, 62];

/// Fixed DPI for all legacy QL models (hardware limitation).
const _kQl570Dpi = 300;

/// Bytes per raster line for legacy models (720 dots / 8, fixed at 300 DPI).
const _kQl570BytesPerLine = 90;

/// Total dot width per raster line for legacy models (fixed at 300 DPI).
const _kQl570TotalDots = 720;

/// Printable dot widths per tape width (mm) at 300 DPI, from the Brother QL spec.
/// The printable area is always smaller than the physical tape width due to margins.
const _kQl570PrintableDots300 = <int, int>{
  12: 120, 17: 165, 23: 202, 29: 306,
  38: 413, 50: 554, 54: 590, 58: 618, 62: 696,
};

const _kQl570MediaTypeContinuous = 0x0A;
const _kQl570MediaTypeDieCut = 0x0B;
const _kQl570PrintInfoFlags = 0x0E;
const _kQl570AutoCutFlag = 0x40;
const _kQl570CutAtEndFlag = 0x08;

const _kQl570ContinuousSpecs = <int, ({int printableDots, int leftMarginDots})>{
  12: (printableDots: 106, leftMarginDots: 585),
  29: (printableDots: 306, leftMarginDots: 408),
  38: (printableDots: 413, leftMarginDots: 295),
  50: (printableDots: 554, leftMarginDots: 154),
  54: (printableDots: 590, leftMarginDots: 130),
  62: (printableDots: 696, leftMarginDots: 12),
};

const _kQl570DieCutSpecs = <String, ({int printableDots, int leftMarginDots})>{
  '17x54': (printableDots: 165, leftMarginDots: 555),
  '17x87': (printableDots: 165, leftMarginDots: 555),
  '23x23': (printableDots: 236, leftMarginDots: 442),
  '29x90': (printableDots: 306, leftMarginDots: 408),
  '38x90': (printableDots: 413, leftMarginDots: 295),
  '39x48': (printableDots: 425, leftMarginDots: 289),
  '52x29': (printableDots: 578, leftMarginDots: 142),
  '54x29': (printableDots: 578, leftMarginDots: 142),
  '62x29': (printableDots: 696, leftMarginDots: 12),
  '62x30': (printableDots: 696, leftMarginDots: 12),
  '62x100': (printableDots: 696, leftMarginDots: 12),
};

typedef _Ql570MediaSpec = ({
  int mediaType,
  int tapeWidthMm,
  int labelLengthMm,
  int printableDots,
  int leftMarginDots,
  int marginDots,
});

/// Returns the number of printable dots for a given tape width.
/// Legacy models are always 300 DPI; falls back to an approximate formula for unlisted widths.
int _ql570PrintableDots(double tapeMm) {
  final key = tapeMm.round();
  return _kQl570PrintableDots300[key]
      ?? ((tapeMm * 300 / 25.4) * 0.88).round().clamp(1, 720).toInt();
}

String _ql570ModelKey(PrinterConfig cfg) =>
    cfg.deviceName.trim().toLowerCase().replaceAll(' ', '');

bool _ql570SupportsAutoCut(PrinterConfig cfg) =>
    !_ql570ModelKey(cfg).contains('ql-500');

bool _ql570SupportsCutEvery(PrinterConfig cfg) =>
    _ql570ModelKey(cfg).contains('ql-570');

bool _ql570SupportsExpandedMode(PrinterConfig cfg) {
  final key = _ql570ModelKey(cfg);
  return key.contains('ql-570') || key.contains('650td');
}

int _ql570ContinuousMarginDots(PrinterConfig cfg) {
  final key = _ql570ModelKey(cfg);
  if (key.contains('ql-550') || key.contains('ql-570')) {
    return 35;
  }
  return 0;
}

int _ql570CutEveryCount(String cutMode, int totalPages) {
  if (cutMode == 'end') {
    return totalPages.clamp(1, 255).toInt();
  }
  return 1;
}

_Ql570MediaSpec _ql570MediaSpec(LabelTemplate tpl, PrinterConfig cfg) {
  final width = tpl.labelW.round();
  final length = tpl.labelH.round();
  if (cfg.continuousRoll) {
    final spec = _kQl570ContinuousSpecs[width];
    if (spec != null) {
      return (
        mediaType: _kQl570MediaTypeContinuous,
        tapeWidthMm: width.clamp(0, 255).toInt(),
        labelLengthMm: length.clamp(0, 255).toInt(),
        printableDots: spec.printableDots,
        leftMarginDots: spec.leftMarginDots,
        marginDots: _ql570ContinuousMarginDots(cfg),
      );
    }
  } else {
    final spec = _kQl570DieCutSpecs['${width}x$length'];
    if (spec != null) {
      return (
        mediaType: _kQl570MediaTypeDieCut,
        tapeWidthMm: width.clamp(0, 255).toInt(),
        labelLengthMm: length.clamp(0, 255).toInt(),
        printableDots: spec.printableDots,
        leftMarginDots: spec.leftMarginDots,
        marginDots: 0,
      );
    }
  }

  final printable = _ql570PrintableDots(tpl.labelW);
  return (
    mediaType: cfg.continuousRoll ? _kQl570MediaTypeContinuous : _kQl570MediaTypeDieCut,
    tapeWidthMm: width.clamp(0, 255).toInt(),
    labelLengthMm: length.clamp(0, 255).toInt(),
    printableDots: printable,
    leftMarginDots: (_kQl570TotalDots - printable) ~/ 2,
    marginDots: cfg.continuousRoll ? _ql570ContinuousMarginDots(cfg) : 0,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Cut logic
// ─────────────────────────────────────────────────────────────────────────────

/// End byte for a die-cut label: always 0x1A (advance past gap + cut).
const _kQl570DieCutEndByte = 0x1A;

// ─────────────────────────────────────────────────────────────────────────────
// Cut logic (continuous roll only)
// ─────────────────────────────────────────────────────────────────────────────

/// End byte for a continuous-roll label at index [pageIdx] of [totalPages].
///
/// | cutMode    | position    | byte | meaning              |
/// |------------|-------------|------|----------------------|
/// | 'none'     | any         | 0x0C | feed, no cut         |
/// | 'between'  | any         | 0x1A | feed + cut           |
/// | 'end'      | not last    | 0x0C | feed, no cut         |
/// | 'end'      | last        | 0x1A | feed + cut           |
int _ql570ContinuousEndByte(String cutMode, int pageIdx, int totalPages) {
  final isLast = pageIdx == totalPages - 1;
  if (cutMode == 'none') return 0x0C;
  if (cutMode == 'end' && !isLast) return 0x0C;
  return 0x1A;
}

// ─────────────────────────────────────────────────────────────────────────────
// Raster bit helper
// ─────────────────────────────────────────────────────────────────────────────

/// Sets one printable dot in a 90-byte raster line.
///
/// [dot] is the 0-based position within the printable area (0 = left edge).
/// [leftOffset] centers the printable area in the 720-dot head.
///
/// Brother QL byte 0 MSB = rightmost head dot (dot 719). The reversal formula
/// places dot 0 (leftmost printable) at byte 88 and dot N-1 at byte 1.
void _ql570SetDot(List<int> line, int dot, int leftOffset) {
  final physDot = leftOffset + dot;
  final revDot  = _kQl570TotalDots - 1 - physDot;
  line[revDot ~/ 8] |= (1 << (7 - revDot % 8));
}

// ─────────────────────────────────────────────────────────────────────────────
// Entry point
// ─────────────────────────────────────────────────────────────────────────────

/// Dispatches to the correct sub-protocol based on media type.
Future<Uint8List> _generateBrotherQl570Data(
    LabelTemplate tpl, List<Map<String, dynamic>> records, PrinterConfig cfg) =>
    cfg.continuousRoll
        ? _ql570Continuous(tpl, records, cfg)
        : _ql570DieCut(tpl, records, cfg);

List<int> _ql570PageHeader(
  LabelTemplate tpl,
  PrinterConfig cfg,
  _Ql570MediaSpec spec, {
  required int rasterLines,
  required int pageIdx,
  required int totalPages,
}) {
  final pageHeader = <int>[
    0x1B,
    0x69,
    0x7A,
    _kQl570PrintInfoFlags,
    spec.mediaType,
    spec.tapeWidthMm,
    spec.labelLengthMm,
    rasterLines & 0xFF,
    (rasterLines >> 8) & 0xFF,
    (rasterLines >> 16) & 0xFF,
    (rasterLines >> 24) & 0xFF,
    pageIdx == 0 ? 0x00 : 0x01,
    0x00,
  ];

  final autoCut = tpl.cutMode != 'none' && _ql570SupportsAutoCut(cfg);
  if (_ql570SupportsAutoCut(cfg)) {
    pageHeader.addAll([0x1B, 0x69, 0x4D, autoCut ? _kQl570AutoCutFlag : 0x00]);
  }
  if (autoCut && _ql570SupportsCutEvery(cfg)) {
    pageHeader.addAll([0x1B, 0x69, 0x41, _ql570CutEveryCount(tpl.cutMode, totalPages)]);
  }
  if (_ql570SupportsExpandedMode(cfg)) {
    pageHeader.addAll([
      0x1B,
      0x69,
      0x4B,
      tpl.cutMode == 'end' ? _kQl570CutAtEndFlag : 0x00,
    ]);
  }
  pageHeader.addAll([
    0x1B,
    0x69,
    0x64,
    spec.marginDots & 0xFF,
    (spec.marginDots >> 8) & 0xFF,
  ]);
  return pageHeader;
}

void _ql570WriteRasterRows(
  BytesBuilder buf,
  Uint8List rgba, {
  required int imageWidth,
  required int imageHeight,
  required int leftMarginDots,
}) {
  for (int row = 0; row < imageHeight; row++) {
    final line = List<int>.filled(_kQl570BytesPerLine, 0);
    for (int dot = 0; dot < imageWidth; dot++) {
      final idx = (row * imageWidth + dot) * 4;
      final gray =
          (rgba[idx] * 0.299 + rgba[idx + 1] * 0.587 + rgba[idx + 2] * 0.114)
              .round();
      if (gray < 128) {
        _ql570SetDot(line, dot, leftMarginDots);
      }
    }
    buf.add(const [0x67, 0x00, _kQl570BytesPerLine]);
    buf.add(line);
  }
}

Future<void> _sendBrotherQl570(PrinterConfig cfg, Uint8List data) async {
  if (cfg.connectionType != 'usb') {
    throw UnsupportedError('Brother QL-570 legacy printers only support USB.');
  }
  await _sendViaUsb(cfg.usbPath, data);
}

Future<void> _printBrotherQl570(
    LabelTemplate tpl, List<Map<String, dynamic>> records, PrinterConfig cfg) async {
  final data = await _generateBrotherQl570Data(tpl, records, cfg);
  debugPrint('[PRINT] QL-570 legacy data: ${data.length} bytes -> USB "${cfg.usbPath}"');
  await _sendBrotherQl570(cfg, data);
}

Future<_ConnState> _checkBrotherQl570Connection(PrinterConfig cfg) async {
  if (cfg.connectionType != 'usb') {
    return _ConnState.unreachable;
  }
  return _checkUsbPrinterConnection(cfg.usbPath);
}

double _ql570PrintableWidthMm(LabelTemplate tpl, PrinterConfig cfg) {
  final spec = _ql570MediaSpec(tpl, cfg);
  return spec.printableDots / _kQl570Dpi * 25.4;
}

// ─────────────────────────────────────────────────────────────────────────────
// Die-cut
// ─────────────────────────────────────────────────────────────────────────────

/// Generates raster data for die-cut labels on QL-570 compatible printers.
///
/// Image is rendered at EXACTLY [printable] pixels wide so each pixel maps 1:1
/// to a printable dot — no fractional-pixel scaling in the raster loop.
/// Height uses floor() to avoid a spurious extra partial-dot line.
Future<Uint8List> _ql570DieCut(
    LabelTemplate tpl, List<Map<String, dynamic>> records, PrinterConfig cfg) async {
  final printRecords = records.isEmpty ? [<String, dynamic>{}] : records;
  final buf = BytesBuilder();
  final spec = _ql570MediaSpec(tpl, cfg);
  final totalPages = printRecords.fold(0, (s, _) => s + tpl.copies);
  int pageIdx = 0;

  buf.add(List.filled(200, 0));
  buf.add(const [0x1B, 0x40]);

  debugPrint('[QL570] mode=die-cut tape=${tpl.labelW}mm label=${tpl.labelW}×${tpl.labelH}mm '
      'printable=${spec.printableDots} dots leftMargin=${spec.leftMarginDots} copies=${tpl.copies} records=${printRecords.length}');
  debugPrint('[QL570] fields=${tpl.fields.length} topOffsetMm=${tpl.topOffsetMm} cutMode=${tpl.cutMode}');

  for (final record in printRecords) {
    for (int c = 0; c < tpl.copies; c++) {
      final image = await _renderLabelToImage(tpl, record, _kQl570Dpi,
          floorHeight: true, printableW: spec.printableDots);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) continue;
      final rgba = byteData.buffer.asUint8List();
      final iw = image.width;
      final ih = image.height;

      buf.add(_ql570PageHeader(
        tpl,
        cfg,
        spec,
        rasterLines: ih,
        pageIdx: pageIdx,
        totalPages: totalPages,
      ));

      debugPrint('[QL570] die-cut copy=${c + 1} image=$iw×${ih}px '
          '(${(iw/(_kQl570Dpi/25.4)).toStringAsFixed(1)}×${(ih/(_kQl570Dpi/25.4)).toStringAsFixed(1)}mm) '
          'rasterLines=$ih endByte=0x${_kQl570DieCutEndByte.toRadixString(16).toUpperCase()}');

      _ql570WriteRasterRows(
        buf,
        rgba,
        imageWidth: iw,
        imageHeight: ih,
        leftMarginDots: spec.leftMarginDots,
      );
      buf.addByte(_kQl570DieCutEndByte);
      pageIdx++;
    }
  }
  debugPrint('[QL570] die-cut total bytes=${buf.length}');
  return buf.toBytes();
}

// ─────────────────────────────────────────────────────────────────────────────
// Continuous roll
// ─────────────────────────────────────────────────────────────────────────────

/// Generates raster data for continuous-roll media on QL-570 compatible printers.
///
/// Each page carries its own legacy Brother job-data header, followed by raster
/// rows and a cut/feed end byte.
Future<Uint8List> _ql570Continuous(
    LabelTemplate tpl, List<Map<String, dynamic>> records, PrinterConfig cfg) async {
  final printRecords = records.isEmpty ? [<String, dynamic>{}] : records;
  final buf = BytesBuilder();
  final spec = _ql570MediaSpec(tpl, cfg);

  final totalPages = printRecords.fold(0, (s, _) => s + tpl.copies);
  debugPrint('[QL570] mode=continuous tape=${tpl.labelW}mm label=${tpl.labelW}×${tpl.labelH}mm '
      'printable=${spec.printableDots} dots leftMargin=${spec.leftMarginDots} copies=${tpl.copies} records=${printRecords.length} '
      'totalPages=$totalPages cutMode=${tpl.cutMode} topOffsetMm=${tpl.topOffsetMm}');
  debugPrint('[QL570] fields=${tpl.fields.length}');

  buf.add(List.filled(200, 0));
  buf.add(const [0x1B, 0x40]);

  int pageIdx = 0;
  for (final record in printRecords) {
    for (int c = 0; c < tpl.copies; c++, pageIdx++) {
      final image = await _renderLabelToImage(tpl, record, _kQl570Dpi,
          printableW: spec.printableDots);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) continue;
      final rgba = byteData.buffer.asUint8List();
      final iw = image.width;
      final ih = image.height;

      final endByte = _ql570ContinuousEndByte(tpl.cutMode, pageIdx, totalPages);
      buf.add(_ql570PageHeader(
        tpl,
        cfg,
        spec,
        rasterLines: ih,
        pageIdx: pageIdx,
        totalPages: totalPages,
      ));
      debugPrint('[QL570] continuous page=${pageIdx + 1}/$totalPages image=$iw×${ih}px '
          '(${(iw/(_kQl570Dpi/25.4)).toStringAsFixed(1)}×${(ih/(_kQl570Dpi/25.4)).toStringAsFixed(1)}mm) '
          'rasterLines=$ih endByte=0x${endByte.toRadixString(16).toUpperCase()} '
          '(${endByte == 0x1A ? "cut" : "no-cut"})');

      _ql570WriteRasterRows(
        buf,
        rgba,
        imageWidth: iw,
        imageHeight: ih,
        leftMarginDots: spec.leftMarginDots,
      );
      buf.addByte(endByte);
    }
  }
  debugPrint('[QL570] continuous total bytes=${buf.length}');
  return buf.toBytes();
}

// ─────────────────────────────────────────────────────────────────────────────
// Solid-black test print
// ─────────────────────────────────────────────────────────────────────────────

/// Generates a solid-black raster job for diagnostics.
///
/// Every printable dot is set, so the output should be a filled black rectangle
/// across the printable area for the selected media.
///
/// [continuousRoll] — true for continuous tape, false for die-cut labels.
/// [cutMode] — 'none' (0x0C feed only) | 'end' (0x1A feed+cut). Only used
///   when [continuousRoll] is true; die-cut always uses 0x1A.
Uint8List _ql570SolidBlack(double tapeMm, double labelHMm,
    {bool continuousRoll = false, String cutMode = 'end',
    String deviceName = 'Brother QL-570'}) {
  final tpl = LabelTemplate(
    id: '_ql570_test',
    name: 'QL570 Test',
    labelW: tapeMm,
    labelH: labelHMm,
    paperSize: '${tapeMm.round()}x${labelHMm.round()}',
    cutMode: cutMode,
    copies: 1,
  );
  final cfg = PrinterConfig(
    protocol: 'brother_ql_legacy',
    connectionType: 'usb',
    deviceName: deviceName,
    continuousRoll: continuousRoll,
  );
  final spec = _ql570MediaSpec(tpl, cfg);
  final height = (labelHMm * _kQl570Dpi / 25.4).floor();
  final endByte    = continuousRoll
      ? (cutMode == 'none' ? 0x0C : 0x1A)
      : _kQl570DieCutEndByte;

  debugPrint('[QL570] solid-black test tape=${tapeMm}mm height=${labelHMm}mm '
      'media=${continuousRoll ? "continuous" : "die-cut"} cutMode=$cutMode '
      'rasterLines=$height '
      'endByte=0x${endByte.toRadixString(16).toUpperCase()}');

  final buf = BytesBuilder();
  buf.add(List.filled(200, 0));
  buf.add(const [0x1B, 0x40]);
  buf.add(_ql570PageHeader(
    tpl,
    cfg,
    spec,
    rasterLines: height,
    pageIdx: 0,
    totalPages: 1,
  ));

  for (int row = 0; row < height; row++) {
    final line = List<int>.filled(_kQl570BytesPerLine, 0);
    for (int dot = 0; dot < spec.printableDots; dot++) {
      _ql570SetDot(line, dot, spec.leftMarginDots);
    }
    buf.add(const [0x67, 0x00, _kQl570BytesPerLine]);
    buf.add(line);
  }
  buf.addByte(endByte);

  final data = buf.toBytes();

  String hexDump(List<int> bytes, {int max = 5000}) {
    return bytes
        .take(max)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join(' ');
  }

  debugPrint('[QL570] HEX (first 200 bytes): ${hexDump(data)}');

  debugPrint('[QL570] solid-black total bytes=${buf.length}');
  return buf.toBytes();
}
