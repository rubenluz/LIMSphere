// shared_widgets.dart - Fish-facility shared tokens and widgets:
// FishDS (colour aliases to AppDS), StatusBadge, InlineEditCell
// (permission-aware double-tap-to-edit cell used in tanks and stocks grids).

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/theme/theme.dart';
import '/theme/module_permission.dart';

// ─── Internal alias — all values live in AppDS (theme/theme.dart) ─────────────
class _C {
  static const accent = AppDS.accent;
  static const red    = AppDS.red;
  static Color statusColor(String? s) => AppDS.statusColor(s);
}

// Public alias for cross-file access — delegates to AppDS
class FishDS {
  static const bg            = AppDS.bg;
  static const surface       = AppDS.surface;
  static const surface2      = AppDS.surface2;
  static const surface3      = AppDS.surface3;
  static const border        = AppDS.border;
  static const border2       = AppDS.border2;
  static const accent        = AppDS.accent;
  static const green         = AppDS.green;
  static const yellow        = AppDS.yellow;
  static const orange        = AppDS.orange;
  static const red           = AppDS.red;
  static const purple        = AppDS.purple;
  static const textPrimary   = AppDS.textPrimary;
  static const textSecondary = AppDS.textSecondary;
  static const textMuted     = AppDS.textMuted;
  static Color statusColor(String? s) => AppDS.statusColor(s);
}

// ─── STATUS BADGE ─────────────────────────────────────────────────────────────
class StatusBadge extends StatelessWidget {
  final String? label;
  final String? overrideStatus;
  const StatusBadge({super.key, this.label, this.overrideStatus});

  @override
  Widget build(BuildContext context) {
    if (label == null && overrideStatus == null) return const SizedBox.shrink();
    final text = label ?? overrideStatus!;
    final color = _C.statusColor(overrideStatus ?? label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 5, height: 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(
            text.toUpperCase(),
            style: GoogleFonts.spaceGrotesk(
              fontSize: 10, fontWeight: FontWeight.w700,
              color: color, letterSpacing: 0.06),
          ),
        ],
      ),
    );
  }
}

// ─── SEARCH BAR ──────────────────────────────────────────────────────────────
class AppSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final VoidCallback? onClear;

  const AppSearchBar({
    super.key, required this.controller,
    this.hint = 'Search…', this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      child: TextField(
        controller: controller,
        style: GoogleFonts.spaceGrotesk(color: context.appTextPrimary, fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.spaceGrotesk(color: context.appTextMuted, fontSize: 13),
          prefixIcon: Icon(Icons.search, size: 16, color: context.appTextMuted),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close, size: 14, color: context.appTextMuted),
                  onPressed: () { controller.clear(); onClear?.call(); },
                )
              : null,
          filled: true,
          fillColor: context.appSurface3,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: context.appBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _C.accent, width: 1.5),
          ),
          isDense: true,
        ),
      ),
    );
  }
}

// ─── FILTER CHIP ─────────────────────────────────────────────────────────────
class AppFilterChip extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  const AppFilterChip({
    super.key, required this.label,
    required this.value, required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = value != null && value!.isNotEmpty;
    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: isActive ? _C.accent.withValues(alpha: 0.12) : context.appSurface2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isActive ? _C.accent.withValues(alpha: 0.5) : context.appBorder),
      ),
      child: PopupMenuButton<String>(
        initialValue: value ?? '',
        onSelected: (v) => onChanged(v.isEmpty ? null : v),
        color: context.appSurface2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: context.appBorder2),
        ),
        itemBuilder: (ctx) => [
          PopupMenuItem(
            value: '',
            child: Text('All $label',
              style: GoogleFonts.spaceGrotesk(color: context.appTextSecondary, fontSize: 13)),
          ),
          const PopupMenuDivider(),
          ...options.map((o) => PopupMenuItem(
            value: o,
            child: Text(o,
              style: GoogleFonts.spaceGrotesk(color: context.appTextPrimary, fontSize: 13)),
          )),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isActive ? value! : label,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 12,
                  color: isActive ? _C.accent : context.appTextSecondary,
                  fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_down,
                size: 14, color: isActive ? _C.accent : context.appTextMuted),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── SORTABLE COLUMN HEADER ───────────────────────────────────────────────────
class SortHeader extends StatelessWidget {
  final String label;
  final String columnKey;
  final String? sortKey;
  final bool sortAsc;
  final ValueChanged<String> onSort;

  const SortHeader({
    super.key, required this.label, required this.columnKey,
    this.sortKey, required this.sortAsc, required this.onSort,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = sortKey == columnKey;
    return InkWell(
      onTap: () => onSort(columnKey),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label.toUpperCase(),
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 10.5, fontWeight: FontWeight.w700,
                letterSpacing: 0.07,
                color: isActive ? _C.accent : context.appHeaderText),
            ),
          ),
          const SizedBox(width: 3),
          Icon(
            isActive
                ? (sortAsc ? Icons.arrow_upward : Icons.arrow_downward)
                : Icons.unfold_more,
            size: 11,
            color: isActive ? _C.accent : context.appTextMuted),
        ],
      ),
    );
  }
}

// ─── DETAIL FIELD ROW ─────────────────────────────────────────────────────────
class DetailField extends StatelessWidget {
  final String label;
  final String? value;
  final bool mono;
  final Widget? trailing;

  const DetailField({
    super.key, required this.label,
    this.value, this.mono = false, this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 170,
            child: Text(label, style: GoogleFonts.spaceGrotesk(
              fontSize: 11, fontWeight: FontWeight.w700,
              letterSpacing: 0.08, color: context.appTextMuted)),
          ),
          Expanded(
            child: trailing ?? Text(
              value ?? '—',
              style: mono
                  ? GoogleFonts.jetBrainsMono(fontSize: 12, color: context.appTextPrimary)
                  : GoogleFonts.spaceGrotesk(fontSize: 13, color: context.appTextPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── SECTION HEADER ───────────────────────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  const SectionHeader({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Row(
        children: [
          Text(
            title.toUpperCase(),
            style: GoogleFonts.spaceGrotesk(
              fontSize: 10.5, fontWeight: FontWeight.w800,
              letterSpacing: 0.12, color: context.appTextMuted),
          ),
          const SizedBox(width: 12),
          Expanded(child: Container(height: 1, color: context.appBorder)),
          if (subtitle != null) ...[
            const SizedBox(width: 8),
            Text(subtitle!,
              style: GoogleFonts.spaceGrotesk(fontSize: 10, color: context.appTextMuted)),
          ],
        ],
      ),
    );
  }
}

// ─── STAT CARD ────────────────────────────────────────────────────────────────
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const StatCard({super.key, required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: context.appSurface2,
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: context.appBorder2, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 10, color: context.appTextMuted,
              fontWeight: FontWeight.w600, letterSpacing: 0.08)),
          const SizedBox(height: 3),
          Text(value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 18, fontWeight: FontWeight.w700,
              color: color ?? context.appTextPrimary)),
        ],
      ),
    );
  }
}

// ─── ICON BUTTON ─────────────────────────────────────────────────────────────
class AppIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? color;

  const AppIconButton({
    super.key, required this.icon,
    required this.tooltip, required this.onPressed, this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 15, color: color ?? context.appTextMuted),
        ),
      ),
    );
  }
}

// ─── INLINE EDIT CELL ────────────────────────────────────────────────────────
class InlineEditCell extends StatefulWidget {
  final String? value;
  final ValueChanged<String> onSaved;
  final bool mono;
  final double width;

  const InlineEditCell({
    super.key, this.value, required this.onSaved,
    this.mono = false, this.width = 120,
  });

  @override
  State<InlineEditCell> createState() => _InlineEditCellState();
}

class _InlineEditCellState extends State<InlineEditCell> {
  late TextEditingController _ctrl;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value ?? '');
  }

  @override
  Widget build(BuildContext context) {
    if (_editing) {
      return SizedBox(
        width: widget.width,
        height: 28,
        child: TextField(
          controller: _ctrl,
          autofocus: true,
          style: (widget.mono
              ? GoogleFonts.jetBrainsMono(fontSize: 12)
              : GoogleFonts.spaceGrotesk(fontSize: 12))
              .copyWith(color: context.appTextPrimary),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            filled: true,
            fillColor: context.appSurface3,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: _C.accent, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: _C.accent, width: 1.5),
            ),
            isDense: true,
          ),
          onSubmitted: (v) { widget.onSaved(v); setState(() => _editing = false); },
          onTapOutside: (_) { widget.onSaved(_ctrl.text); setState(() => _editing = false); },
        ),
      );
    }
    return InkWell(
      onTap: () {
        if (!context.canEditModule) { context.warnReadOnly(); return; }
        setState(() => _editing = true);
      },
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Text(
          widget.value ?? '—',
          style: (widget.mono
              ? GoogleFonts.jetBrainsMono(fontSize: 12)
              : GoogleFonts.spaceGrotesk(fontSize: 12))
              .copyWith(color: context.appTextPrimary),
        ),
      ),
    );
  }
}

// ─── DROPDOWN CELL ───────────────────────────────────────────────────────────
class DropdownCell extends StatelessWidget {
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  const DropdownCell({
    super.key, this.value,
    required this.options, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      initialValue: value,
      onSelected: onChanged,
      color: context.appSurface2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: context.appBorder2),
      ),
      itemBuilder: (ctx) => options.map((o) => PopupMenuItem(
        value: o,
        child: Text(o, style: GoogleFonts.spaceGrotesk(color: context.appTextPrimary, fontSize: 13)),
      )).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: context.appBorder.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (value != null) StatusBadge(label: value),
            if (value == null)
              Text('—', style: GoogleFonts.spaceGrotesk(fontSize: 12, color: context.appTextMuted)),
            const SizedBox(width: 3),
            Icon(Icons.keyboard_arrow_down, size: 12, color: context.appTextMuted),
          ],
        ),
      ),
    );
  }
}

// ─── CONFIRM DIALOG ──────────────────────────────────────────────────────────
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Delete',
  Color confirmColor = _C.red,
}) async {
  return await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: ctx.appSurface2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: ctx.appBorder2),
      ),
      title: Text(title,
        style: GoogleFonts.spaceGrotesk(
          color: ctx.appTextPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
      content: Text(message,
        style: GoogleFonts.spaceGrotesk(color: ctx.appTextSecondary, fontSize: 13)),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: confirmColor),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  ) ?? false;
}