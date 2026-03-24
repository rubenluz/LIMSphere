// label_widgets.dart - Part of label_page.dart.
// UI components: _TemplatesTab, _CategoryHeader, _Pill, _TemplateCard, _IconBtn,
// _FieldRenderer, _BarcodePlaceholderPainter, _PreviewCanvas.

part of 'label_page.dart';


// ─────────────────────────────────────────────────────────────────────────────
// Tab 1 — Templates (grouped by category)
// ─────────────────────────────────────────────────────────────────────────────
class _TemplatesTab extends StatelessWidget {
  final List<LabelTemplate> templates;
  final LabelTemplate? activeTemplate;
  final PrinterConfig printer;
  final _ConnState connected;
  final List<Map<String, dynamic>> records;
  final String entityType;
  final void Function(LabelTemplate) onSelect;
  final void Function(LabelTemplate) onEdit;
  final void Function(LabelTemplate) onDelete;
  final void Function(LabelTemplate) onDuplicate;

  const _TemplatesTab({
    required this.templates, required this.activeTemplate,
    required this.printer, required this.connected,
    required this.records, required this.entityType,
    required this.onSelect, required this.onEdit,
    required this.onDelete, required this.onDuplicate,
  });

  @override
  Widget build(BuildContext context) {
    final Map<String, List<LabelTemplate>> byCategory = {};
    for (final t in templates) {
      byCategory.putIfAbsent(t.category, () => []).add(t);
    }

    final dotColor = switch (connected) {
      _ConnState.checking    => context.appTextMuted,
      _ConnState.connected   => AppDS.green,
      _ConnState.driverOnly  => const Color(0xFFF59E0B),
      _ConnState.unreachable => AppDS.red,
    };
    final connLabel = switch (connected) {
      _ConnState.checking    => 'Checking…',
      _ConnState.connected   => 'Connected',
      _ConnState.driverOnly  => 'Driver found — offline',
      _ConnState.unreachable => 'Not found',
    };

    return Column(children: [
      // Printer status bar
      Container(
        color: context.appSurface,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 8, height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
          ),
          const SizedBox(width: 8),
          Text(printer.deviceName,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.appTextPrimary)),
          const SizedBox(width: 6),
          Text('${printer.connectionType.toUpperCase()} · ${activeTemplate?.paperSize ?? '62x30'} mm · ${activeTemplate?.dpi ?? 300} dpi',
              style: TextStyle(fontSize: 11, color: context.appTextSecondary)),
          const SizedBox(width: 6),
          Text(connLabel,
              style: TextStyle(fontSize: 10, color: dotColor, fontWeight: FontWeight.w600)),
          const Spacer(),
          if (activeTemplate?.autoCut ?? false) ...[
            _Pill('Auto-cut', Icons.content_cut_rounded, AppDS.accent),
            const SizedBox(width: 6),
          ],
          if (activeTemplate?.rotate ?? false)
            _Pill('Rotated', Icons.rotate_90_degrees_ccw_rounded, AppDS.sky),
        ]),
      ),
      Divider(height: 1, color: context.appBorder),
      Expanded(
        child: templates.isEmpty
            ? Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.view_quilt_outlined, size: 48, color: context.appTextMuted),
                  const SizedBox(height: 12),
                  Text('No templates yet',
                      style: TextStyle(fontSize: 14, color: context.appTextMuted)),
                  const SizedBox(height: 6),
                  Text('Use "Starters" to add a pre-built template, or "New Template" to build from scratch.',
                      style: TextStyle(fontSize: 12, color: context.appTextMuted)),
                ]),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final category in byCategory.keys) ...[
                    _CategoryHeader(category),
                    const SizedBox(height: 10),
                    for (final t in byCategory[category]!)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _TemplateCard(
                          template: t,
                          isActive: activeTemplate?.id == t.id,
                          onSelect: () => onSelect(t),
                          onEdit: () => onEdit(t),
                          onDelete: () => onDelete(t),
                          onDuplicate: () => onDuplicate(t),
                          onPrint: () => _showPrintDialog(context, t),
                        ),
                      ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
      ),
    ]);
  }

  void _showPrintDialog(BuildContext context, LabelTemplate t) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PrintLabelPage(
          template: t,
          printer: printer,
          initialRecords: records,
          entityType: t.category,
        ),
      ),
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  final String category;
  const _CategoryHeader(this.category);

  static const _icons = <String, IconData>{
    'Strains':   Icons.science_outlined,
    'Reagents':  Icons.water_drop_outlined,
    'Equipment': Icons.build_outlined,
    'Samples':   Icons.inventory_2_outlined,
    'Stocks':    Icons.set_meal_rounded,
    'General':   Icons.label_outline,
  };

  @override
  Widget build(BuildContext context) {
    final icon = _icons[category] ?? Icons.label_outline;
    return Row(children: [
      Icon(icon, size: 13, color: context.appTextSecondary),
      const SizedBox(width: 6),
      Text(category.toUpperCase(),
          style: TextStyle(fontSize: 10, letterSpacing: 1.1,
              color: context.appTextSecondary, fontWeight: FontWeight.w700)),
      const SizedBox(width: 10),
      Expanded(child: Divider(color: context.appBorder)),
    ]);
  }
}


class _Pill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _Pill(this.label, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _TemplateCard extends StatefulWidget {
  final LabelTemplate template;
  final bool isActive;
  final VoidCallback onSelect, onEdit, onDelete, onDuplicate, onPrint;
  const _TemplateCard({
    required this.template, required this.isActive,
    required this.onSelect, required this.onEdit,
    required this.onDelete, required this.onDuplicate, required this.onPrint,
  });
  @override
  State<_TemplateCard> createState() => _TemplateCardState();
}

class _TemplateCardState extends State<_TemplateCard> {
  Map<String, dynamic>? _previewData;

  @override
  void initState() {
    super.initState();
    _fetchPreviewRow();
  }

  @override
  void didUpdateWidget(_TemplateCard old) {
    super.didUpdateWidget(old);
    if (old.template.category != widget.template.category) _fetchPreviewRow();
  }

  Future<void> _fetchPreviewRow() async {
    try {
      final table = _tableForEntity(widget.template.category);
      final rows = await Supabase.instance.client
          .from(table).select(_selectForCategory(widget.template.category)).limit(100) as List<dynamic>;
      if (!mounted || rows.isEmpty) return;
      final idx = DateTime.now().microsecondsSinceEpoch % rows.length;
      final row = _flattenJoins(rows[idx]);
      _injectQr([row], widget.template.category);
      setState(() => _previewData = row);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final data = _previewData ?? _sampleDataFor(widget.template.category);
    return GestureDetector(
      onTap: widget.onSelect,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: context.appSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.isActive ? AppDS.accent : context.appBorder,
            width: widget.isActive ? 1.5 : 1,
          ),
          boxShadow: widget.isActive ? [BoxShadow(color: AppDS.accent.withValues(alpha: 0.15), blurRadius: 12)] : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            // Preview thumbnail — real DB data when available
            Container(
              width: 90, height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: context.appBorder),
              ),
              clipBehavior: Clip.antiAlias,
              child: FittedBox(
                fit: BoxFit.contain,
                child: _PreviewCanvas(
                  template: widget.template, scale: 1.5,
                  sampleData: data,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.template.name,
                  style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: widget.isActive ? AppDS.accent : context.appTextPrimary,
                  )),
              const SizedBox(height: 3),
              Text('${widget.template.labelW.toInt()}×${widget.template.labelH.toInt()} mm · ${widget.template.fields.length} fields',
                  style: TextStyle(fontSize: 11, color: context.appTextSecondary)),
            ])),
            if (widget.isActive) const Icon(Icons.check_circle_rounded, color: AppDS.accent, size: 16),
            const SizedBox(width: 8),
            _IconBtn(icon: Icons.edit_outlined, onTap: widget.onEdit, tooltip: 'Edit'),
            _IconBtn(icon: Icons.copy_rounded, onTap: widget.onDuplicate, tooltip: 'Duplicate'),
            _IconBtn(icon: Icons.print_rounded, onTap: widget.onPrint, tooltip: 'Print'),
            _IconBtn(icon: Icons.delete_outline_rounded, onTap: widget.onDelete,
                tooltip: 'Delete', color: AppDS.red),
          ]),
        ),
      ),
    );
  }
}



class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final Color color;
  const _IconBtn({required this.icon, required this.onTap, required this.tooltip, this.color = AppDS.textSecondary});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 17, color: color),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Field renderer — used in both builder canvas and preview
// ─────────────────────────────────────────────────────────────────────────────
class _FieldRenderer extends StatelessWidget {
  final LabelField field;
  final double scale;
  final Map<String, dynamic>? data;

  const _FieldRenderer({required this.field, this.scale = 1, this.data});

  String get _resolvedContent {
    final now = DateTime.now();
    final dateFmt = DateFormat('yyyy-MM-dd');
    final timeFmt = DateFormat('HH:mm');
    String s = field.content
        .replaceAll('{current_time}', timeFmt.format(now))
        .replaceAll('{current_date}', dateFmt.format(now));
    s = s.replaceAllMapped(RegExp(r'\{date\+(\d+)\}'), (m) {
      final n = int.tryParse(m.group(1) ?? '') ?? 0;
      return dateFmt.format(now.add(Duration(days: n)));
    });
    if (data != null) {
      data!.forEach((k, v) => s = s.replaceAll('{$k}', v?.toString() ?? ''));
    }
    return s;
  }

  @override
  Widget build(BuildContext context) {
    return switch (field.type) {
      LabelFieldType.text => field.content.contains('{strain_scientific_name}')
        ? _scientificNameText(
            _resolvedContent,
            TextStyle(
              fontSize: (field.fontSize * scale * (25.4 / 72)).clamp(4.0, 200.0),
              fontWeight: field.fontWeight,
              color: field.color,
            ),
            textAlign: field.textAlign,
            softWrap: true,
            overflow: TextOverflow.visible,
          )
        : Text(_resolvedContent,
          style: TextStyle(
            // Convert pt → canvas px so the font is proportional to the label size
            fontSize: (field.fontSize * scale * (25.4 / 72)).clamp(4.0, 200.0),
            fontWeight: field.fontWeight,
            color: field.color,
          ),
          textAlign: field.textAlign,
          softWrap: true,
          overflow: TextOverflow.visible,
        ),
      LabelFieldType.qrcode => FittedBox(
        fit: BoxFit.contain,
        child: QrImageView(
          data: _resolvedContent.isEmpty ? 'QR' : _resolvedContent,
          version: QrVersions.auto,
          size: 200,
          eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
          dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
          backgroundColor: Colors.white,
        ),
      ),
      LabelFieldType.barcode => Center(child: CustomPaint(
        painter: _BarcodePlaceholderPainter(),
        size: Size(field.w * scale, field.h * scale * 0.8),
      )),
      LabelFieldType.divider => Container(
        height: 1,
        margin: EdgeInsets.symmetric(vertical: (field.h * scale / 2 - 0.5).clamp(0, 100)),
        color: field.color,
      ),
      LabelFieldType.image => Container(
        color: Colors.grey.shade200,
        child: const Icon(Icons.image_outlined, size: 16, color: Colors.grey),
      ),
    };
  }
}

// Suffixes that identify names at family rank and above (not italicised).
// Genus, species, and infraspecific epithets carry none of these endings.
bool _isHigherTaxon(String word) {
  const suffixes = [
    'aceae',    // family – plants, fungi, bacteria
    'idae',     // family – animals
    'oideae',   // subfamily – plants
    'inae',     // subfamily – animals
    'ales',     // order – plants, fungi, bacteria
    'iformes',  // order – vertebrates
    'phyceae',  // class – algae
    'mycetes',  // class – fungi
    'opsida',   // class – plants
    'mycota',   // phylum – fungi
    'phyta',    // phylum – plants
    'viridae',  // family – viruses
    'virales',  // order – viruses
  ];
  final lower = word.toLowerCase();
  return suffixes.any((s) => lower.endsWith(s));
}

// Renders a scientific name word-by-word:
// – abbreviations (ending in '.') and higher-taxon names (family and above)
//   stay upright; genus, species, and infraspecific epithets are italic.
Widget _scientificNameText(
  String name,
  TextStyle base, {
  TextAlign textAlign = TextAlign.start,
  bool softWrap = false,
  TextOverflow overflow = TextOverflow.ellipsis,
}) {
  final words = name.split(' ');
  final spans = <TextSpan>[];
  for (var i = 0; i < words.length; i++) {
    final word = words[i];
    final upright = word.endsWith('.') || _isHigherTaxon(word);
    spans.add(TextSpan(
      text: i < words.length - 1 ? '$word ' : word,
      style: base.copyWith(
        fontStyle: upright ? FontStyle.normal : FontStyle.italic,
      ),
    ));
  }
  return Text.rich(
    TextSpan(children: spans),
    textAlign: textAlign,
    softWrap: softWrap,
    overflow: overflow,
  );
}

class _BarcodePlaceholderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.black;
    final widths = [2.0, 1.0, 3.0, 1.0, 2.0, 1.0, 1.0, 3.0, 2.0, 1.0, 2.0, 1.0, 3.0, 1.0, 2.0];
    double x = 0;
    bool draw = true;
    for (final w in widths) {
      final barW = w / widths.fold(0.0, (a, b) => a + b) * size.width;
      if (draw) canvas.drawRect(Rect.fromLTWH(x, 0, barW - 0.5, size.height), p);
      x += barW;
      draw = !draw;
    }
  }
  @override bool shouldRepaint(_) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Preview canvas (read-only — used in template cards & print dialog)
// ─────────────────────────────────────────────────────────────────────────────
class _PreviewCanvas extends StatelessWidget {
  final LabelTemplate template;
  final double scale;
  final Map<String, dynamic>? sampleData;

  const _PreviewCanvas({required this.template, this.scale = 2.0, this.sampleData});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: template.labelW * scale,
      height: template.labelH * scale,
      color: Colors.white,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: template.fields.map((f) => Positioned(
          left: f.x * scale, top: f.y * scale,
          child: SizedBox(
            width: f.w * scale, height: f.h * scale,
            child: _FieldRenderer(field: f, scale: scale, data: sampleData),
          ),
        )).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Extension helpers
// ─────────────────────────────────────────────────────────────────────────────
extension _IterableFirstOrNull<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}
