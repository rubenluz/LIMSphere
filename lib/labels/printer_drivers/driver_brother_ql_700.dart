// driver_brother_ql_700.dart — Part of label_page.dart.
// Brother QL modern raster protocol driver.
// Covers: QL-700, QL-800, QL-810W, QL-820NWB, and compatible models.
// Supports ESC i z print-info, USB + Wi-Fi, 300 and 600 DPI.
//
// All media constants, cut logic, and raster helpers are self-contained here.
// Nothing is shared with driver_brother_ql_570.dart.

part of '../label_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Driver info
// ─────────────────────────────────────────────────────────────────────────────

/// Printable dot widths per tape width (mm) at 300 DPI, from the Brother QL spec.
/// The printable area is always smaller than the physical tape width due to margins.
const _kQl700PrintableDots300 = <int, int>{
  12: 120, 17: 165, 23: 202, 29: 306,
  38: 413, 50: 554, 54: 590, 58: 618, 62: 696,
};

const _kQl700Port = 9100;

/// Returns the number of printable dots for a given tape width and DPI.
/// Falls back to an approximate formula for unlisted widths.
int _ql700PrintableDots(double tapeMm, int dpi) {
  final key = tapeMm.round();
  final base = _kQl700PrintableDots300[key]
      ?? ((tapeMm * 300 / 25.4) * 0.88).round().clamp(1, 720).toInt();
  return dpi == 600 ? base * 2 : base;
}

/// Total raster dots per line: 720 at 300 DPI, 1440 at 600 DPI.
int _ql700TotalDots(int dpi) => dpi == 600 ? 1440 : 720;

/// Bytes per raster line (totalDots / 8).
int _ql700BytesPerLine(int dpi) => _ql700TotalDots(dpi) ~/ 8;

double _ql700PrintableWidthMm(double tapeMm, int dpi) =>
    _ql700PrintableDots(tapeMm, dpi) / dpi * 25.4;

// ─────────────────────────────────────────────────────────────────────────────
// Media type constants (ESC i z print-info command)
// ─────────────────────────────────────────────────────────────────────────────

/// Media-type byte for continuous-roll tape.
const _kQl700MediaTypeContinuous = 0x0A;

/// Label-length field for continuous roll: 0 = printer self-detects from raster data.
const _kQl700LabelLenContinuous = 0;

/// Media-type byte for pre-cut (die-cut) labels.
const _kQl700MediaTypeDieCut = 0x0B;

/// End byte for a die-cut label: always 0x1A (advance past gap + cut).
const _kQl700DieCutEndByte = 0x1A;

// ─────────────────────────────────────────────────────────────────────────────
// Cut logic (continuous roll only)
// ─────────────────────────────────────────────────────────────────────────────

/// ESC i M auto-cut flag for continuous roll.
/// 0x40 = cutter enabled (fires when end byte 0x1A is sent).
/// 0x00 = cutter disabled (paper feeds without cutting on any end byte).
int _ql700ContinuousAutoCutFlag(String cutMode) =>
    cutMode != 'none' ? 0x40 : 0x00;

/// End byte for a continuous-roll label at index [pageIdx] of [totalPages].
///
/// | cutMode    | position    | byte | meaning              |
/// |------------|-------------|------|----------------------|
/// | 'none'     | any         | 0x0C | feed, no cut         |
/// | 'between'  | any         | 0x1A | feed + cut           |
/// | 'end'      | not last    | 0x0C | feed, no cut         |
/// | 'end'      | last        | 0x1A | feed + cut           |
int _ql700ContinuousEndByte(String cutMode, int pageIdx, int totalPages) {
  final isLast = pageIdx == totalPages - 1;
  if (cutMode == 'none') return 0x0C;
  if (cutMode == 'end' && !isLast) return 0x0C;
  return 0x1A;
}

// ─────────────────────────────────────────────────────────────────────────────
// Data generation
// ─────────────────────────────────────────────────────────────────────────────

/// Generates a Brother QL raster data blob for all [records].
/// Send the result via [_sendBrotherQl700] (Wi-Fi) or [_sendViaUsb] (USB).
///
/// Continuous roll: one initialisation + raster mode header for the whole batch.
/// Die-cut: each label gets its own ESC i z print-info per label so the gap
/// sensor resets cleanly. ESC @ and ESC i a are sent once per job — repeating
/// them causes a media-sensing advance that misaligns subsequent labels.
Future<Uint8List> _generateBrotherQl700Data(
    LabelTemplate tpl, List<Map<String, dynamic>> records, PrinterConfig cfg) async {
  final printRecords = records.isEmpty ? [<String, dynamic>{}] : records;
  final buf = BytesBuilder();

  final pxPerMm     = tpl.dpi / 25.4;
  final rasterH     = (tpl.labelH * pxPerMm).ceil();
  final rasterBytes = [rasterH & 0xFF, (rasterH >> 8) & 0xFF, (rasterH >> 16) & 0xFF, (rasterH >> 24) & 0xFF];
  final mediaTypeByte = cfg.continuousRoll ? _kQl700MediaTypeContinuous : _kQl700MediaTypeDieCut;
  final labelLenByte  = cfg.continuousRoll ? _kQl700LabelLenContinuous  : tpl.labelH.round();

  // Single initialisation for the whole job.
  // ESC @ and ESC i a must NOT be repeated per label — on die-cut media,
  // ESC @ triggers a media-sensing advance that misaligns every subsequent label.
  buf.add(List.filled(200, 0));               // Invalidate
  buf.add(const [0x1B, 0x40]);               // ESC @: initialize
  buf.add(const [0x1B, 0x69, 0x61, 0x01]);  // ESC i a: raster mode (once per job)
  if (cfg.continuousRoll) {
    buf.add([0x1B, 0x69, 0x4D, _ql700ContinuousAutoCutFlag(tpl.cutMode)]);
  } else {
    buf.add(const [0x1B, 0x69, 0x4D, 0x00]); // auto-cut off; 0x1A drives cut per label
  }

  final totalPages = printRecords.fold(0, (s, _) => s + tpl.copies);
  int pageIdx = 0;
  for (final record in printRecords) {
    for (int c = 0; c < tpl.copies; c++, pageIdx++) {

      // Print info (ESC i z).
      // PI flags: bit7=media type, bit6=tape width, bit5=label length.
      // All three set (0xEE) activates gap-detection for die-cut.
      buf.add([
        0x1B, 0x69, 0x7A,
        cfg.continuousRoll ? 0x8E : 0xEE,
        mediaTypeByte,
        tpl.labelW.round(),     // tape width in mm
        labelLenByte,           // 0 for continuous, label height for die-cut
        ...rasterBytes,         // raster line count (little-endian)
        0x00,                   // page# — always 0
        0,
      ]);

      final image = await _renderLabelToImage(tpl, record, tpl.dpi);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) continue;
      final rgba = byteData.buffer.asUint8List();
      final iw = image.width;
      final ih = image.height;

      // Raster line is always bytesPerLine wide regardless of tape width.
      // printableDots is the tape's actual print area; image is centered within totalDots.
      final bytesPerLine = _ql700BytesPerLine(tpl.dpi);
      final totalDots    = _ql700TotalDots(tpl.dpi);
      final printable    = _ql700PrintableDots(tpl.labelW, tpl.dpi);
      final leftOffset   = (totalDots - printable) ~/ 2;

      for (int row = 0; row < ih; row++) {
        final line = List<int>.filled(bytesPerLine, 0);
        for (int dot = 0; dot < printable; dot++) {
          final col = (dot * iw ~/ printable).clamp(0, iw - 1);
          final idx = (row * iw + col) * 4;
          final gray = (rgba[idx] * 0.299 + rgba[idx + 1] * 0.587 + rgba[idx + 2] * 0.114).round();
          if (gray < 128) {
            final physDot = leftOffset + dot;
            final revDot  = totalDots - 1 - physDot;
            line[revDot ~/ 8] |= (1 << (7 - revDot % 8));
          }
        }
        buf.add([0x67, 0x00, bytesPerLine]);
        buf.add(line);
      }

      final endByte = cfg.continuousRoll
          ? _ql700ContinuousEndByte(tpl.cutMode, pageIdx, totalPages)
          : _kQl700DieCutEndByte;
      buf.addByte(endByte);
    }
  }

  return buf.toBytes();
}

// ─────────────────────────────────────────────────────────────────────────────
// Communication
// ─────────────────────────────────────────────────────────────────────────────

/// Sends Brother QL raster data to the printer over raw TCP port 9100.
Future<void> _sendBrotherQl700(String ip, Uint8List data) async {
  final socket =
      await Socket.connect(ip, _kQl700Port, timeout: const Duration(seconds: 8));
  try {
    socket.add(data);
    await socket.flush();
  } finally {
    await socket.close();
  }
}

Future<void> _sendBrotherQl700Usb(PrinterConfig cfg, Uint8List data) async {
  if (cfg.connectionType != 'usb') {
    throw UnsupportedError('Brother QL USB send requires a USB profile.');
  }
  await _sendViaUsb(cfg.usbPath, data);
}

Future<_ConnState> _checkBrotherQl700Connection(PrinterConfig cfg) async {
  if (cfg.connectionType == 'usb') {
    return _checkUsbPrinterConnection(cfg.usbPath);
  }
  return _checkTcpPrinterConnection(cfg.ipAddress, _kQl700Port);
}

Future<void> _printBrotherQl700(
    LabelTemplate tpl, List<Map<String, dynamic>> records, PrinterConfig cfg) async {
  final data = await _generateBrotherQl700Data(tpl, records, cfg);
  if (cfg.connectionType == 'usb') {
    debugPrint('[PRINT] QL-700 raster data: ${data.length} bytes -> USB "${cfg.usbPath}"');
    await _sendBrotherQl700Usb(cfg, data);
  } else {
    debugPrint('[PRINT] QL-700 raster data: ${data.length} bytes -> TCP ${cfg.ipAddress}:$_kQl700Port');
    await _sendBrotherQl700(cfg.ipAddress, data);
  }
}
