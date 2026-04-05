// samples_widgets.dart - Part of samples_page.dart.
// _DraggableHeader: column header supporting drag-to-reorder.
// _ColResizeHandle: drag handle for adjusting column widths.
part of 'samples_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Draggable header  (identical pattern to strains_page)
// ─────────────────────────────────────────────────────────────────────────────
class _DraggableHeader extends StatefulWidget {
  final SampleColDef col;
  final List<SampleColDef> allVisibleCols;
  final double Function(SampleColDef) colWidthFn;
  final VoidCallback onDragStart;
  final void Function(double localX) onDragUpdate;
  final VoidCallback onDragEnd;
  final VoidCallback? onTapInSelectionMode;
  final VoidCallback onTapSort;
  final Widget child;
  const _DraggableHeader({
    required this.col, required this.allVisibleCols, required this.colWidthFn,
    required this.onDragStart, required this.onDragUpdate, required this.onDragEnd,
    required this.onTapSort, required this.child, this.onTapInSelectionMode,
  });
  @override State<_DraggableHeader> createState() => _DraggableHeaderState();
}

class _DraggableHeaderState extends State<_DraggableHeader> {
  bool _isDragging = false;
  double _pointerStartX = 0;
  double _colStartOffset = 0;

  double get _cw => widget.colWidthFn(widget.col);

  double _offsetOf(SampleColDef col) {
    double acc = 0;
    for (final c in widget.allVisibleCols) {
      if (c.key == col.key) break;
      acc += widget.colWidthFn(c);
    }
    return acc;
  }

  @override
  Widget build(BuildContext context) {
    final inSel = widget.onTapInSelectionMode != null;
    return GestureDetector(
      onTap: inSel ? widget.onTapInSelectionMode : widget.onTapSort,
      onLongPressStart: inSel ? null : (d) {
        _pointerStartX  = d.globalPosition.dx;
        _colStartOffset = _offsetOf(widget.col);
        setState(() => _isDragging = true);
        widget.onDragStart();
      },
      onLongPressMoveUpdate: inSel ? null : (d) {
        if (!_isDragging) return;
        widget.onDragUpdate(_colStartOffset + _cw / 2 + d.globalPosition.dx - _pointerStartX);
      },
      onLongPressEnd:    inSel ? null : (_) { setState(() => _isDragging = false); widget.onDragEnd(); },
      onLongPressCancel: inSel ? null : ()  { setState(() => _isDragging = false); widget.onDragEnd(); },
      child: MouseRegion(
        cursor: inSel ? SystemMouseCursors.click : (_isDragging ? SystemMouseCursors.grabbing : SystemMouseCursors.grab),
        child: widget.child,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Column resize handle
// ─────────────────────────────────────────────────────────────────────────────
class _ColResizeHandle extends StatefulWidget {
  final void Function(double delta) onDrag;
  final void Function() onDragEnd;
  const _ColResizeHandle({required this.onDrag, required this.onDragEnd});
  @override State<_ColResizeHandle> createState() => _ColResizeHandleState();
}

class _ColResizeHandleState extends State<_ColResizeHandle> {
  bool _hovering = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _hovering = true),
      onExit:  (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (d) => widget.onDrag(d.delta.dx),
        onHorizontalDragEnd:    (_) => widget.onDragEnd(),
        child: Center(child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 2, height: 20,
          decoration: BoxDecoration(
            color: _hovering ? AppDS.blue : Colors.transparent,
            borderRadius: BorderRadius.circular(1),
          ),
        )),
      ),
    );
  }
}

// Thumb widgets provided by /theme/grid_widgets.dart (AppHorizontalThumb, AppVerticalThumb).
