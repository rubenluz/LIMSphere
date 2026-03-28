// brother_ql_570.dart — Part of label_page.dart.
// Brother QL legacy raster protocol driver.
// Covers: QL-500, QL-550, QL-570, QL-650TD.
// These older models do NOT support ESC i z or ESC i M.
// Fixed at 300 DPI, USB only.
//
// Die-cut protocol:  one complete [Invalidate + ESC@ + ESC i a + raster + 0x1A]
//                    job per label. The printer has no way to detect label
//                    boundaries from a command; each job triggers one cut.
//                    Uses floor() for raster height to avoid a spurious extra
//                    partial-dot line (29 mm × 300/25.4 = 342.52 → 342).
//
// Continuous protocol: single init for the whole batch; end byte drives cut.
//
// All media constants, cut logic, and raster helpers are self-contained here.
// Nothing is shared with brother_ql_700.dart.

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

/// Returns the number of printable dots for a given tape width.
/// Legacy models are always 300 DPI; falls back to an approximate formula for unlisted widths.
int _ql570PrintableDots(double tapeMm) {
  final key = tapeMm.round();
  return _kQl570PrintableDots300[key]
      ?? ((tapeMm * 300 / 25.4) * 0.88).round().clamp(1, 720);
}

// ─────────────────────────────────────────────────────────────────────────────
// Media type constants
// ─────────────────────────────────────────────────────────────────────────────

/// End byte for a die-cut label: always 0x1A (advance past gap + cut).
/// Using 0x0C on die-cut media causes subsequent labels to overprint on the
/// same spot on QL-570 and some other models.
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
// Entry point
// ─────────────────────────────────────────────────────────────────────────────

/// Dispatches to the correct sub-protocol based on media type.
Future<Uint8List> _generateBrotherQl570Data(
    LabelTemplate tpl, List<Map<String, dynamic>> records, PrinterConfig cfg) =>
    cfg.continuousRoll
        ? _ql570Continuous(tpl, records)
        : _ql570DieCut(tpl, records);

// ─────────────────────────────────────────────────────────────────────────────
// Die-cut
// ─────────────────────────────────────────────────────────────────────────────

/// Generates raster data for die-cut labels on QL-570 compatible printers.
///
/// Each label is a self-contained job:
///   Invalidate (200×0x00) + ESC @ + ESC i a + raster lines + 0x1A
///
/// No ESC i z, no ESC i M — these are QL-700+ commands and are either ignored
/// or corrupt internal state on legacy models.
/// Uses floor() for raster line count to avoid an extra partial line.
Future<Uint8List> _ql570DieCut(
    LabelTemplate tpl, List<Map<String, dynamic>> records) async {
  final printRecords = records.isEmpty ? [<String, dynamic>{}] : records;
  final buf = BytesBuilder();

  final printable  = _ql570PrintableDots(tpl.labelW);
  final leftOffset = (_kQl570TotalDots - printable) ~/ 2;

  for (final record in printRecords) {
    for (int c = 0; c < tpl.copies; c++) {
      // Full job init per label — QL-570 relies on per-job mechanics for
      // gap detection; there is no ESC i z to tell it the label height.
      buf.add(List.filled(200, 0));
      buf.add(const [0x1B, 0x40]);
      buf.add(const [0x1B, 0x69, 0x61, 0x01]);

      final image = await _renderLabelToImage(tpl, record, _kQl570Dpi, floorHeight: true);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) continue;
      final rgba = byteData.buffer.asUint8List();
      final iw = image.width;
      final ih = image.height;

      for (int row = 0; row < ih; row++) {
        final line = List<int>.filled(_kQl570BytesPerLine, 0);
        for (int dot = 0; dot < printable; dot++) {
          final col = (dot * iw ~/ printable).clamp(0, iw - 1);
          final idx = (row * iw + col) * 4;
          final gray = (rgba[idx] * 0.299 + rgba[idx + 1] * 0.587 + rgba[idx + 2] * 0.114).round();
          if (gray < 128) {
            final physDot = leftOffset + dot;
            final revDot  = _kQl570TotalDots - 1 - physDot;
            line[revDot ~/ 8] |= (1 << (7 - revDot % 8));
          }
        }
        buf.add([0x67, 0x00, _kQl570BytesPerLine]);
        buf.add(line);
      }

      buf.addByte(_kQl570DieCutEndByte); // 0x1A — feed past gap + cut
    }
  }
  return buf.toBytes();
}

// ─────────────────────────────────────────────────────────────────────────────
// Continuous roll
// ─────────────────────────────────────────────────────────────────────────────

/// Generates raster data for continuous-roll media on QL-570 compatible printers.
///
/// Single init for the whole batch; end byte per label controls cut behaviour.
Future<Uint8List> _ql570Continuous(
    LabelTemplate tpl, List<Map<String, dynamic>> records) async {
  final printRecords = records.isEmpty ? [<String, dynamic>{}] : records;
  final buf = BytesBuilder();

  buf.add(List.filled(200, 0));
  buf.add(const [0x1B, 0x40]);
  buf.add(const [0x1B, 0x69, 0x61, 0x01]);

  final printable  = _ql570PrintableDots(tpl.labelW);
  final leftOffset = (_kQl570TotalDots - printable) ~/ 2;

  final totalPages = printRecords.fold(0, (s, _) => s + tpl.copies);
  int pageIdx = 0;
  for (final record in printRecords) {
    for (int c = 0; c < tpl.copies; c++, pageIdx++) {
      final image = await _renderLabelToImage(tpl, record, _kQl570Dpi);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) continue;
      final rgba = byteData.buffer.asUint8List();
      final iw = image.width;
      final ih = image.height;

      for (int row = 0; row < ih; row++) {
        final line = List<int>.filled(_kQl570BytesPerLine, 0);
        for (int dot = 0; dot < printable; dot++) {
          final col = (dot * iw ~/ printable).clamp(0, iw - 1);
          final idx = (row * iw + col) * 4;
          final gray = (rgba[idx] * 0.299 + rgba[idx + 1] * 0.587 + rgba[idx + 2] * 0.114).round();
          if (gray < 128) {
            final physDot = leftOffset + dot;
            final revDot  = _kQl570TotalDots - 1 - physDot;
            line[revDot ~/ 8] |= (1 << (7 - revDot % 8));
          }
        }
        buf.add([0x67, 0x00, _kQl570BytesPerLine]);
        buf.add(line);
      }

      buf.addByte(_ql570ContinuousEndByte(tpl.cutMode, pageIdx, totalPages));
    }
  }
  return buf.toBytes();
}
