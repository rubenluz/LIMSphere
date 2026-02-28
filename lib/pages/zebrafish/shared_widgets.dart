import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Design tokens (mirrors strains_page _DS pattern) ─────────────────────────
class _C {
  static const Color bg       = Color(0xFF0F172A);
  static const Color surface  = Color(0xFF1E293B);
  static const Color surface2 = Color(0xFF1A2438);
  static const Color surface3 = Color(0xFF243044);
  static const Color border   = Color(0xFF334155);
  static const Color border2  = Color(0xFF2D3F55);
  static const Color accent   = Color(0xFF38BDF8);
  static const Color green    = Color(0xFF22C55E);
  static const Color yellow   = Color(0xFFEAB308);
  static const Color orange   = Color(0xFFF97316);
  static const Color red      = Color(0xFFEF4444);
  static const Color purple   = Color(0xFFA855F7);

  static const Color textPrimary   = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted     = Color(0xFF64748B);

  static Color statusColor(String? s) {
    switch (s?.toLowerCase()) {
      case 'active':        return green;
      case 'breeding':      return purple;
      case 'healthy':       return green;
      case 'observation':   return yellow;
      case 'treatment':     return orange;
      case 'sick':          return red;
      case 'archiving':
      case 'archived':      return textMuted;
      case 'lost':          return red;
      case 'cryopreserved': return accent;
      case 'quarantine':    return yellow;
      case 'retired':       return red;
      case 'empty':         return textMuted;
      case 'transgenic':    return accent;
      case 'mutant':        return orange;
      case 'crispr':        return purple;
      case 'ko':            return red;
      case 'ki':            return yellow;
      case 'wt':            return green;
      default:              return textSecondary;
    }
  }
}

// Expose _C as FishDS for cross-file access
class FishDS {
  static const Color bg       = _C.bg;
  static const Color surface  = _C.surface;
  static const Color surface2 = _C.surface2;
  static const Color surface3 = _C.surface3;
  static const Color border   = _C.border;
  static const Color border2  = _C.border2;
  static const Color accent   = _C.accent;
  static const Color green    = _C.green;
  static const Color yellow   = _C.yellow;
  static const Color orange   = _C.orange;
  static const Color red      = _C.red;
  static const Color purple   = _C.purple;
  static const Color textPrimary   = _C.textPrimary;
  static const Color textSecondary = _C.textSecondary;
  static const Color textMuted     = _C.textMuted;
  static Color statusColor(String? s) => _C.statusColor(s);
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
        color: color.withOpacity(0.13),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
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
        style: GoogleFonts.spaceGrotesk(color: _C.textPrimary, fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.spaceGrotesk(color: _C.textMuted, fontSize: 13),
          prefixIcon: const Icon(Icons.search, size: 16, color: _C.textMuted),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, size: 14, color: _C.textMuted),
                  onPressed: () { controller.clear(); onClear?.call(); },
                )
              : null,
          filled: true,
          fillColor: _C.surface3,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _C.border),
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
        color: isActive ? _C.accent.withOpacity(0.12) : _C.surface2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isActive ? _C.accent.withOpacity(0.5) : _C.border),
      ),
      child: PopupMenuButton<String>(
        initialValue: value ?? '',
        onSelected: (v) => onChanged(v.isEmpty ? null : v),
        color: _C.surface2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: _C.border2),
        ),
        itemBuilder: (ctx) => [
          PopupMenuItem(
            value: '',
            child: Text('All $label',
              style: GoogleFonts.spaceGrotesk(color: _C.textSecondary, fontSize: 13)),
          ),
          const PopupMenuDivider(),
          ...options.map((o) => PopupMenuItem(
            value: o,
            child: Text(o,
              style: GoogleFonts.spaceGrotesk(color: _C.textPrimary, fontSize: 13)),
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
                  color: isActive ? _C.accent : _C.textSecondary,
                  fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_down,
                size: 14, color: isActive ? _C.accent : _C.textMuted),
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
          Text(
            label.toUpperCase(),
            style: GoogleFonts.spaceGrotesk(
              fontSize: 10.5, fontWeight: FontWeight.w700,
              letterSpacing: 0.07,
              color: isActive ? _C.accent : _C.textSecondary),
          ),
          const SizedBox(width: 3),
          Icon(
            isActive
                ? (sortAsc ? Icons.arrow_upward : Icons.arrow_downward)
                : Icons.unfold_more,
            size: 11,
            color: isActive ? _C.accent : _C.textMuted),
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
              letterSpacing: 0.08, color: _C.textMuted)),
          ),
          Expanded(
            child: trailing ?? Text(
              value ?? '—',
              style: mono
                  ? GoogleFonts.jetBrainsMono(fontSize: 12, color: _C.textPrimary)
                  : GoogleFonts.spaceGrotesk(fontSize: 13, color: _C.textPrimary),
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
              letterSpacing: 0.12, color: _C.textMuted),
          ),
          const SizedBox(width: 12),
          Expanded(child: Container(height: 1, color: _C.border)),
          if (subtitle != null) ...[
            const SizedBox(width: 8),
            Text(subtitle!,
              style: GoogleFonts.spaceGrotesk(fontSize: 10, color: _C.textMuted)),
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
        color: _C.surface2,
        borderRadius: BorderRadius.circular(8),
        border: const Border(left: BorderSide(color: _C.border2, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 10, color: _C.textMuted,
              fontWeight: FontWeight.w600, letterSpacing: 0.08)),
          const SizedBox(height: 3),
          Text(value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 18, fontWeight: FontWeight.w700,
              color: color ?? _C.textPrimary)),
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
          child: Icon(icon, size: 15, color: color ?? _C.textMuted),
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
              .copyWith(color: _C.textPrimary),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            filled: true,
            fillColor: _C.surface3,
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
      onTap: () => setState(() => _editing = true),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Text(
          widget.value ?? '—',
          style: (widget.mono
              ? GoogleFonts.jetBrainsMono(fontSize: 12)
              : GoogleFonts.spaceGrotesk(fontSize: 12))
              .copyWith(color: _C.textPrimary),
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
      color: _C.surface2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: _C.border2),
      ),
      itemBuilder: (ctx) => options.map((o) => PopupMenuItem(
        value: o,
        child: Text(o, style: GoogleFonts.spaceGrotesk(color: _C.textPrimary, fontSize: 13)),
      )).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: _C.border.withOpacity(0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (value != null) StatusBadge(label: value),
            if (value == null)
              Text('—', style: GoogleFonts.spaceGrotesk(fontSize: 12, color: _C.textMuted)),
            const SizedBox(width: 3),
            const Icon(Icons.keyboard_arrow_down, size: 12, color: _C.textMuted),
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
      backgroundColor: _C.surface2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: _C.border2),
      ),
      title: Text(title,
        style: GoogleFonts.spaceGrotesk(
          color: _C.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
      content: Text(message,
        style: GoogleFonts.spaceGrotesk(color: _C.textSecondary, fontSize: 13)),
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