import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'strains_columns.dart';
import '/theme/theme.dart';
import '/theme/grid_widgets.dart';

// Backward-compatible aliases so strains_page.dart keeps working unchanged.
typedef HorizontalThumb = AppHorizontalThumb;
typedef VerticalThumb   = AppVerticalThumb;


// ─────────────────────────────────────────────────────────────────────────────
// Status cell
// ─────────────────────────────────────────────────────────────────────────────
class StatusCell extends StatelessWidget {
  final String? status;
  const StatusCell({super.key, this.status});

  Color get _color {
    if (status == 'ALIVE')  return AppDS.green;
    if (status == 'DEAD')   return AppDS.red;
    if (status == 'INCARE') return AppDS.yellow;
    return Colors.grey;
  }

  IconData get _icon {
    if (status == 'ALIVE')  return Icons.check_circle_rounded;
    if (status == 'DEAD')   return Icons.cancel_rounded;
    if (status == 'INCARE') return Icons.medical_services_rounded;
    return Icons.help_outline_rounded;
  }

  @override
  Widget build(BuildContext context) {
    if (status == null || status!.isEmpty) return const SizedBox.shrink();
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(_icon, size: 11, color: _color),
      const SizedBox(width: 5),
      Flexible(
          child: Text(status!,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: _color),
              overflow: TextOverflow.ellipsis)),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Toolbar chip
// ─────────────────────────────────────────────────────────────────────────────
class ToolbarChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;
  const ToolbarChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 10, vertical: compact ? 4 : 6),
        decoration: BoxDecoration(
          color: selected ? AppDS.accent.withValues(alpha: 0.15) : context.appSurface2,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: selected ? AppDS.accent.withValues(alpha: 0.5) : context.appBorder),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon,
                size: 13,
                color: selected ? AppDS.accent : context.appTextSecondary),
            const SizedBox(width: 5),
          ],
          Text(label,
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: selected ? AppDS.accent : context.appTextSecondary)),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Kingdom selector
// ─────────────────────────────────────────────────────────────────────────────
class KingdomSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const KingdomSelector({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        textStyle: WidgetStateProperty.all(const TextStyle(fontSize: 11)),
        padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 10)),
      ),
      segments: const [
        ButtonSegment(value: 'all', label: Text('All')),
        ButtonSegment(value: 'prokaryote', label: Text('Prokaryote')),
        ButtonSegment(value: 'eukaryote', label: Text('Eukaryote')),
      ],
      selected: {value},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Draggable header
// ─────────────────────────────────────────────────────────────────────────────
class DraggableHeader extends StatefulWidget {
  final StrainColDef col;
  final List<StrainColDef> allVisibleCols;
  final double Function(StrainColDef) colWidthFn;
  final VoidCallback onDragStart;
  final void Function(double localX) onDragUpdate;
  final VoidCallback onDragEnd;
  final VoidCallback? onTapInSelectionMode;
  final VoidCallback onTapSort;
  final Widget child;

  const DraggableHeader({
    super.key,
    required this.col,
    required this.allVisibleCols,
    required this.colWidthFn,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onTapSort,
    required this.child,
    this.onTapInSelectionMode,
  });

  @override
  State<DraggableHeader> createState() => _DraggableHeaderState();
}

class _DraggableHeaderState extends State<DraggableHeader> {
  bool _isDragging = false;
  double _pointerStartX = 0;
  double _colStartOffset = 0;

  double get _cw => widget.colWidthFn(widget.col);

  double _offsetOf(StrainColDef col) {
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
      onLongPressStart: inSel
          ? null
          : (d) {
              _pointerStartX = d.globalPosition.dx;
              _colStartOffset = _offsetOf(widget.col);
              setState(() => _isDragging = true);
              widget.onDragStart();
            },
      onLongPressMoveUpdate: inSel
          ? null
          : (d) {
              if (!_isDragging) return;
              widget.onDragUpdate(
                  _colStartOffset + _cw / 2 + d.globalPosition.dx - _pointerStartX);
            },
      onLongPressEnd: inSel
          ? null
          : (_) {
              setState(() => _isDragging = false);
              widget.onDragEnd();
            },
      onLongPressCancel: inSel
          ? null
          : () {
              setState(() => _isDragging = false);
              widget.onDragEnd();
            },
      child: MouseRegion(
        cursor: inSel
            ? SystemMouseCursors.click
            : (_isDragging ? SystemMouseCursors.grabbing : SystemMouseCursors.grab),
        child: widget.child,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Column resize handle
// ─────────────────────────────────────────────────────────────────────────────
class ColResizeHandle extends StatefulWidget {
  final void Function(double delta) onDrag;
  final void Function() onDragEnd;
  const ColResizeHandle({super.key, required this.onDrag, required this.onDragEnd});

  @override
  State<ColResizeHandle> createState() => _ColResizeHandleState();
}

class _ColResizeHandleState extends State<ColResizeHandle> {
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
        onHorizontalDragEnd: (_) => widget.onDragEnd(),
        child: Center(
            child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 2,
          height: 20,
          decoration: BoxDecoration(
            color: _hovering ? AppDS.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(1),
          ),
        )),
      ),
    );
  }
}

// HorizontalThumb and VerticalThumb are re-exported via typedefs at the top of this file.

// ─────────────────────────────────────────────────────────────────────────────
// Column position number input
// ─────────────────────────────────────────────────────────────────────────────
class ColPositionField extends StatefulWidget {
  final int position;
  final int total;
  final void Function(int newPos) onSubmit;
  const ColPositionField(
      {super.key, required this.position, required this.total, required this.onSubmit});

  @override
  State<ColPositionField> createState() => _ColPositionFieldState();
}

class _ColPositionFieldState extends State<ColPositionField> {
  late TextEditingController _ctrl;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: '${widget.position}');
  }

  @override
  void didUpdateWidget(ColPositionField old) {
    super.didUpdateWidget(old);
    if (!_editing && old.position != widget.position) {
      _ctrl.text = '${widget.position}';
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final val = int.tryParse(_ctrl.text);
    if (val != null) widget.onSubmit(val);
    else _ctrl.text = '${widget.position}';
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _editing = true),
      child: _editing
          ? SizedBox(
              width: 32,
              height: 26,
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w700, color: context.appTextPrimary),
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: context.appSurface3,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: const BorderSide(color: AppDS.accent, width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: const BorderSide(color: AppDS.accent, width: 1.5),
                  ),
                ),
                onSubmitted: (_) => _submit(),
                onTapOutside: (_) => _submit(),
              ),
            )
          : Container(
              width: 32,
              height: 26,
              decoration: BoxDecoration(
                color: context.appSurface2,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: context.appBorder),
              ),
              alignment: Alignment.center,
              child: Text('${widget.position}',
                  style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: context.appTextSecondary)),
            ),
    );
  }
}