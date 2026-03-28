// label_db_field_picker.dart - Part of label_page.dart.
// Dropdown picker for selecting a Supabase table field to bind to a label
// field slot (used inside the template builder).

part of '../label_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DB Field Picker — bottom sheet for selecting a database field to add
// ─────────────────────────────────────────────────────────────────────────────
class _DbFieldPicker extends StatefulWidget {
  final String category;
  final void Function(String key) onSelect;
  const _DbFieldPicker({required this.category, required this.onSelect});

  @override
  State<_DbFieldPicker> createState() => _DbFieldPickerState();
}

class _DbFieldPickerState extends State<_DbFieldPicker> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  List<({String key, String label})> _fields = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFields();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFields() async {
    final hardcoded = _fieldsForCategory(widget.category);
    final hardcodedKeys = hardcoded.map((f) => f.key).toSet();

    final extra = <({String key, String label})>[];
    try {
      final table = _tableForEntity(widget.category);
      final rows = await Supabase.instance.client.from(table).select().limit(1);
      if (rows.isNotEmpty) {
        final row = Map<String, dynamic>.from(rows.first);
        for (final entry in row.entries) {
          if (entry.value == null) { continue; }
          final dbKey = '{${entry.key}}';
          if (hardcodedKeys.contains(dbKey)) { continue; }
          final label = entry.key
              .split('_')
              .where((s) => s.isNotEmpty)
              .map((s) => s[0].toUpperCase() + s.substring(1))
              .join(' ');
          extra.add((key: dbKey, label: label));
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _fields = [...hardcoded, ...extra];
        _loading = false;
      });
    }
  }

  List<({String key, String label})> get _filtered {
    if (_query.isEmpty) { return _fields; }
    final q = _query.toLowerCase();
    return _fields
        .where((f) =>
            f.label.toLowerCase().contains(q) ||
            f.key.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Handle
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: AppDS.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
          child: Row(children: [
            const Icon(Icons.data_object_rounded, size: 18, color: AppDS.accent),
            const SizedBox(width: 10),
            Text(widget.category, style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, color: AppDS.textPrimary)),
            const Spacer(),
            if (!_loading)
              Text('${filtered.length} fields', style: const TextStyle(
                  fontSize: 12, color: AppDS.textSecondary)),
          ]),
        ),
        // Search
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            controller: _searchCtrl,
            style: const TextStyle(fontSize: 13, color: AppDS.textPrimary),
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: AppDS.bg,
              hintText: 'Search fields…',
              hintStyle: const TextStyle(color: AppDS.textSecondary, fontSize: 13),
              prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppDS.textSecondary),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppDS.border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppDS.border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppDS.accent)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            ),
          ),
        ),
        const Divider(color: AppDS.border, height: 1),
        // Body
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppDS.accent)),
          )
        else if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text('No fields match "$_query".',
                style: const TextStyle(
                    fontSize: 13, color: AppDS.textSecondary)),
          )
        else
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final f = filtered[i];
                return InkWell(
                  onTap: () => widget.onSelect(f.key),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    child: Row(children: [
                      const Icon(Icons.add_circle_outline_rounded,
                          size: 16, color: AppDS.accent),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(f.label, style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppDS.textPrimary)),
                            Text(f.key, style: const TextStyle(
                                fontSize: 11, color: AppDS.textSecondary)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          size: 16, color: AppDS.textMuted),
                    ]),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 12),
      ],
    );
  }
}
