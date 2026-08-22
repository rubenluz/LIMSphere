import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '/theme/theme.dart';

class LabToolPage extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final Widget child;
  final List<Widget>? actions;

  const LabToolPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.child,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBg,
      appBar: AppBar(
        backgroundColor: context.appSurface2,
        foregroundColor: context.appTextPrimary,
        actions: actions,
        title: Row(
          children: [
            Icon(icon, size: 19, color: accent),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: context.appTextPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subtitle,
                    style: GoogleFonts.spaceGrotesk(
                      color: context.appTextSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LabToolCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;

  const LabToolCard({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.spaceGrotesk(
                    color: context.appTextPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 15),
          child,
        ],
      ),
    );
  }
}

class LabNumberField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? suffix;
  final ValueChanged<String>? onChanged;
  final String? hint;

  const LabNumberField({
    super.key,
    required this.controller,
    required this.label,
    this.suffix,
    this.onChanged,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9eE+.,-]')),
      ],
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixText: suffix,
        isDense: true,
        filled: true,
        fillColor: context.appSurface3,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: context.appBorder),
        ),
      ),
    );
  }
}

class LabSelect<T> extends StatelessWidget {
  final T value;
  final String label;
  final List<T> values;
  final String Function(T) labelOf;
  final ValueChanged<T?> onChanged;

  const LabSelect({
    super.key,
    required this.value,
    required this.label,
    required this.values,
    required this.labelOf,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        filled: true,
        fillColor: context.appSurface3,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: context.appBorder),
        ),
      ),
      dropdownColor: context.appSurface,
      items: [
        for (final item in values)
          DropdownMenuItem(value: item, child: Text(labelOf(item))),
      ],
      onChanged: (item) {
        onChanged(item);
        FocusManager.instance.primaryFocus?.unfocus();
      },
    );
  }
}

class LabResultRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const LabResultRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: context.appTextSecondary, fontSize: 12),
            ),
          ),
          const SizedBox(width: 12),
          SelectableText(
            value,
            textAlign: TextAlign.right,
            style: GoogleFonts.jetBrainsMono(
              color: valueColor ?? context.appTextPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

double? parseLabNumber(String value) =>
    double.tryParse(value.trim().replaceAll(',', '.'));
