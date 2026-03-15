import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '/theme/theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data models
// ─────────────────────────────────────────────────────────────────────────────

enum LabelFieldType { text, barcode, qrcode, divider, image }

class LabelField {
  final String id;
  LabelFieldType type;
  String content;      // static text OR field key like '{strain_code}'
  double x, y, w, h;
  double fontSize;
  FontWeight fontWeight;
  TextAlign textAlign;
  Color color;
  bool isPlaceholder;  // true = bound to a real DB field

  LabelField({
    required this.id,
    required this.type,
    required this.content,
    this.x = 10,
    this.y = 10,
    this.w = 120,
    this.h = 20,
    this.fontSize = 10,
    this.fontWeight = FontWeight.normal,
    this.textAlign = TextAlign.left,
    this.color = Colors.black,
    this.isPlaceholder = false,
  });

  LabelField copyWith({
    LabelFieldType? type,
    String? content,
    double? x, double? y, double? w, double? h,
    double? fontSize,
    FontWeight? fontWeight,
    TextAlign? textAlign,
    Color? color,
    bool? isPlaceholder,
  }) {
    return LabelField(
      id: id,
      type: type ?? this.type,
      content: content ?? this.content,
      x: x ?? this.x, y: y ?? this.y, w: w ?? this.w, h: h ?? this.h,
      fontSize: fontSize ?? this.fontSize,
      fontWeight: fontWeight ?? this.fontWeight,
      textAlign: textAlign ?? this.textAlign,
      color: color ?? this.color,
      isPlaceholder: isPlaceholder ?? this.isPlaceholder,
    );
  }
}

class LabelTemplate {
  String id;
  String name;
  double labelW;   // mm
  double labelH;   // mm
  List<LabelField> fields;

  LabelTemplate({
    required this.id,
    required this.name,
    this.labelW = 62,
    this.labelH = 30,
    List<LabelField>? fields,
  }) : fields = fields ?? [];

  LabelTemplate clone() => LabelTemplate(
    id: id, name: name, labelW: labelW, labelH: labelH,
    fields: fields.map((f) => f.copyWith()).toList(),
  );
}

class PrinterConfig {
  String connectionType;   // 'bluetooth' | 'wifi'
  String deviceName;
  String ipAddress;
  String paperSize;        // '62x30' | '62x100' | '62x29' | '29x90'
  int dpi;                 // 300 | 600
  bool autoCut;
  bool halfCut;
  bool rotate;             // 90°
  int copies;

  PrinterConfig({
    this.connectionType = 'wifi',
    this.deviceName = 'Brother QL-820NWB',
    this.ipAddress = '192.168.1.100',
    this.paperSize = '62x30',
    this.dpi = 300,
    this.autoCut = true,
    this.halfCut = false,
    this.rotate = false,
    this.copies = 1,
  });
}

const _kAvailableFields = [
  (key: '{strain_code}',     label: 'Strain Code'),
  (key: '{strain_status}',   label: 'Status'),
  (key: '{strain_species}',  label: 'Species'),
  (key: '{strain_genus}',    label: 'Genus'),
  (key: '{strain_medium}',   label: 'Medium'),
  (key: '{strain_room}',     label: 'Room'),
  (key: '{strain_next_transfer}', label: 'Next Transfer'),
  (key: '{s_island}',        label: 'Island (Origin)'),
  (key: '{s_country}',       label: 'Country'),
];

// ─────────────────────────────────────────────────────────────────────────────
// Main page
// ─────────────────────────────────────────────────────────────────────────────
class PrintStrainsPage extends StatefulWidget {
  const PrintStrainsPage({super.key});

  @override
  State<PrintStrainsPage> createState() => _PrintStrainsPageState();
}

class _PrintStrainsPageState extends State<PrintStrainsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  final _printer = PrinterConfig();
  LabelTemplate? _activeTemplate;

  final List<LabelTemplate> _templates = [
    LabelTemplate(
      id: 'default',
      name: 'Default 62×30',
      labelW: 62, labelH: 30,
      fields: [
        LabelField(id: 'f1', type: LabelFieldType.text,
            content: '{strain_code}', x: 4, y: 3, w: 100, h: 14,
            fontSize: 11, fontWeight: FontWeight.bold, isPlaceholder: true),
        LabelField(id: 'f2', type: LabelFieldType.text,
            content: '{strain_species}', x: 4, y: 16, w: 120, h: 10,
            fontSize: 8, isPlaceholder: true),
        LabelField(id: 'f3', type: LabelFieldType.qrcode,
            content: '{strain_code}', x: 130, y: 2, w: 26, h: 26,
            isPlaceholder: true),
      ],
    ),
    LabelTemplate(
      id: 'small',
      name: 'Small ID Label',
      labelW: 62, labelH: 20,
      fields: [
        LabelField(id: 'f1', type: LabelFieldType.text,
            content: '{strain_code}', x: 4, y: 4, w: 80, h: 12,
            fontSize: 9, fontWeight: FontWeight.bold, isPlaceholder: true),
        LabelField(id: 'f3', type: LabelFieldType.barcode,
            content: '{strain_code}', x: 90, y: 2, w: 60, h: 16,
            isPlaceholder: true),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _activeTemplate = _templates.first;
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AppDS.bg,
        appBarTheme: const AppBarTheme(backgroundColor: AppDS.surface, foregroundColor: AppDS.textPrimary, elevation: 0),
        tabBarTheme: const TabBarThemeData(
          labelColor: AppDS.accent,
          unselectedLabelColor: AppDS.textSecondary,
          indicatorColor: AppDS.accent,
          dividerColor: AppDS.border,
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Row(children: [
            Icon(Icons.print_rounded, size: 18, color: AppDS.accent),
            SizedBox(width: 10),
            Text('Label Printing', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ]),
          bottom: TabBar(
            controller: _tabs,
            tabs: const [
              Tab(icon: Icon(Icons.view_quilt_rounded, size: 16), text: 'Templates'),
              Tab(icon: Icon(Icons.edit_rounded, size: 16), text: 'Builder'),
              Tab(icon: Icon(Icons.settings_rounded, size: 16), text: 'Printer'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabs,
          children: [
            _TemplatesTab(
              templates: _templates,
              activeTemplate: _activeTemplate,
              printer: _printer,
              onSelect: (t) => setState(() => _activeTemplate = t),
              onEdit: (t) {
                setState(() => _activeTemplate = t);
                _tabs.animateTo(1);
              },
              onDelete: (t) => setState(() {
                _templates.removeWhere((x) => x.id == t.id);
                if (_activeTemplate?.id == t.id) _activeTemplate = _templates.firstOrNull;
              }),
              onAdd: () {
                final newT = LabelTemplate(
                  id: 'tpl_${DateTime.now().millisecondsSinceEpoch}',
                  name: 'New Template',
                  labelW: double.tryParse(_printer.paperSize.split('x')[0]) ?? 62,
                  labelH: double.tryParse(_printer.paperSize.split('x')[1]) ?? 30,
                );
                setState(() {
                  _templates.add(newT);
                  _activeTemplate = newT;
                });
                _tabs.animateTo(1);
              },
            ),
            _BuilderTab(
              template: _activeTemplate,
              onSave: (t) {
                setState(() {
                  final i = _templates.indexWhere((x) => x.id == t.id);
                  if (i >= 0) _templates[i] = t;
                  else _templates.add(t);
                  _activeTemplate = t;
                });
              },
            ),
            _PrinterTab(config: _printer, onChanged: () => setState(() {})),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 1 — Templates
// ─────────────────────────────────────────────────────────────────────────────
class _TemplatesTab extends StatelessWidget {
  final List<LabelTemplate> templates;
  final LabelTemplate? activeTemplate;
  final PrinterConfig printer;
  final void Function(LabelTemplate) onSelect;
  final void Function(LabelTemplate) onEdit;
  final void Function(LabelTemplate) onDelete;
  final VoidCallback onAdd;

  const _TemplatesTab({
    required this.templates, required this.activeTemplate,
    required this.printer,
    required this.onSelect, required this.onEdit,
    required this.onDelete, required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Printer status bar
      Container(
        color: AppDS.surface,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          Container(
            width: 8, height: 8,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: AppDS.green),
          ),
          const SizedBox(width: 8),
          Text(printer.deviceName,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppDS.textPrimary)),
          const SizedBox(width: 6),
          Text('${printer.paperSize} mm · ${printer.dpi} dpi',
              style: const TextStyle(fontSize: 11, color: AppDS.textSecondary)),
          const Spacer(),
          if (printer.autoCut)
            _Pill('Auto-cut', Icons.content_cut_rounded, AppDS.accent),
          const SizedBox(width: 6),
          if (printer.rotate)
            _Pill('Rotated', Icons.rotate_90_degrees_ccw_rounded, AppDS.sky),
        ]),
      ),
      const Divider(height: 1, color: AppDS.border),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Add new template card
            GestureDetector(
              onTap: onAdd,
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                  border: Border.all(color: AppDS.border, width: 1.5, style: BorderStyle.solid),
                  borderRadius: BorderRadius.circular(12),
                  color: AppDS.surface.withValues(alpha: 0.4),
                ),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.add_rounded, color: AppDS.accent, size: 22),
                  SizedBox(width: 10),
                  Text('New Template', style: TextStyle(color: AppDS.accent, fontSize: 14, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            ...templates.map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _TemplateCard(
                template: t,
                isActive: activeTemplate?.id == t.id,
                onSelect: () => onSelect(t),
                onEdit: () => onEdit(t),
                onDelete: () => onDelete(t),
                onPrint: () => _showPrintDialog(context, t),
              ),
            )),
          ],
        ),
      ),
    ]);
  }

  void _showPrintDialog(BuildContext context, LabelTemplate t) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppDS.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Print Labels', style: TextStyle(color: AppDS.textPrimary, fontSize: 16)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _PreviewCanvas(template: t, scale: 3.0),
          const SizedBox(height: 16),
          Text('Template: ${t.name}', style: const TextStyle(color: AppDS.textSecondary, fontSize: 12)),
          Text('${t.labelW.toInt()}×${t.labelH.toInt()} mm · ${t.fields.length} fields',
              style: const TextStyle(color: AppDS.textSecondary, fontSize: 12)),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppDS.textSecondary)),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppDS.accent, foregroundColor: AppDS.bg),
            icon: const Icon(Icons.print_rounded, size: 16),
            label: const Text('Print'),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Sending to printer…'),
                  backgroundColor: AppDS.border,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              );
            },
          ),
        ],
      ),
    );
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

class _TemplateCard extends StatelessWidget {
  final LabelTemplate template;
  final bool isActive;
  final VoidCallback onSelect, onEdit, onDelete, onPrint;
  const _TemplateCard({
    required this.template, required this.isActive,
    required this.onSelect, required this.onEdit,
    required this.onDelete, required this.onPrint,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelect,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: AppDS.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? AppDS.accent : AppDS.border,
            width: isActive ? 1.5 : 1,
          ),
          boxShadow: isActive ? [BoxShadow(color: AppDS.accent.withValues(alpha: 0.15), blurRadius: 12)] : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            // Preview thumbnail
            Container(
              width: 90, height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppDS.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: FittedBox(
                fit: BoxFit.contain,
                child: _PreviewCanvas(template: template, scale: 1.5),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(template.name,
                  style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: isActive ? AppDS.accent : AppDS.textPrimary,
                  )),
              const SizedBox(height: 3),
              Text('${template.labelW.toInt()}×${template.labelH.toInt()} mm · ${template.fields.length} fields',
                  style: const TextStyle(fontSize: 11, color: AppDS.textSecondary)),
            ])),
            if (isActive) const Icon(Icons.check_circle_rounded, color: AppDS.accent, size: 16),
            const SizedBox(width: 8),
            _IconBtn(icon: Icons.edit_outlined, onTap: onEdit, tooltip: 'Edit'),
            _IconBtn(icon: Icons.print_rounded, onTap: onPrint, tooltip: 'Print'),
            _IconBtn(icon: Icons.delete_outline_rounded, onTap: onDelete,
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
// Tab 2 — Builder
// ─────────────────────────────────────────────────────────────────────────────
class _BuilderTab extends StatefulWidget {
  final LabelTemplate? template;
  final void Function(LabelTemplate) onSave;
  const _BuilderTab({required this.template, required this.onSave});

  @override
  State<_BuilderTab> createState() => _BuilderTabState();
}

class _BuilderTabState extends State<_BuilderTab> {
  late LabelTemplate _tpl;
  String? _selectedFieldId;
  final double _scale = 4.0; // px per mm on canvas

  @override
  void initState() {
    super.initState();
    _tpl = widget.template?.clone() ?? LabelTemplate(id: 'new', name: 'New Template');
  }

  @override
  void didUpdateWidget(_BuilderTab old) {
    super.didUpdateWidget(old);
    if (widget.template?.id != old.template?.id) {
      setState(() {
        _tpl = widget.template?.clone() ?? LabelTemplate(id: 'new', name: 'New Template');
        _selectedFieldId = null;
      });
    }
  }

  LabelField? get _selectedField =>
      _tpl.fields.firstWhereOrNull((f) => f.id == _selectedFieldId);

  void _addField(LabelFieldType type, {String? content, bool isPlaceholder = false}) {
    final id = 'f${DateTime.now().millisecondsSinceEpoch}';
    final field = LabelField(
      id: id, type: type,
      content: content ?? (type == LabelFieldType.text ? 'Text' : '{strain_code}'),
      x: 4, y: 4,
      w: type == LabelFieldType.qrcode ? 24 : type == LabelFieldType.barcode ? 60 : 100,
      h: type == LabelFieldType.qrcode ? 24 : type == LabelFieldType.barcode ? 16 : 12,
      isPlaceholder: isPlaceholder,
    );
    setState(() {
      _tpl.fields.add(field);
      _selectedFieldId = id;
    });
  }

  void _deleteField(String id) {
    setState(() {
      _tpl.fields.removeWhere((f) => f.id == id);
      if (_selectedFieldId == id) _selectedFieldId = null;
    });
  }

  void _updateField(LabelField updated) {
    setState(() {
      final i = _tpl.fields.indexWhere((f) => f.id == updated.id);
      if (i >= 0) _tpl.fields[i] = updated;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.template == null) {
      return const Center(child: Text('No template selected.\nGo to Templates and select or create one.',
          textAlign: TextAlign.center, style: TextStyle(color: AppDS.textSecondary)));
    }
    return Column(children: [
      // Top bar
      Container(
        color: AppDS.surface,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: TextEditingController(text: _tpl.name)
                ..selection = TextSelection.collapsed(offset: _tpl.name.length),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppDS.textPrimary),
              decoration: const InputDecoration(
                isDense: true, border: InputBorder.none,
                hintText: 'Template name…',
                hintStyle: TextStyle(color: AppDS.textSecondary),
              ),
              onChanged: (v) => _tpl.name = v,
            ),
          ),
          Text('${_tpl.labelW.toInt()}×${_tpl.labelH.toInt()} mm',
              style: const TextStyle(fontSize: 11, color: AppDS.textSecondary)),
          const SizedBox(width: 12),
          FilledButton.icon(
            style: FilledButton.styleFrom(
                backgroundColor: AppDS.accent, foregroundColor: AppDS.bg,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
            icon: const Icon(Icons.save_rounded, size: 15),
            label: const Text('Save', style: TextStyle(fontSize: 12)),
            onPressed: () {
              widget.onSave(_tpl.clone());
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: const Text('Template saved'),
                backgroundColor: AppDS.border,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ));
            },
          ),
        ]),
      ),
      const Divider(height: 1, color: AppDS.border),

      Expanded(
        child: Row(children: [
          // Left panel — field palette
          Container(
            width: 160,
            color: AppDS.surface,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(12, 12, 12, 6),
                child: Text('ADD FIELD', style: TextStyle(fontSize: 9, letterSpacing: 1.2,
                    color: AppDS.textSecondary, fontWeight: FontWeight.w700)),
              ),
              _PaletteBtn('Text', Icons.text_fields_rounded,
                  () => _addField(LabelFieldType.text)),
              _PaletteBtn('DB Field', Icons.data_object_rounded,
                  () => _showFieldPicker()),
              _PaletteBtn('QR Code', Icons.qr_code_2_rounded,
                  () => _addField(LabelFieldType.qrcode, isPlaceholder: true)),
              _PaletteBtn('Barcode', Icons.barcode_reader,
                  () => _addField(LabelFieldType.barcode, isPlaceholder: true)),
              _PaletteBtn('Divider', Icons.horizontal_rule_rounded,
                  () => _addField(LabelFieldType.divider)),
              const Divider(color: AppDS.border, height: 20),
              const Padding(
                padding: EdgeInsets.fromLTRB(12, 0, 12, 6),
                child: Text('FIELDS', style: TextStyle(fontSize: 9, letterSpacing: 1.2,
                    color: AppDS.textSecondary, fontWeight: FontWeight.w700)),
              ),
              Expanded(
                child: ListView(
                  children: _tpl.fields.map((f) => _FieldListItem(
                    field: f,
                    isSelected: _selectedFieldId == f.id,
                    onTap: () => setState(() => _selectedFieldId = f.id),
                    onDelete: () => _deleteField(f.id),
                  )).toList(),
                ),
              ),
            ]),
          ),
          const VerticalDivider(width: 1, color: AppDS.border),

          // Center — canvas
          Expanded(
            child: Container(
              color: const Color(0xFF0A0F1A),
              child: Center(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: _BuilderCanvas(
                      template: _tpl,
                      scale: _scale,
                      selectedId: _selectedFieldId,
                      onSelect: (id) => setState(() => _selectedFieldId = id),
                      onMove: (id, dx, dy) {
                        final f = _tpl.fields.firstWhereOrNull((f) => f.id == id);
                        if (f != null) _updateField(f.copyWith(x: (f.x + dx / _scale).clamp(0, _tpl.labelW - 5), y: (f.y + dy / _scale).clamp(0, _tpl.labelH - 3)));
                      },
                      onResize: (id, dw, dh) {
                        final f = _tpl.fields.firstWhereOrNull((f) => f.id == id);
                        if (f != null) _updateField(f.copyWith(w: (f.w + dw / _scale).clamp(10, _tpl.labelW), h: (f.h + dh / _scale).clamp(5, _tpl.labelH)));
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
          const VerticalDivider(width: 1, color: AppDS.border),

          // Right panel — properties
          if (_selectedField != null)
            Container(
              width: 200,
              color: AppDS.surface,
              child: _FieldProperties(
                field: _selectedField!,
                onChange: _updateField,
              ),
            ),
        ]),
      ),
    ]);
  }

  void _showFieldPicker() async {
    final picked = await showModalBottomSheet<({String key, String label})>(
      context: context,
      backgroundColor: AppDS.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Choose Database Field',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppDS.textPrimary)),
          ),
          ..._kAvailableFields.map((f) => ListTile(
            dense: true,
            leading: const Icon(Icons.data_object_rounded, size: 16, color: AppDS.accent),
            title: Text(f.label, style: const TextStyle(fontSize: 13, color: AppDS.textPrimary)),
            subtitle: Text(f.key, style: const TextStyle(fontSize: 10, color: AppDS.textSecondary)),
            onTap: () => Navigator.pop(context, f),
          )),
          const SizedBox(height: 16),
        ],
      ),
    );
    if (picked != null) {
      _addField(LabelFieldType.text, content: picked.key, isPlaceholder: true);
    }
  }
}

class _PaletteBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _PaletteBtn(this.label, this.icon, this.onTap);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(children: [
          Icon(icon, size: 15, color: AppDS.accent),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(fontSize: 12, color: AppDS.textPrimary)),
        ]),
      ),
    );
  }
}

class _FieldListItem extends StatelessWidget {
  final LabelField field;
  final bool isSelected;
  final VoidCallback onTap, onDelete;
  const _FieldListItem({required this.field, required this.isSelected, required this.onTap, required this.onDelete});

  IconData get _typeIcon => switch (field.type) {
    LabelFieldType.text => Icons.text_fields_rounded,
    LabelFieldType.qrcode => Icons.qr_code_2_rounded,
    LabelFieldType.barcode => Icons.barcode_reader,
    LabelFieldType.divider => Icons.horizontal_rule_rounded,
    LabelFieldType.image => Icons.image_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppDS.accent.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isSelected ? AppDS.accent.withValues(alpha: 0.4) : Colors.transparent),
        ),
        child: Row(children: [
          Icon(_typeIcon, size: 13, color: isSelected ? AppDS.accent : AppDS.textSecondary),
          const SizedBox(width: 6),
          Expanded(child: Text(
            field.content.length > 16 ? '${field.content.substring(0, 16)}…' : field.content,
            style: TextStyle(fontSize: 11, color: isSelected ? AppDS.accent : AppDS.textPrimary),
            overflow: TextOverflow.ellipsis,
          )),
          InkWell(
            onTap: onDelete,
            child: const Icon(Icons.close, size: 12, color: AppDS.textSecondary),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Builder canvas (drag + resize)
// ─────────────────────────────────────────────────────────────────────────────
class _BuilderCanvas extends StatelessWidget {
  final LabelTemplate template;
  final double scale;
  final String? selectedId;
  final void Function(String id) onSelect;
  final void Function(String id, double dx, double dy) onMove;
  final void Function(String id, double dw, double dh) onResize;

  const _BuilderCanvas({
    required this.template, required this.scale,
    required this.selectedId, required this.onSelect,
    required this.onMove, required this.onResize,
  });

  @override
  Widget build(BuildContext context) {
    final cw = template.labelW * scale;
    final ch = template.labelH * scale;

    return Container(
      width: cw, height: ch,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(3),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 20, spreadRadius: 2),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // Grid
          CustomPaint(painter: _GridPainter(scale: scale), size: Size(cw, ch)),
          // Fields
          ...template.fields.map((f) {
            final isSelected = selectedId == f.id;
            return Positioned(
              left: f.x * scale, top: f.y * scale,
              child: GestureDetector(
                onTap: () => onSelect(f.id),
                onPanUpdate: (d) => onMove(f.id, d.delta.dx, d.delta.dy),
                child: Stack(clipBehavior: Clip.none, children: [
                  Container(
                    width: f.w * scale, height: f.h * scale,
                    decoration: isSelected ? BoxDecoration(
                      border: Border.all(color: AppDS.accent, width: 1.5),
                    ) : null,
                    child: _FieldRenderer(field: f, scale: scale),
                  ),
                  // Resize handle (bottom-right)
                  if (isSelected)
                    Positioned(
                      right: -5, bottom: -5,
                      child: GestureDetector(
                        onPanUpdate: (d) => onResize(f.id, d.delta.dx, d.delta.dy),
                        child: Container(
                          width: 10, height: 10,
                          decoration: BoxDecoration(
                            color: AppDS.accent,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                        ),
                      ),
                    ),
                ]),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  final double scale;
  const _GridPainter({required this.scale});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppDS.tableBorder.withValues(alpha: 0.5)
      ..strokeWidth = 0.5;
    // 5mm grid
    final step = 5 * scale;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Field renderer (used in both builder canvas and preview)
// ─────────────────────────────────────────────────────────────────────────────
class _FieldRenderer extends StatelessWidget {
  final LabelField field;
  final double scale;
  final Map<String, dynamic>? data; // live data for print preview

  const _FieldRenderer({required this.field, this.scale = 1, this.data});

  String get _resolvedContent {
    if (data == null) return field.content;
    String s = field.content;
    data!.forEach((k, v) {
      s = s.replaceAll('{$k}', v?.toString() ?? '');
    });
    return s;
  }

  @override
  Widget build(BuildContext context) {
    return switch (field.type) {
      LabelFieldType.text => Align(
        alignment: Alignment.centerLeft,
        child: Text(_resolvedContent,
          style: TextStyle(
            fontSize: field.fontSize,
            fontWeight: field.fontWeight,
            color: field.color,
            height: 1.1,
          ),
          textAlign: field.textAlign,
          overflow: TextOverflow.ellipsis,
          maxLines: 3,
        ),
      ),
      LabelFieldType.qrcode => Center(child: CustomPaint(
        painter: _QRPlaceholderPainter(),
        size: Size(field.h * scale * 0.9, field.h * scale * 0.9),
      )),
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

class _QRPlaceholderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.black;
    final cell = size.width / 7;
    // Draw simplified QR-like pattern
    for (int r = 0; r < 7; r++) {
      for (int c = 0; c < 7; c++) {
        final inTopLeft  = r < 3 && c < 3;
        final inTopRight = r < 3 && c >= 4;
        final inBotLeft  = r >= 4 && c < 3;
        if (inTopLeft || inTopRight || inBotLeft) {
          canvas.drawRect(Rect.fromLTWH(c * cell, r * cell, cell * 0.85, cell * 0.85), p);
        } else if ((r + c) % 2 == 0) {
          canvas.drawRect(Rect.fromLTWH(c * cell, r * cell, cell * 0.75, cell * 0.75), p);
        }
      }
    }
  }
  @override bool shouldRepaint(_) => false;
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
// Field properties panel
// ─────────────────────────────────────────────────────────────────────────────
class _FieldProperties extends StatelessWidget {
  final LabelField field;
  final void Function(LabelField) onChange;
  const _FieldProperties({required this.field, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Text('PROPERTIES', style: TextStyle(fontSize: 9, letterSpacing: 1.2,
            color: AppDS.textSecondary, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),

        // Content
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
                value: field.fontSize.clamp(6, 24),
                min: 6, max: 24,
                divisions: 18,
                activeColor: AppDS.accent,
                onChanged: (v) => onChange(field.copyWith(fontSize: v)),
              ),
            ),
            Text('${field.fontSize.toInt()}', style: const TextStyle(fontSize: 11, color: AppDS.textSecondary)),
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
          Expanded(child: _NumField('W', field.w, (v) => onChange(field.copyWith(w: v)))),
          const SizedBox(width: 6),
          Expanded(child: _NumField('H', field.h, (v) => onChange(field.copyWith(h: v)))),
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
    child: Text(text, style: const TextStyle(fontSize: 10, color: AppDS.textSecondary, fontWeight: FontWeight.w600)),
  );
}

class _PropField extends StatelessWidget {
  final String value;
  final void Function(String) onChanged;
  const _PropField({required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => TextField(
    controller: TextEditingController(text: value)
        ..selection = TextSelection.collapsed(offset: value.length),
    style: const TextStyle(fontSize: 12, color: AppDS.textPrimary),
    decoration: InputDecoration(
      isDense: true, filled: true, fillColor: AppDS.bg,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppDS.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppDS.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppDS.accent)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
    ),
    onChanged: onChanged,
  );
}

class _NumField extends StatelessWidget {
  final String label;
  final double value;
  final void Function(double) onChanged;
  const _NumField(this.label, this.value, this.onChanged);
  @override
  Widget build(BuildContext context) => TextField(
    controller: TextEditingController(text: value.toStringAsFixed(1)),
    style: const TextStyle(fontSize: 11, color: AppDS.textPrimary),
    keyboardType: TextInputType.number,
    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 10, color: AppDS.textSecondary),
      isDense: true, filled: true, fillColor: AppDS.bg,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppDS.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppDS.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppDS.accent)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
    ),
    onChanged: (v) { final d = double.tryParse(v); if (d != null) onChanged(d); },
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
        color: active ? AppDS.accent.withValues(alpha: 0.2) : AppDS.bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: active ? AppDS.accent : AppDS.border),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: active ? AppDS.accent : AppDS.textSecondary, fontWeight: FontWeight.bold)),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 3 — Printer settings
// ─────────────────────────────────────────────────────────────────────────────
class _PrinterTab extends StatefulWidget {
  final PrinterConfig config;
  final VoidCallback onChanged;
  const _PrinterTab({required this.config, required this.onChanged});

  @override
  State<_PrinterTab> createState() => _PrinterTabState();
}

class _PrinterTabState extends State<_PrinterTab> {
  late final _ipCtrl = TextEditingController(text: widget.config.ipAddress);

  final _paperSizes = const ['62x30', '62x100', '62x29', '29x90', '38x90', '54x29'];
  final _dpiOptions = const [300, 600];
  final _brotherModels = const [
    'Brother QL-820NWB',
    'Brother QL-810W',
    'Brother QL-800',
    'Brother QL-700',
  ];

  @override
  Widget build(BuildContext context) {
    final cfg = widget.config;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [

        // Connection
        _SectionHeader('Connection', Icons.wifi_rounded),
        const SizedBox(height: 12),
        _SegmentRow(
          label: 'Type',
          options: const {'wifi': 'Wi-Fi', 'bluetooth': 'Bluetooth'},
          value: cfg.connectionType,
          onChanged: (v) { setState(() => cfg.connectionType = v); widget.onChanged(); },
        ),
        const SizedBox(height: 12),
        _DropdownRow(
          label: 'Model',
          options: _brotherModels,
          value: cfg.deviceName,
          onChanged: (v) { setState(() => cfg.deviceName = v!); widget.onChanged(); },
        ),
        const SizedBox(height: 12),
        if (cfg.connectionType == 'wifi') ...[
          _PropLabel('IP Address'),
          const SizedBox(height: 4),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _ipCtrl,
                style: const TextStyle(fontSize: 13, color: AppDS.textPrimary),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  isDense: true, filled: true, fillColor: AppDS.surface,
                  hintText: '192.168.1.100',
                  hintStyle: const TextStyle(color: AppDS.textSecondary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppDS.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppDS.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppDS.accent)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onChanged: (v) => cfg.ipAddress = v,
              ),
            ),
            const SizedBox(width: 10),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppDS.border, foregroundColor: AppDS.textPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
              icon: const Icon(Icons.search_rounded, size: 16),
              label: const Text('Scan', style: TextStyle(fontSize: 12)),
              onPressed: _scanNetwork,
            ),
          ]),
          const SizedBox(height: 6),
        ],

        const SizedBox(height: 20),
        _SectionHeader('Paper & Print', Icons.straighten_rounded),
        const SizedBox(height: 12),

        // Paper size
        _PropLabel('Paper Size (mm)'),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: _paperSizes.map((s) {
            final isSelected = cfg.paperSize == s;
            return GestureDetector(
              onTap: () { setState(() => cfg.paperSize = s); widget.onChanged(); },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppDS.accent.withValues(alpha: 0.15) : AppDS.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isSelected ? AppDS.accent : AppDS.border, width: isSelected ? 1.5 : 1),
                ),
                child: Text(s, style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: isSelected ? AppDS.accent : AppDS.textPrimary)),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 16),
        _PropLabel('Resolution (DPI)'),
        const SizedBox(height: 6),
        Row(children: _dpiOptions.map((d) {
          final isSelected = cfg.dpi == d;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () { setState(() => cfg.dpi = d); widget.onChanged(); },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppDS.accent.withValues(alpha: 0.15) : AppDS.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isSelected ? AppDS.accent : AppDS.border, width: isSelected ? 1.5 : 1),
                ),
                child: Text('$d dpi', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isSelected ? AppDS.accent : AppDS.textPrimary)),
              ),
            ),
          );
        }).toList()),

        const SizedBox(height: 16),
        _SwitchRow('Auto Cut', 'Cut label after printing', Icons.content_cut_rounded,
            cfg.autoCut, (v) { setState(() => cfg.autoCut = v); widget.onChanged(); }),
        const SizedBox(height: 4),
        _SwitchRow('Half Cut', 'Partial cut (leave backing intact)', Icons.cut_rounded,
            cfg.halfCut, (v) { setState(() => cfg.halfCut = v); widget.onChanged(); }),
        const SizedBox(height: 4),
        _SwitchRow('Rotate 90°', 'Rotate label before printing', Icons.rotate_90_degrees_ccw_rounded,
            cfg.rotate, (v) { setState(() => cfg.rotate = v); widget.onChanged(); }),

        const SizedBox(height: 16),
        _PropLabel('Copies'),
        const SizedBox(height: 6),
        Row(children: [
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, color: AppDS.accent),
            onPressed: cfg.copies > 1 ? () { setState(() => cfg.copies--); widget.onChanged(); } : null,
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: AppDS.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppDS.border),
            ),
            child: Text('${cfg.copies}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppDS.textPrimary)),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: AppDS.accent),
            onPressed: cfg.copies < 99 ? () { setState(() => cfg.copies++); widget.onChanged(); } : null,
          ),
        ]),

        const SizedBox(height: 24),
        // Test print
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
                foregroundColor: AppDS.accent,
                side: const BorderSide(color: AppDS.accent),
                padding: const EdgeInsets.symmetric(vertical: 14)),
            icon: const Icon(Icons.print_outlined, size: 18),
            label: const Text('Send Test Print'),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: const Text('Test label sent to printer'),
              backgroundColor: AppDS.border,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            )),
          ),
        ),
      ],
    );
  }

  void _scanNetwork() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppDS.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Network Scan', style: TextStyle(color: AppDS.textPrimary, fontSize: 15)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const CircularProgressIndicator(color: AppDS.accent, strokeWidth: 2),
          const SizedBox(height: 16),
          const Text('Scanning for Brother devices…', style: TextStyle(color: AppDS.textSecondary, fontSize: 12)),
          const SizedBox(height: 16),
          // Simulated result
          ListTile(
            dense: true,
            leading: const Icon(Icons.print_rounded, color: AppDS.accent, size: 18),
            title: const Text('Brother QL-820NWB', style: TextStyle(color: AppDS.textPrimary, fontSize: 13)),
            subtitle: const Text('192.168.1.105', style: TextStyle(color: AppDS.textSecondary, fontSize: 11)),
            onTap: () {
              setState(() {
                widget.config.ipAddress = '192.168.1.105';
                _ipCtrl.text = '192.168.1.105';
              });
              Navigator.pop(context);
            },
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppDS.textSecondary))),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final IconData icon;
  const _SectionHeader(this.label, this.icon);
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 14, color: AppDS.accent),
    const SizedBox(width: 8),
    Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppDS.textPrimary)),
    const SizedBox(width: 12),
    const Expanded(child: Divider(color: AppDS.border)),
  ]);
}

class _SegmentRow extends StatelessWidget {
  final String label;
  final Map<String, String> options;
  final String value;
  final void Function(String) onChanged;
  const _SegmentRow({required this.label, required this.options, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => Row(children: [
    SizedBox(width: 80, child: Text(label, style: const TextStyle(fontSize: 12, color: AppDS.textSecondary))),
    SegmentedButton<String>(
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        backgroundColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? AppDS.accent.withValues(alpha: 0.2) : AppDS.surface),
        foregroundColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? AppDS.accent : AppDS.textSecondary),
        side: WidgetStateProperty.all(const BorderSide(color: AppDS.border)),
      ),
      segments: options.entries.map((e) => ButtonSegment(value: e.key, label: Text(e.value, style: const TextStyle(fontSize: 12)))).toList(),
      selected: {value},
      onSelectionChanged: (s) => onChanged(s.first),
    ),
  ]);
}

class _DropdownRow extends StatelessWidget {
  final String label;
  final List<String> options;
  final String value;
  final void Function(String?) onChanged;
  const _DropdownRow({required this.label, required this.options, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => Row(children: [
    SizedBox(width: 80, child: Text(label, style: const TextStyle(fontSize: 12, color: AppDS.textSecondary))),
    Expanded(
      child: DropdownButtonFormField<String>(
        value: value,
        dropdownColor: AppDS.surface,
        style: const TextStyle(fontSize: 12, color: AppDS.textPrimary),
        decoration: InputDecoration(
          isDense: true, filled: true, fillColor: AppDS.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppDS.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppDS.border)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
        items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
        onChanged: onChanged,
      ),
    ),
  ]);
}

class _SwitchRow extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final bool value;
  final void Function(bool) onChanged;
  const _SwitchRow(this.title, this.subtitle, this.icon, this.value, this.onChanged);
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(vertical: 2),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: AppDS.surface,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppDS.border),
    ),
    child: Row(children: [
      Icon(icon, size: 16, color: value ? AppDS.accent : AppDS.textSecondary),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: value ? AppDS.textPrimary : AppDS.textSecondary)),
        Text(subtitle, style: const TextStyle(fontSize: 10, color: AppDS.textSecondary)),
      ])),
      Switch(value: value, onChanged: onChanged, activeColor: AppDS.accent),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Preview canvas (read-only, used in template cards & print dialog)
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