// grid_widgets.dart - Shared data-table cell and column header widgets used
// across culture-collection and other grid pages.

import 'package:flutter/material.dart';
import 'theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Shared custom scrollbar thumbs used by all data-grid pages.
// ─────────────────────────────────────────────────────────────────────────────

// ── Horizontal scrollbar thumb ────────────────────────────────────────────────
class AppHorizontalThumb extends StatefulWidget {
  final double contentWidth;
  final ValueNotifier<double> offset;
  final void Function(double) onScrollTo;
  const AppHorizontalThumb({
    super.key,
    required this.contentWidth,
    required this.offset,
    required this.onScrollTo,
  });

  @override
  State<AppHorizontalThumb> createState() => _AppHorizontalThumbState();
}

class _AppHorizontalThumbState extends State<AppHorizontalThumb> {
  double? _dragStartX;
  double? _dragStartOffset;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, constraints) {
      final viewW    = constraints.maxWidth;
      final contentW = widget.contentWidth;
      if (contentW <= viewW) return const SizedBox(height: 10);
      final thumbW    = (viewW * viewW / contentW).clamp(40.0, viewW);
      final maxThumbX = viewW - thumbW;
      return SizedBox(
        height: 10,
        child: ValueListenableBuilder<double>(
          valueListenable: widget.offset,
          builder: (ctx, offset, _) {
            final maxOffset = contentW - viewW;
            final fraction  = maxOffset > 0 ? (offset / maxOffset).clamp(0.0, 1.0) : 0.0;
            final thumbX    = fraction * maxThumbX;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => widget.onScrollTo(
                  (d.localPosition.dx / viewW).clamp(0.0, 1.0) * maxOffset),
              onHorizontalDragStart: (d) {
                _dragStartX = d.localPosition.dx;
                _dragStartOffset = offset;
              },
              onHorizontalDragUpdate: (d) {
                if (_dragStartX == null) return;
                widget.onScrollTo(_dragStartOffset! +
                    (d.localPosition.dx - _dragStartX!) / maxThumbX * maxOffset);
              },
              child: CustomPaint(
                  painter: _HThumbPainter(thumbX: thumbX, thumbW: thumbW),
                  size: Size(viewW, 10)),
            );
          },
        ),
      );
    });
  }
}

class _HThumbPainter extends CustomPainter {
  final double thumbX, thumbW;
  const _HThumbPainter({required this.thumbX, required this.thumbW});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(0, 3, size.width, 4), const Radius.circular(2)),
        Paint()..color = AppDS.border);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(thumbX, 1, thumbW, 8), const Radius.circular(4)),
        Paint()..color = AppDS.textSecondary);
  }

  @override
  bool shouldRepaint(_HThumbPainter old) =>
      old.thumbX != thumbX || old.thumbW != thumbW;
}

// ── Vertical scrollbar thumb ──────────────────────────────────────────────────
class AppVerticalThumb extends StatefulWidget {
  final double contentLength;
  final double topPadding;
  final ValueNotifier<double> offset;
  final void Function(double) onScrollTo;
  const AppVerticalThumb({
    super.key,
    required this.contentLength,
    required this.topPadding,
    required this.offset,
    required this.onScrollTo,
  });
  @override State<AppVerticalThumb> createState() => _AppVerticalThumbState();
}

class _AppVerticalThumbState extends State<AppVerticalThumb> {
  double? _dragStartY;
  double? _dragStartOffset;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, constraints) {
      final totalH   = constraints.maxHeight;
      final viewH    = totalH - widget.topPadding;
      final contentH = widget.contentLength;
      if (contentH <= viewH) return const SizedBox(width: 10);
      final thumbH    = (viewH * viewH / contentH).clamp(40.0, viewH);
      final maxThumbY = viewH - thumbH;
      return SizedBox(
        width: 10,
        child: ValueListenableBuilder<double>(
          valueListenable: widget.offset,
          builder: (ctx, offset, _) {
            final maxOffset = contentH - viewH;
            final fraction  = maxOffset > 0 ? (offset / maxOffset).clamp(0.0, 1.0) : 0.0;
            final thumbY    = fraction * maxThumbY + widget.topPadding;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) {
                final ly = (d.localPosition.dy - widget.topPadding).clamp(0.0, viewH);
                widget.onScrollTo((ly / viewH).clamp(0.0, 1.0) * maxOffset);
              },
              onVerticalDragStart: (d) {
                _dragStartY = d.localPosition.dy;
                _dragStartOffset = offset;
              },
              onVerticalDragUpdate: (d) {
                if (_dragStartY == null) return;
                widget.onScrollTo(_dragStartOffset! +
                    (d.localPosition.dy - _dragStartY!) / maxThumbY * maxOffset);
              },
              child: CustomPaint(
                painter: _VThumbPainter(thumbY: thumbY, thumbH: thumbH, topPadding: widget.topPadding),
                size: Size(10, totalH),
              ),
            );
          },
        ),
      );
    });
  }
}

class _VThumbPainter extends CustomPainter {
  final double thumbY, thumbH, topPadding;
  const _VThumbPainter({required this.thumbY, required this.thumbH, required this.topPadding});
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(3, topPadding, 4, size.height - topPadding), const Radius.circular(2)),
        Paint()..color = AppDS.border);
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(1, thumbY, 8, thumbH), const Radius.circular(4)),
        Paint()..color = AppDS.textSecondary);
  }
  @override bool shouldRepaint(_VThumbPainter old) =>
      old.thumbY != thumbY || old.thumbH != thumbH;
}
