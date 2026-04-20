// detail_widgets.dart - Shared collapsible section + inline field helpers
// used by RoomDetailPage and LocationDetailPage.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/theme/theme.dart';

class DetailSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;

  const DetailSection({
    super.key,
    required this.title,
    required this.icon,
    required this.expanded,
    required this.onToggle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.appBorder),
      ),
      child: Column(children: [
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.vertical(
            top: const Radius.circular(10),
            bottom: Radius.circular(expanded ? 0 : 10),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: context.appSurface2,
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(10),
                bottom: Radius.circular(expanded ? 0 : 10),
              ),
            ),
            child: Row(children: [
              Icon(icon, size: 14, color: AppDS.accent),
              const SizedBox(width: 8),
              Text(title,
                  style: GoogleFonts.spaceGrotesk(
                      color: context.appTextSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8)),
              const Spacer(),
              Icon(
                expanded ? Icons.expand_less : Icons.expand_more,
                size: 18,
                color: context.appTextMuted,
              ),
            ]),
          ),
        ),
        if (expanded) ...[
          Divider(height: 1, color: context.appBorder),
          Padding(
            padding: const EdgeInsets.all(14),
            child: child,
          ),
        ],
      ]),
    );
  }
}

class DetailFieldRow extends StatelessWidget {
  final List<Widget> children;
  const DetailFieldRow({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: children
          .expand((w) => [Expanded(child: w), const SizedBox(width: 10)])
          .toList()
        ..removeLast(),
    );
  }
}

class DetailInlineField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final int maxLines;
  final TextInputType? keyboardType;

  const DetailInlineField({
    super.key,
    required this.label,
    required this.controller,
    this.maxLines = 1,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: GoogleFonts.spaceGrotesk(color: context.appTextPrimary, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.spaceGrotesk(
            color: context.appTextSecondary, fontSize: 11),
        filled: true,
        fillColor: context.appSurface3,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: context.appBorder)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: context.appBorder)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppDS.accent)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}

class DetailInlineDropdown<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final void Function(T?) onChanged;

  const DetailInlineDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.spaceGrotesk(
            color: context.appTextSecondary, fontSize: 11),
        filled: true,
        fillColor: context.appSurface3,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: context.appBorder)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: context.appBorder)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          dropdownColor: context.appSurface,
          style: GoogleFonts.spaceGrotesk(
              color: context.appTextPrimary, fontSize: 13),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

void detailSnack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg, style: const TextStyle(color: Colors.white)),
    behavior: SnackBarBehavior.floating,
    backgroundColor: AppDS.surface,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  ));
}

String detailFmtDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

// Strip any leading R#/L#.# prefix from a stored name so the derived code
// isn't duplicated when prepended at display time.
String stripLocationCodePrefix(String name) {
  final match = RegExp(r'^[RL]\d+(?:\.\d+)?\s*(?:[-·]\s*)?',
          caseSensitive: false)
      .firstMatch(name.trim());
  if (match == null) return name.trim();
  return name.trim().substring(match.end).trim();
}
