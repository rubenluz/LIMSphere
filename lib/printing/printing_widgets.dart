// printing_widgets.dart - Part of printing_page.dart.
// UI components: _TemplatesTab, _CategoryHeader, _PrintDialog,
// _RecordList, _EmptyRecordsPanel, _Pill, _TemplateCard, _IconBtn,
// _FieldRenderer, _BarcodePlaceholderPainter, _PreviewCanvas.

part of 'printing_page.dart';


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
    showDialog(
      context: context,
      builder: (ctx) => _PrintDialog(
        template: t,
        printer: printer,
        initialRecords: records,
        entityType: t.category,
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

// ─────────────────────────────────────────────────────────────────────────────
// Print Dialog — batch select, preview, real ZPL/TCP printing
// ─────────────────────────────────────────────────────────────────────────────
class _PrintDialog extends StatefulWidget {
  final LabelTemplate template;
  final PrinterConfig printer;
  final List<Map<String, dynamic>> initialRecords;
  final String entityType;

  const _PrintDialog({
    required this.template,
    required this.printer,
    this.initialRecords = const [],
    this.entityType = 'General',
  });

  @override
  State<_PrintDialog> createState() => _PrintDialogState();
}

class _PrintDialogState extends State<_PrintDialog> {
  List<Map<String, dynamic>> _records = [];
  late List<bool> _selected;
  int _previewIndex = 0;
  bool _loading = false;
  bool _isPrinting = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _records = List.from(widget.initialRecords);
    _selected = List.filled(_records.length, true);
  }

  List<Map<String, dynamic>> get _selectedRecords =>
      [for (int i = 0; i < _records.length; i++) if (_selected[i]) _records[i]];

  int get _totalLabels => (_selectedRecords.isEmpty ? 1 : _selectedRecords.length) * widget.template.copies;

  Map<String, dynamic> get _previewData {
    if (_records.isEmpty) return _sampleDataFor(widget.entityType);
    return _records[_previewIndex.clamp(0, _records.length - 1)];
  }

  Future<void> _loadFromDb() async {
    setState(() { _loading = true; _status = null; });
    try {
      final rows = await Supabase.instance.client
          .from(_tableForEntity(widget.entityType))
          .select() as List<dynamic>;
      setState(() {
        _records = rows.cast<Map<String, dynamic>>();
        _selected = List.filled(_records.length, true);
        _previewIndex = 0;
        _loading = false;
      });
    } catch (e) {
      setState(() { _loading = false; _status = 'Failed to load: $e'; });
    }
  }

  Future<void> _doPrint() async {
    if (_isPrinting) return;
    final proto = widget.printer.protocol == 'brother_ql' ? 'Brother QL' : 'ZPL';
    setState(() { _isPrinting = true; _status = 'Generating $proto data…'; });
    try {
      final batch = _selectedRecords.isEmpty ? <Map<String, dynamic>>[] : _selectedRecords;
      setState(() => _status = 'Connecting to ${widget.printer.ipAddress}…');
      await _sendToPrinter(widget.template, batch, widget.printer);
      final n = _totalLabels;
      setState(() {
        _isPrinting = false;
        _status = 'Sent $n label${n != 1 ? 's' : ''} to printer ✓';
      });
    } catch (e) {
      setState(() {
        _isPrinting = false;
        _status = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasRecords = _records.isNotEmpty;
    final isError = _status != null && _status!.startsWith('Error');
    final isDone = _status != null && _status!.contains('✓');

    return Dialog(
      backgroundColor: context.appSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 560),
        child: Column(children: [
          // ── Header ──────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
            child: Row(children: [
              const Icon(Icons.print_rounded, size: 18, color: AppDS.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.template.name,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.appTextPrimary)),
                  Text('${widget.template.labelW.toInt()}×${widget.template.labelH.toInt()} mm · ${widget.entityType}',
                      style: TextStyle(fontSize: 11, color: context.appTextSecondary)),
                ]),
              ),
              IconButton(
                icon: Icon(Icons.close, size: 18, color: context.appTextSecondary),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),
          Divider(height: 1, color: context.appBorder),

          // ── Body ────────────────────────────────────────────────────────
          Expanded(
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Left: preview + navigation
              Container(
                width: 220,
                color: const Color(0xFF0A0F1A),
                child: Column(children: [
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 12)],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: _PreviewCanvas(template: widget.template, scale: 3.0, sampleData: _previewData),
                          ),
                          if (!hasRecords) ...[
                            const SizedBox(height: 10),
                            Text('Sample preview', style: TextStyle(fontSize: 10, color: context.appTextSecondary)),
                          ],
                        ]),
                      ),
                    ),
                  ),
                  // Record navigation
                  if (hasRecords)
                    Container(
                      color: context.appSurface,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: Row(children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left_rounded, size: 18),
                          color: context.appTextSecondary,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          onPressed: _previewIndex > 0
                              ? () => setState(() => _previewIndex--)
                              : null,
                        ),
                        Expanded(
                          child: Text(
                            '${_previewIndex + 1} / ${_records.length}',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 11, color: context.appTextSecondary),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right_rounded, size: 18),
                          color: context.appTextSecondary,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          onPressed: _previewIndex < _records.length - 1
                              ? () => setState(() => _previewIndex++)
                              : null,
                        ),
                      ]),
                    ),
                ],
              )),
              VerticalDivider(width: 1, color: context.appBorder),

              // Right: record list or empty state
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: AppDS.accent, strokeWidth: 2))
                    : hasRecords
                        ? _RecordList(
                            records: _records,
                            selected: _selected,
                            previewIndex: _previewIndex,
                            onToggle: (i) => setState(() => _selected[i] = !_selected[i]),
                            onToggleAll: () => setState(() {
                              final allOn = _selected.every((s) => s);
                              for (int i = 0; i < _selected.length; i++) { _selected[i] = !allOn; }
                            }),
                            onTapRow: (i) => setState(() => _previewIndex = i),
                          )
                        : _EmptyRecordsPanel(
                            entityType: widget.entityType,
                            onLoad: _loadFromDb,
                          ),
              ),
            ]),
          ),
          Divider(height: 1, color: context.appBorder),

          // ── Footer ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Row(children: [
              // Status
              Expanded(
                child: _status != null
                    ? Text(_status!,
                        style: TextStyle(
                          fontSize: 11,
                          color: isError ? AppDS.red : isDone ? AppDS.green : context.appTextSecondary,
                        ))
                    : Text(
                        hasRecords
                            ? '${_selectedRecords.length} of ${_records.length} records · $_totalLabels label${_totalLabels != 1 ? 's' : ''}'
                            : '1 label (sample data)',
                        style: TextStyle(fontSize: 11, color: context.appTextSecondary),
                      ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close', style: TextStyle(color: context.appTextSecondary)),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor: AppDS.accent, foregroundColor: AppDS.bg,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                icon: _isPrinting
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: AppDS.bg, strokeWidth: 2))
                    : const Icon(Icons.print_rounded, size: 15),
                label: Text(_isPrinting ? 'Printing…' : 'Print', style: const TextStyle(fontSize: 13)),
                onPressed: _isPrinting ? null : _doPrint,
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _RecordList extends StatelessWidget {
  final List<Map<String, dynamic>> records;
  final List<bool> selected;
  final int previewIndex;
  final void Function(int) onToggle;
  final VoidCallback onToggleAll;
  final void Function(int) onTapRow;

  const _RecordList({
    required this.records, required this.selected,
    required this.previewIndex, required this.onToggle,
    required this.onToggleAll, required this.onTapRow,
  });

  // Pick the most meaningful display field from a record
  String _recordLabel(Map<String, dynamic> r) {
    for (final k in ['strain_code', 'reagent_code', 'eq_code', 'sample_code', 'code', 'name', 'id']) {
      if (r[k] != null) return r[k].toString();
    }
    return r.values.firstOrNull?.toString() ?? '—';
  }

  String _recordSubLabel(Map<String, dynamic> r) {
    for (final k in ['strain_species', 'reagent_name', 'eq_name', 'sample_type', 'name', 'type']) {
      if (r[k] != null) return r[k].toString();
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final allSelected = selected.every((s) => s);
    return Column(children: [
      // Select all row
      InkWell(
        onTap: onToggleAll,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          color: context.appSurface,
          child: Row(children: [
            Icon(allSelected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                size: 17, color: allSelected ? AppDS.accent : context.appTextSecondary),
            const SizedBox(width: 10),
            Text(allSelected ? 'Deselect all' : 'Select all',
                style: TextStyle(fontSize: 12, color: context.appTextSecondary)),
            const Spacer(),
            Text('${selected.where((s) => s).length}/${records.length}',
                style: TextStyle(fontSize: 11, color: context.appTextSecondary)),
          ]),
        ),
      ),
      Divider(height: 1, color: context.appBorder),
      Expanded(
        child: ListView.builder(
          itemCount: records.length,
          itemBuilder: (ctx, i) {
            final isPreview = i == previewIndex;
            return InkWell(
              onTap: () => onTapRow(i),
              child: Container(
                color: isPreview ? AppDS.accent.withValues(alpha: 0.08) : Colors.transparent,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => onToggle(i),
                    child: Icon(
                      selected[i] ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                      size: 16, color: selected[i] ? AppDS.accent : context.appTextSecondary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_recordLabel(records[i]),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                            color: isPreview ? AppDS.accent : ctx.appTextPrimary),
                        overflow: TextOverflow.ellipsis),
                    if (_recordSubLabel(records[i]).isNotEmpty)
                      Text(_recordSubLabel(records[i]),
                          style: TextStyle(fontSize: 10, color: ctx.appTextSecondary),
                          overflow: TextOverflow.ellipsis),
                  ])),
                  if (isPreview)
                    const Icon(Icons.visibility_rounded, size: 13, color: AppDS.accent),
                ]),
              ),
            );
          },
        ),
      ),
    ]);
  }
}

class _EmptyRecordsPanel extends StatelessWidget {
  final String entityType;
  final VoidCallback onLoad;
  const _EmptyRecordsPanel({required this.entityType, required this.onLoad});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.table_rows_outlined, size: 40, color: context.appTextSecondary),
          const SizedBox(height: 14),
          Text('No records loaded', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.appTextPrimary)),
          const SizedBox(height: 6),
          Text('Load $entityType from the database to print with real data,\nor print now using sample placeholder values.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: context.appTextSecondary)),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
                foregroundColor: AppDS.accent, side: const BorderSide(color: AppDS.accent)),
            icon: const Icon(Icons.download_rounded, size: 15),
            label: Text('Load all $entityType', style: const TextStyle(fontSize: 12)),
            onPressed: onLoad,
          ),
        ]),
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
      setState(() => _previewData = _flattenJoins(rows[idx]));
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
      LabelFieldType.text => Align(
        alignment: Alignment.topLeft,
        child: Text(_resolvedContent,
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
      ),
      LabelFieldType.qrcode => Center(
        child: QrImageView(
          data: _resolvedContent.isEmpty ? 'QR' : _resolvedContent,
          version: QrVersions.auto,
          size: field.h * scale * 0.9,
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
