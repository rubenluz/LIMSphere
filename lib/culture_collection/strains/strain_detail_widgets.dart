// strain_detail_widgets.dart - Part of strain_detail_page.dart.
// _StatusDropdown: inline status selector chip used in the strain detail form.
part of 'strain_detail_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Status dropdown widget
// ─────────────────────────────────────────────────────────────────────────────
class _StatusDropdown extends StatelessWidget {
  final String label;
  final String? value;
  final ValueChanged<String?> onChanged;

  const _StatusDropdown({required this.label, required this.value, required this.onChanged});

  static const _options = ['ALIVE', 'INCARE', 'DEAD'];

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: _options.contains(value) ? value : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12, color: _DS.labelColor),
        isDense: true, filled: true, fillColor: const Color(0xFFFAFAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _DS.cardBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _DS.cardBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _DS.accent, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      items: [
        const DropdownMenuItem(value: null,
            child: Text('— not set —',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13))),
        ..._options.map((s) => DropdownMenuItem(
          value: s,
          child: Row(children: [
            Icon(_statusIcon(s), size: 14, color: _statusColor(s)),
            const SizedBox(width: 8),
            Text(s, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                color: _statusColor(s))),
          ]),
        )),
      ],
      onChanged: onChanged,
    );
  }
}