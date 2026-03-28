// label_preview_canvas.dart — Part of label_page.dart.
// Field rendering and preview canvas:
//   _FieldRenderer, _isHigherTaxon, _scientificNameText,
//   _BarcodePlaceholderPainter, _PreviewCanvas, _PrintableAreaPainter,
//   _IterableFirstOrNull.

part of '../label_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Field renderer — used in both builder canvas and preview
// ─────────────────────────────────────────────────────────────────────────────
class _FieldRenderer extends StatelessWidget {
  final LabelField field;
  final double scale;
  final Map<String, dynamic>? data;

  const _FieldRenderer({required this.field, this.scale = 1, this.data});

  String get _resolvedContent {
    final now = DateTime.now();
    final dateFmt = DateFormat('yyyy-MM-dd');
    final timeFmt = DateFormat('HH:mm');
    String s = field.content
        .replaceAll('{current_time}', timeFmt.format(now))
        .replaceAll('{current_date}', dateFmt.format(now));
    s = s.replaceAllMapped(RegExp(r'\{date\+(\d+)\}'), (m) {
      final n = int.tryParse(m.group(1) ?? '') ?? 0;
      return dateFmt.format(now.add(Duration(days: n)));
    });
    if (data != null) {
      data!.forEach((k, v) => s = s.replaceAll('{$k}', v?.toString() ?? ''));
    }
    return s;
  }

  @override
  Widget build(BuildContext context) {
    return switch (field.type) {
      LabelFieldType.text => field.content.contains('{strain_scientific_name}')
        ? _scientificNameText(
            _resolvedContent,
            TextStyle(
              fontSize: (field.fontSize * scale * (25.4 / 72)).clamp(4.0, 200.0),
              fontWeight: field.fontWeight,
              color: field.color,
            ),
            textAlign: field.textAlign,
            softWrap: true,
            overflow: TextOverflow.visible,
          )
        : Text(_resolvedContent,
          style: TextStyle(
            // Convert pt → canvas px so the font is proportional to the label size
            fontSize: (field.fontSize * scale * (25.4 / 72)).clamp(4.0, 200.0),
            fontWeight: field.fontWeight,
            color: field.color,
          ),
          textAlign: field.textAlign,
          softWrap: true,
          overflow: TextOverflow.visible,
        ),
      LabelFieldType.qrcode => FittedBox(
        fit: BoxFit.contain,
        child: QrImageView(
          data: _resolvedContent.isEmpty ? 'QR' : _resolvedContent,
          version: QrVersions.auto,
          size: 200,
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

// Suffixes that identify names at family rank and above (not italicised).
// Genus, species, and infraspecific epithets carry none of these endings.
bool _isHigherTaxon(String word) {
  const suffixes = [
    'aceae',    // family – plants, fungi, bacteria
    'idae',     // family – animals
    'oideae',   // subfamily – plants
    'inae',     // subfamily – animals
    'ales',     // order – plants, fungi, bacteria
    'iformes',  // order – vertebrates
    'phyceae',  // class – algae
    'mycetes',  // class – fungi
    'opsida',   // class – plants
    'mycota',   // phylum – fungi
    'phyta',    // phylum – plants
    'viridae',  // family – viruses
    'virales',  // order – viruses
  ];
  final lower = word.toLowerCase();
  return suffixes.any((s) => lower.endsWith(s));
}

// Renders a scientific name word-by-word:
// – abbreviations (ending in '.') and higher-taxon names (family and above)
//   stay upright; genus, species, and infraspecific epithets are italic.
Widget _scientificNameText(
  String name,
  TextStyle base, {
  TextAlign textAlign = TextAlign.start,
  bool softWrap = false,
  TextOverflow overflow = TextOverflow.ellipsis,
}) {
  final words = name.split(' ');
  final spans = <TextSpan>[];
  for (var i = 0; i < words.length; i++) {
    final word = words[i];
    final upright = word.endsWith('.') || _isHigherTaxon(word);
    spans.add(TextSpan(
      text: i < words.length - 1 ? '$word ' : word,
      style: base.copyWith(
        fontStyle: upright ? FontStyle.normal : FontStyle.italic,
      ),
    ));
  }
  return Text.rich(
    TextSpan(children: spans),
    textAlign: textAlign,
    softWrap: softWrap,
    overflow: overflow,
  );
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
  /// Printable width in mm — dashed left/right boundary lines (Brother QL horizontal margin).
  final double? printableW;
  /// Printable height in mm — dashed top/bottom boundary lines (Brother QL die-cut vertical margin).
  final double? printableH;

  const _PreviewCanvas({
    required this.template, this.scale = 2.0,
    this.sampleData, this.printableW, this.printableH,
  });

  @override
  Widget build(BuildContext context) {
    final pw = printableW;
    final ph = printableH;
    final showH = pw != null && pw < template.labelW;
    final showV = ph != null && ph < template.labelH;
    return Container(
      width: template.labelW * scale,
      height: template.labelH * scale,
      color: Colors.white,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          ...template.fields.map((f) => Positioned(
            left: f.x * scale, top: f.y * scale,
            child: SizedBox(
              width: f.w * scale, height: f.h * scale,
              child: _FieldRenderer(field: f, scale: scale, data: sampleData),
            ),
          )),
          if (showH || showV)
            Positioned.fill(
              child: CustomPaint(
                painter: _PrintableAreaPainter(
                  marginHPx: showH ? (template.labelW - pw) / 2 * scale : 0,
                  marginVPx: showV ? (template.labelH - ph) / 2 * scale : 0,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PrintableAreaPainter extends CustomPainter {
  final double marginHPx; // left/right margin in pixels
  final double marginVPx; // top/bottom margin in pixels
  const _PrintableAreaPainter({required this.marginHPx, this.marginVPx = 0});

  @override
  void paint(Canvas canvas, Size size) {
    if (marginHPx <= 0 && marginVPx <= 0) return;
    final paint = Paint()
      ..color = const Color(0xFF888888)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;
    const dashLen = 3.0;
    const gapLen  = 2.0;

    // Vertical dashed lines (left & right)
    if (marginHPx > 0) {
      for (final x in [marginHPx, size.width - marginHPx]) {
        double y = 0;
        while (y < size.height) {
          final end = (y + dashLen).clamp(0.0, size.height);
          canvas.drawLine(Offset(x, y), Offset(x, end), paint);
          y += dashLen + gapLen;
        }
      }
    }

    // Horizontal dashed lines (top & bottom)
    if (marginVPx > 0) {
      for (final y in [marginVPx, size.height - marginVPx]) {
        double x = 0;
        while (x < size.width) {
          final end = (x + dashLen).clamp(0.0, size.width);
          canvas.drawLine(Offset(x, y), Offset(end, y), paint);
          x += dashLen + gapLen;
        }
      }
    }
  }

  @override
  bool shouldRepaint(_PrintableAreaPainter old) =>
      old.marginHPx != marginHPx || old.marginVPx != marginVPx;
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
