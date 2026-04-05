// label_builder_widgets.dart — Part of label_page.dart.
// Builder palette + canvas widgets: _PaletteBtn, _FieldListItem,
// _BuilderCanvas, _GridPainter.

part of '../label_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Builder helper widgets
// ─────────────────────────────────────────────────────────────────────────────
class _PaletteBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _PaletteBtn(this.label, this.icon, this.onTap);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(children: [
          Icon(icon, size: 15, color: AppDS.accent),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(fontSize: 12, color: context.appTextPrimary)),
        ]),
      ),
    );
  }
}

class _FieldListItem extends StatelessWidget {
  final LabelField field;
  final bool isSelected;
  final bool isMultiSelected;
  final VoidCallback onTap, onDelete;
  final VoidCallback? onToggleMultiSelect;
  const _FieldListItem({
    required this.field,
    required this.isSelected,
    required this.isMultiSelected,
    required this.onTap,
    required this.onDelete,
    this.onToggleMultiSelect,
  });

  IconData get _typeIcon => switch (field.type) {
    LabelFieldType.text    => Icons.text_fields_rounded,
    LabelFieldType.qrcode  => Icons.qr_code_2_rounded,
    LabelFieldType.barcode => Icons.barcode_reader,
    LabelFieldType.divider => Icons.horizontal_rule_rounded,
    LabelFieldType.image   => Icons.image_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final active = isSelected || isMultiSelected;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppDS.accent.withValues(alpha: 0.15)
              : isMultiSelected
                  ? AppDS.accent.withValues(alpha: 0.08)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: active ? AppDS.accent.withValues(alpha: 0.4) : Colors.transparent),
        ),
        child: Row(children: [
          GestureDetector(
            onTap: onToggleMultiSelect,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Icon(
                active ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                size: 14,
                color: active ? AppDS.accent : context.appTextMuted,
              ),
            ),
          ),
          Icon(_typeIcon, size: 13, color: active ? AppDS.accent : context.appTextSecondary),
          const SizedBox(width: 6),
          Expanded(child: Text(
            field.content.length > 16 ? '${field.content.substring(0, 16)}…' : field.content,
            style: TextStyle(fontSize: 11, color: active ? AppDS.accent : context.appTextPrimary),
            overflow: TextOverflow.ellipsis,
          )),
          InkWell(
            onTap: onDelete,
            child: Icon(Icons.close, size: 12, color: context.appTextSecondary),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Builder canvas (drag + resize)
// ─────────────────────────────────────────────────────────────────────────────
class _BuilderCanvas extends StatelessWidget {
  final LabelTemplate template;
  final double scale;
  final String? selectedId;
  final Set<String> selectedIds;
  final void Function(String id) onSelect;
  final void Function(String id, double dx, double dy) onMove;
  final void Function(String id, double dw, double dh) onResize;
  final Map<String, dynamic>? data;
  final double? printableW; // mm — dashed left/right margin lines
  final double? printableH; // mm — dashed top/bottom margin lines

  const _BuilderCanvas({
    required this.template, required this.scale,
    required this.selectedId, required this.selectedIds,
    required this.onSelect,
    required this.onMove, required this.onResize,
    this.data, this.printableW, this.printableH,
  });

  @override
  Widget build(BuildContext context) {
    final cw = template.labelW * scale;
    final ch = template.labelH * scale;
    final pw = printableW;
    final ph = printableH;
    final showH = pw != null && pw < template.labelW;
    final showV = ph != null && ph < template.labelH;

    return Container(
      width: cw, height: ch,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(3),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 20, spreadRadius: 2),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          CustomPaint(painter: _GridPainter(scale: scale), size: Size(cw, ch)),
          if (showH || showV)
            Positioned.fill(
              child: CustomPaint(
                painter: _PrintableAreaPainter(
                  marginHPx: showH ? (template.labelW - pw) / 2 * scale : 0,
                  marginVPx: showV ? (template.labelH - ph) / 2 * scale : 0,
                ),
              ),
            ),
          ...template.fields.map((f) {
            final isSelected = selectedId == f.id;
            final isMultiSelected = !isSelected && selectedIds.contains(f.id);
            return Positioned(
              left: f.x * scale, top: f.y * scale,
              child: GestureDetector(
                onTap: () => onSelect(f.id),
                onPanUpdate: (d) => onMove(f.id, d.delta.dx, d.delta.dy),
                child: Stack(clipBehavior: Clip.none, children: [
                  Container(
                    width: f.w * scale, height: f.h * scale,
                    decoration: isSelected
                        ? BoxDecoration(border: Border.all(color: AppDS.accent, width: 1.5))
                        : isMultiSelected
                            ? BoxDecoration(border: Border.all(
                                color: AppDS.accent.withValues(alpha: 0.5), width: 1.0,
                                style: BorderStyle.solid))
                            : null,
                    child: _FieldRenderer(field: f, scale: scale, data: data),
                  ),
                  if (isSelected)
                    Positioned(
                      right: 2, bottom: 2,
                      child: GestureDetector(
                        onPanUpdate: (d) => onResize(f.id, d.delta.dx, d.delta.dy),
                        child: Container(
                          width: 14, height: 14,
                          decoration: BoxDecoration(
                            color: AppDS.accent,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                        ),
                      ),
                    ),
                ]),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  final double scale;
  const _GridPainter({required this.scale});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppDS.tableBorder.withValues(alpha: 0.5)
      ..strokeWidth = 0.5;
    final step = 5 * scale;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => false;
}
