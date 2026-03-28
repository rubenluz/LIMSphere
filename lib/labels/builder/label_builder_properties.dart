// label_builder_properties.dart — Part of label_page.dart.
// Field-property panel and DB-fields panel for the label builder:
//   _FieldProperties, _PropLabel, _PropField, _NumField, _AlignBtn, _ToggleBtn,
//   _DbFieldsPanel, _DbFieldChip, _rowLabelFor.

part of '../label_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Field properties panel
// ─────────────────────────────────────────────────────────────────────────────
class _FieldProperties extends StatelessWidget {
  final LabelField field;
  final void Function(LabelField) onChange;
  const _FieldProperties({required this.field, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('FIELD PROPERTIES', style: TextStyle(fontSize: 9, letterSpacing: 1.2,
            color: context.appTextSecondary, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),

        if (field.type == LabelFieldType.text) ...[
          _PropLabel('Content'),
          _PropField(
            value: field.content,
            onChanged: (v) => onChange(field.copyWith(content: v)),
          ),
          const SizedBox(height: 10),
          _PropLabel('Font Size'),
          Row(children: [
            Expanded(
              child: Slider(
                value: field.fontSize.clamp(6.0, 72.0),
                min: 6, max: 72,
                divisions: 66,
                activeColor: AppDS.accent,
                onChanged: (v) {
                  final minH = (v * 0.42).ceilToDouble();
                  onChange(field.copyWith(fontSize: v, h: field.h < minH ? minH : null));
                },
              ),
            ),
            SizedBox(
              width: 56,
              child: _NumField('pt', field.fontSize, (v) {
                final clamped = v.clamp(6.0, 72.0);
                final minH = (clamped * 0.42).ceilToDouble();
                onChange(field.copyWith(fontSize: clamped, h: field.h < minH ? minH : null));
              }),
            ),
          ]),
          const SizedBox(height: 6),
          _PropLabel('Style'),
          Row(children: [
            _ToggleBtn('B', field.fontWeight == FontWeight.bold,
                () => onChange(field.copyWith(fontWeight: field.fontWeight == FontWeight.bold ? FontWeight.normal : FontWeight.bold))),
            const SizedBox(width: 6),
            _ToggleBtn('←', field.textAlign == TextAlign.left,
                () => onChange(field.copyWith(textAlign: TextAlign.left))),
            _ToggleBtn('⊟', field.textAlign == TextAlign.center,
                () => onChange(field.copyWith(textAlign: TextAlign.center))),
            _ToggleBtn('→', field.textAlign == TextAlign.right,
                () => onChange(field.copyWith(textAlign: TextAlign.right))),
          ]),
        ],

        const SizedBox(height: 10),
        _PropLabel('Position'),
        Row(children: [
          Expanded(child: _NumField('X', field.x, (v) => onChange(field.copyWith(x: v)))),
          const SizedBox(width: 6),
          Expanded(child: _NumField('Y', field.y, (v) => onChange(field.copyWith(y: v)))),
        ]),
        const SizedBox(height: 6),
        _PropLabel('Size'),
        Row(children: [
          Expanded(child: _NumField('W', field.w, (v) => onChange(
              field.type == LabelFieldType.qrcode ? field.copyWith(w: v, h: v) : field.copyWith(w: v)))),
          const SizedBox(width: 6),
          Expanded(child: _NumField('H', field.h, (v) => onChange(
              field.type == LabelFieldType.qrcode ? field.copyWith(w: v, h: v) : field.copyWith(h: v)))),
        ]),
      ],
    );
  }
}

class _PropLabel extends StatelessWidget {
  final String text;
  const _PropLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(text, style: TextStyle(fontSize: 10, color: context.appTextSecondary, fontWeight: FontWeight.w600)),
  );
}

class _PropField extends StatefulWidget {
  final String value;
  final void Function(String) onChanged;
  const _PropField({required this.value, required this.onChanged});
  @override
  State<_PropField> createState() => _PropFieldState();
}

class _PropFieldState extends State<_PropField> {
  late final TextEditingController _ctrl;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value);
    _focus = FocusNode();
  }

  @override
  void didUpdateWidget(_PropField old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value && !_focus.hasFocus) {
      _ctrl.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _ctrl,
    focusNode: _focus,
    style: TextStyle(fontSize: 12, color: context.appTextPrimary),
    maxLines: null,
    minLines: 3,
    decoration: InputDecoration(
      isDense: true, filled: true, fillColor: context.appBg,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: context.appBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: context.appBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppDS.accent)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      suffixIcon: _ctrl.text.isNotEmpty
          ? IconButton(
              icon: Icon(Icons.clear_rounded, size: 13, color: context.appTextSecondary),
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
              onPressed: () {
                _ctrl.clear();
                setState(() {});
                widget.onChanged('');
              },
            )
          : null,
    ),
    onChanged: (v) {
      setState(() {});
      widget.onChanged(v);
    },
  );
}

class _NumField extends StatefulWidget {
  final String label;
  final double value;
  final void Function(double) onChanged;
  const _NumField(this.label, this.value, this.onChanged);
  @override
  State<_NumField> createState() => _NumFieldState();
}

class _NumFieldState extends State<_NumField> {
  late final TextEditingController _ctrl;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value.toStringAsFixed(1));
    _focus = FocusNode();
  }

  @override
  void didUpdateWidget(_NumField old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value && !_focus.hasFocus) {
      final text = widget.value.toStringAsFixed(1);
      _ctrl.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _ctrl,
    focusNode: _focus,
    style: TextStyle(fontSize: 11, color: context.appTextPrimary),
    keyboardType: TextInputType.number,
    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
    decoration: InputDecoration(
      labelText: widget.label,
      labelStyle: TextStyle(fontSize: 10, color: context.appTextSecondary),
      isDense: true, filled: true, fillColor: context.appBg,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: context.appBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: context.appBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppDS.accent)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
    ),
    onChanged: (v) { final d = double.tryParse(v); if (d != null) widget.onChanged(d); },
  );
}

class _AlignBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _AlignBtn(this.icon, this.tooltip, this.onTap);
  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: 28, height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: context.appBg,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: context.appBorder),
        ),
        child: Icon(icon, size: 14, color: AppDS.accent),
      ),
    ),
  );
}

class _ToggleBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ToggleBtn(this.label, this.active, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 28, height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? AppDS.accent.withValues(alpha: 0.2) : context.appBg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: active ? AppDS.accent : context.appBorder),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: active ? AppDS.accent : context.appTextSecondary, fontWeight: FontWeight.bold)),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// DB fields panel — searchable wrapping chip panel below the canvas.
// On init fetches a 100-row sample from Supabase and hides columns that are
// entirely empty in the current dataset.  Drag-only — no tap-to-add.
// ─────────────────────────────────────────────────────────────────────────────
class _DbFieldsPanel extends StatefulWidget {
  final String category;
  final String? selectedContent;

  const _DbFieldsPanel({required this.category, required this.selectedContent});

  @override
  State<_DbFieldsPanel> createState() => _DbFieldsPanelState();
}

class _DbFieldsPanelState extends State<_DbFieldsPanel> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  // null = still loading; populated = filtered to non-empty cols
  Set<String>? _nonEmptyCols;

  @override
  void initState() {
    super.initState();
    _loadNonEmptyCols();
  }

  @override
  void didUpdateWidget(_DbFieldsPanel old) {
    super.didUpdateWidget(old);
    if (old.category != widget.category) {
      setState(() => _nonEmptyCols = null);
      _loadNonEmptyCols();
    }
  }

  Future<void> _loadNonEmptyCols() async {
    try {
      final table = _tableForEntity(widget.category);
      final rawRows = await Supabase.instance.client
          .from(table).select(_selectForCategory(widget.category)).limit(100);
      final rows = rawRows.map(_flattenJoins).toList();
      _injectQr(rows, widget.category);
      if (!mounted) return;
      final all = _allColsForCategory(widget.category);
      final nonEmpty = all
          .where((col) => rows.any((r) {
                final v = r[col];
                return v != null && v.toString().trim().isNotEmpty;
              }))
          .toSet();
      setState(() => _nonEmptyCols = nonEmpty);
    } catch (_) {
      // On error keep showing all columns (don't block the UI)
      if (mounted) setState(() => _nonEmptyCols = _allColsForCategory(widget.category).toSet());
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allCols = _allColsForCategory(widget.category);
    // While loading show all; after load show only non-empty
    final visibleCols = _nonEmptyCols == null
        ? allCols
        : allCols.where((c) => _nonEmptyCols!.contains(c)).toList();

    final filtered = _query.isEmpty
        ? visibleCols
        : visibleCols
            .where((c) => _colLabel(c).toLowerCase().contains(_query) ||
                c.toLowerCase().contains(_query))
            .toList();

    return Container(
      constraints: const BoxConstraints(maxHeight: 500),
      decoration: BoxDecoration(
        color: context.appSurface,
        border: Border(top: BorderSide(color: context.appBorder)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header + search row
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
            child: Row(children: [
              Text('DB FIELDS', style: TextStyle(fontSize: 9, letterSpacing: 1.1,
                  color: context.appTextSecondary, fontWeight: FontWeight.w700)),
              if (_nonEmptyCols == null) ...[
                const SizedBox(width: 8),
                const SizedBox(width: 10, height: 10,
                    child: CircularProgressIndicator(strokeWidth: 1.5, color: AppDS.accent)),
              ],
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  style: TextStyle(fontSize: 11, color: context.appTextPrimary),
                  onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: context.appBg,
                    hintText: 'Search fields…',
                    hintStyle: TextStyle(fontSize: 11, color: context.appTextSecondary),
                    prefixIcon: Icon(Icons.search_rounded, size: 14, color: context.appTextSecondary),
                    prefixIconConstraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: context.appBorder)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: context.appBorder)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: AppDS.accent)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    suffixIcon: _query.isNotEmpty
                        ? GestureDetector(
                            onTap: () { _searchCtrl.clear(); setState(() => _query = ''); },
                            child: Icon(Icons.close_rounded, size: 13, color: context.appTextSecondary),
                          )
                        : null,
                  ),
                ),
              ),
            ]),
          ),
          // Chips — scrollable wrap
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: filtered.map((col) {
                  final label = _colLabel(col);
                  final isQr = col.contains('qrcode') || col == '__qr__';
                  final spec = (
                    key: '{$col}',
                    label: label,
                    type: isQr ? LabelFieldType.qrcode : LabelFieldType.text,
                    isPlaceholder: true,
                  );
                  return _DbFieldChip(
                    spec: spec,
                    isSelected: widget.selectedContent == '{$col}',
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DbFieldChip extends StatelessWidget {
  final _FieldSpec spec;
  final bool isSelected;

  const _DbFieldChip({required this.spec, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return Draggable<_FieldSpec>(
      data: spec,
      feedback: Material(
        color: Colors.transparent,
        child: _chip(isSelected: isSelected, isDragging: true),
      ),
      childWhenDragging: Opacity(opacity: 0.4, child: _chip(isSelected: isSelected)),
      child: _chip(isSelected: isSelected),
    );
  }

  Widget _chip({required bool isSelected, bool isDragging = false}) {
    final bgColor = isSelected
        ? AppDS.accent.withValues(alpha: 0.18)
        : isDragging ? AppDS.surface2 : AppDS.surface3;
    final borderColor = isSelected ? AppDS.accent : AppDS.border;
    final textColor = isSelected ? AppDS.accent : AppDS.textPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: isSelected ? 1.5 : 1),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (spec.type == LabelFieldType.qrcode) ...[
          Icon(Icons.qr_code_2_rounded, size: 11, color: textColor),
          const SizedBox(width: 4),
        ],
        Text(spec.label,
            style: TextStyle(fontSize: 10, color: textColor,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
      ]),
    );
  }
}

String _rowLabelFor(Map<String, dynamic> row, String category, int index) {
  switch (category) {
    case 'Strains':
      final name = row['strain_name']?.toString().trim() ?? '';
      return name.isNotEmpty ? name : (row['strain_code']?.toString() ?? '#${index + 1}');
    case 'Stocks':
      final rack = row['fish_stocks_rack']?.toString() ?? '';
      final pos  = row['fish_stocks_position']?.toString() ?? '';
      if (rack.isNotEmpty && pos.isNotEmpty) return '$rack:$pos';
      return row['fish_stocks_tank_id']?.toString() ?? '#${index + 1}';
    case 'Samples':
      return row['sample_code']?.toString() ?? '#${index + 1}';
    case 'Reagents':
      final rn = row['reagent_name']?.toString() ?? '';
      return rn.isNotEmpty ? rn : (row['reagent_code']?.toString() ?? '#${index + 1}');
    case 'Equipment':
      final en = row['eq_name']?.toString() ?? '';
      return en.isNotEmpty ? en : (row['eq_code']?.toString() ?? '#${index + 1}');
    default:
      final n = row['name']?.toString() ?? '';
      return n.isNotEmpty ? n : (row['code']?.toString() ?? '#${index + 1}');
  }
}
