part of 'printing_page.dart';


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
  final _selectedFieldIds = <String>{};
  double _scale = 4.0;
  double _minScale = 1.0;
  bool _livePreview = false;
  Map<String, dynamic>? _liveData;
  List<Map<String, dynamic>> _previewRows = [];
  int _previewRowIndex = 0;
  bool _loadingPreview = false;
  late TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    _tpl = widget.template?.clone() ?? LabelTemplate(id: 'new', name: 'New Template');
    _nameCtrl = TextEditingController(text: _tpl.name);
    if (widget.template != null) _togglePreview();
  }

  @override
  void didUpdateWidget(_BuilderTab old) {
    super.didUpdateWidget(old);
    if (widget.template?.id != old.template?.id) {
      setState(() {
        _tpl = widget.template?.clone() ?? LabelTemplate(id: 'new', name: 'New Template');
        _selectedFieldId = null;
      });
      _nameCtrl.text = _tpl.name;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  LabelField? get _selectedField =>
      _tpl.fields.firstWhereOrNull((f) => f.id == _selectedFieldId);

  void _addField(LabelFieldType type, {String? content, bool isPlaceholder = false}) {
    final id = 'f${DateTime.now().millisecondsSinceEpoch}';
    final field = LabelField(
      id: id, type: type,
      content: content ?? (type == LabelFieldType.text
          ? 'Text'
          : type == LabelFieldType.qrcode
              ? _qrKeyForCategory(_tpl.category)
              : _fieldsForCategory(_tpl.category).first.key),
      x: 4, y: 4,
      w: type == LabelFieldType.qrcode ? 24 : type == LabelFieldType.barcode ? 60 : 40,
      h: type == LabelFieldType.qrcode ? 24 : type == LabelFieldType.barcode ? 16 : 6,
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
      _selectedFieldIds.remove(id);
    });
  }

  void _alignFields(String axis) {
    final fields = _tpl.fields.where((f) => _selectedFieldIds.contains(f.id)).toList();
    if (fields.length < 2) return;
    setState(() {
      switch (axis) {
        case 'left':
          final minX = fields.map((f) => f.x).reduce((a, b) => a < b ? a : b);
          for (var i = 0; i < _tpl.fields.length; i++) {
            if (_selectedFieldIds.contains(_tpl.fields[i].id)) {
              _tpl.fields[i] = _tpl.fields[i].copyWith(x: minX);
            }
          }
        case 'right':
          final maxR = fields.map((f) => f.x + f.w).reduce((a, b) => a > b ? a : b);
          for (var i = 0; i < _tpl.fields.length; i++) {
            if (_selectedFieldIds.contains(_tpl.fields[i].id)) {
              _tpl.fields[i] = _tpl.fields[i].copyWith(x: maxR - _tpl.fields[i].w);
            }
          }
        case 'centerH':
          final minX = fields.map((f) => f.x).reduce((a, b) => a < b ? a : b);
          final maxR = fields.map((f) => f.x + f.w).reduce((a, b) => a > b ? a : b);
          final cx = (minX + maxR) / 2;
          for (var i = 0; i < _tpl.fields.length; i++) {
            if (_selectedFieldIds.contains(_tpl.fields[i].id)) {
              _tpl.fields[i] = _tpl.fields[i].copyWith(x: cx - _tpl.fields[i].w / 2);
            }
          }
        case 'top':
          final minY = fields.map((f) => f.y).reduce((a, b) => a < b ? a : b);
          for (var i = 0; i < _tpl.fields.length; i++) {
            if (_selectedFieldIds.contains(_tpl.fields[i].id)) {
              _tpl.fields[i] = _tpl.fields[i].copyWith(y: minY);
            }
          }
        case 'bottom':
          final maxB = fields.map((f) => f.y + f.h).reduce((a, b) => a > b ? a : b);
          for (var i = 0; i < _tpl.fields.length; i++) {
            if (_selectedFieldIds.contains(_tpl.fields[i].id)) {
              _tpl.fields[i] = _tpl.fields[i].copyWith(y: maxB - _tpl.fields[i].h);
            }
          }
        case 'centerV':
          final minY = fields.map((f) => f.y).reduce((a, b) => a < b ? a : b);
          final maxB = fields.map((f) => f.y + f.h).reduce((a, b) => a > b ? a : b);
          final cy = (minY + maxB) / 2;
          for (var i = 0; i < _tpl.fields.length; i++) {
            if (_selectedFieldIds.contains(_tpl.fields[i].id)) {
              _tpl.fields[i] = _tpl.fields[i].copyWith(y: cy - _tpl.fields[i].h / 2);
            }
          }
      }
    });
  }

  void _updateField(LabelField updated) {
    setState(() {
      final i = _tpl.fields.indexWhere((f) => f.id == updated.id);
      if (i >= 0) _tpl.fields[i] = updated;
    });
  }

  Future<void> _togglePreview() async {
    if (_livePreview) {
      setState(() { _livePreview = false; _liveData = null; });
      return;
    }
    setState(() => _loadingPreview = true);
    try {
      final table = _tableForEntity(_tpl.category);
      // Strains can exceed 800 rows — load all; others cap at 500
      final limit = _tpl.category == 'Strains' ? 10000 : 500;
      final rows = await Supabase.instance.client.from(table).select().limit(limit);
      final loaded = rows.isNotEmpty
          ? rows.map((r) => Map<String, dynamic>.from(r)).toList()
          : [_sampleDataFor(_tpl.category)];
      _previewRows = _sortPreviewRows(loaded, _tpl.category);
    } catch (_) {
      _previewRows = [_sampleDataFor(_tpl.category)];
    }
    _previewRowIndex = 0;
    _liveData = _previewRows[0];
    if (mounted) setState(() { _livePreview = true; _loadingPreview = false; });
  }

  List<Map<String, dynamic>> _sortPreviewRows(
      List<Map<String, dynamic>> rows, String category) {
    switch (category) {
      case 'Strains':
        rows.sort((a, b) {
          final na = (a['strain_code'] ?? '').toString().toLowerCase();
          final nb = (b['strain_code'] ?? '').toString().toLowerCase();
          return na.compareTo(nb);
        });
      case 'Stocks':
        rows.sort((a, b) {
          final ra = (a['fish_stocks_rack'] ?? '').toString();
          final rb = (b['fish_stocks_rack'] ?? '').toString();
          final rc = ra.compareTo(rb);
          if (rc != 0) return rc;
          // Numeric position sort: 1, 2, … 10 (not lexicographic)
          final pa = int.tryParse(a['fish_stocks_position']?.toString() ?? '') ?? 0;
          final pb = int.tryParse(b['fish_stocks_position']?.toString() ?? '') ?? 0;
          return pa.compareTo(pb);
        });
      case 'Samples':
        rows.sort((a, b) =>
            (a['sample_code'] ?? '').toString()
                .compareTo((b['sample_code'] ?? '').toString()));
      case 'Reagents':
        rows.sort((a, b) =>
            (a['reagent_name'] ?? '').toString().toLowerCase()
                .compareTo((b['reagent_name'] ?? '').toString().toLowerCase()));
      case 'Equipment':
        rows.sort((a, b) =>
            (a['eq_name'] ?? '').toString().toLowerCase()
                .compareTo((b['eq_name'] ?? '').toString().toLowerCase()));
      default:
        rows.sort((a, b) =>
            (a['name'] ?? a['code'] ?? '').toString()
                .compareTo((b['name'] ?? b['code'] ?? '').toString()));
    }
    return rows;
  }

  void _setPreviewRow(int index) {
    if (index < 0 || index >= _previewRows.length) return;
    setState(() {
      _previewRowIndex = index;
      _liveData = _previewRows[index];
    });
  }

  Future<void> _printFromPreview() async {
    final prefs = await SharedPreferences.getInstance();
    final printer = PrinterConfig()
      ..protocol = prefs.getString('printer_protocol') ?? 'zpl'
      ..connectionType = prefs.getString('printer_connectionType') ?? 'usb'
      ..deviceName = prefs.getString('printer_deviceName') ?? ''
      ..ipAddress = prefs.getString('printer_ipAddress') ?? ''
      ..usbPath = prefs.getString('printer_usbPath') ?? '';
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => _PrintDialog(
        template: _tpl.clone(),
        printer: printer,
        entityType: _tpl.category,
      ),
    );
  }

  void _showDbFieldPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppDS.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      constraints: const BoxConstraints(maxHeight: 520),
      builder: (ctx) => _DbFieldPicker(
        category: _tpl.category,
        onSelect: (key) {
          Navigator.pop(ctx);
          _addField(LabelFieldType.text, content: key, isPlaceholder: true);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.template == null) {
      return Center(child: Text('No template selected.\nGo to Templates and select or create one.',
          textAlign: TextAlign.center, style: TextStyle(color: context.appTextSecondary)));
    }
    return Column(children: [
      // Top bar
      Container(
        color: context.appSurface,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Row(children: [
          IconButton(
            icon: Icon(Icons.arrow_back_rounded, size: 18, color: context.appTextSecondary),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            tooltip: 'Back',
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: TextField(
              controller: _nameCtrl,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.appTextPrimary),
              decoration: InputDecoration(
                isDense: true, border: InputBorder.none,
                hintText: 'Template name…',
                hintStyle: TextStyle(color: context.appTextSecondary),
              ),
              onChanged: (v) => _tpl.name = v,
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _kPaperSizes.contains(_tpl.paperSize) ? _tpl.paperSize : _kPaperSizes.first,
              isDense: true,
              dropdownColor: AppDS.surface,
              icon: Icon(Icons.expand_more_rounded, size: 14, color: context.appTextSecondary),
              // selectedItemBuilder forces the selected text to render with our colour
              selectedItemBuilder: (context) => _kPaperSizes.map((s) {
                final p = s.split('x');
                return Align(
                  alignment: Alignment.centerLeft,
                  child: Text('${p[0]}×${p[1]} mm',
                      style: TextStyle(fontSize: 11, color: context.appTextSecondary)),
                );
              }).toList(),
              items: _kPaperSizes.map((s) {
                final p = s.split('x');
                return DropdownMenuItem(
                  value: s,
                  child: Text('${p[0]}×${p[1]} mm',
                      style: const TextStyle(fontSize: 11, color: AppDS.textPrimary)),
                );
              }).toList(),
              onChanged: (s) {
                if (s == null) return;
                final parts = s.split('x');
                setState(() {
                  _tpl.paperSize = s;
                  _tpl.labelW = double.tryParse(parts[0]) ?? _tpl.labelW;
                  _tpl.labelH = double.tryParse(parts[1]) ?? _tpl.labelH;
                });
              },
            ),
          ),
          const SizedBox(width: 12),
          // Zoom controls
          Row(mainAxisSize: MainAxisSize.min, children: [
            InkWell(
              onTap: () => setState(() => _scale = (_scale - 0.5).clamp(_minScale, 8.0)),
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.remove_rounded, size: 14, color: context.appTextSecondary),
              ),
            ),
            SizedBox(
              width: 38,
              child: Text(
                '${(_scale / 4.0 * 100).round()}%',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: context.appTextSecondary),
              ),
            ),
            InkWell(
              onTap: () => setState(() => _scale = (_scale + 0.5).clamp(_minScale, 8.0)),
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.add_rounded, size: 14, color: context.appTextSecondary),
              ),
            ),
          ]),
          const SizedBox(width: 12),
          Tooltip(
            message: _livePreview ? 'Show placeholders' : 'Preview with live data',
            child: GestureDetector(
              onTap: _loadingPreview ? null : _togglePreview,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _livePreview ? AppDS.accent.withValues(alpha: 0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _livePreview ? AppDS.accent : context.appBorder),
                ),
                child: _loadingPreview
                    ? const SizedBox(width: 12, height: 12,
                        child: CircularProgressIndicator(strokeWidth: 1.5, color: AppDS.accent))
                    : Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(_livePreview ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                            size: 13, color: _livePreview ? AppDS.accent : context.appTextSecondary),
                        const SizedBox(width: 5),
                        Text('Preview', style: TextStyle(fontSize: 11,
                            color: _livePreview ? AppDS.accent : context.appTextSecondary)),
                      ]),
              ),
            ),
          ),
          // Row selector — spinner populated with row labels, visible when preview is on
          if (_livePreview && _previewRows.isNotEmpty) ...[
            const SizedBox(width: 6),
            SizedBox(
              width: 130,
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _previewRowIndex,
                  isDense: true,
                  isExpanded: true,
                  dropdownColor: AppDS.surface,
                  icon: Icon(Icons.expand_more_rounded, size: 14, color: context.appTextSecondary),
                  selectedItemBuilder: (context) => List.generate(_previewRows.length, (i) =>
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _rowLabelFor(_previewRows[i], _tpl.category, i),
                        style: TextStyle(fontSize: 11, color: context.appTextSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  items: List.generate(_previewRows.length, (i) => DropdownMenuItem(
                    value: i,
                    child: Text(
                      _rowLabelFor(_previewRows[i], _tpl.category, i),
                      style: const TextStyle(fontSize: 11, color: AppDS.textPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  )),
                  onChanged: (i) { if (i != null) _setPreviewRow(i); },
                ),
              ),
            ),
          ],
          const SizedBox(width: 6),
          // Print icon
          Tooltip(
            message: 'Print preview',
            child: InkWell(
              onTap: _printFromPreview,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Icon(Icons.print_rounded, size: 16, color: context.appTextSecondary),
              ),
            ),
          ),
          const SizedBox(width: 4),
          FilledButton.icon(
            style: FilledButton.styleFrom(
                backgroundColor: AppDS.accent, foregroundColor: AppDS.bg,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
            icon: const Icon(Icons.save_rounded, size: 15),
            label: const Text('Save', style: TextStyle(fontSize: 12)),
            onPressed: () {
              widget.onSave(_tpl.clone());
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: const Text('Template saved',
                    style: TextStyle(color: AppDS.bg, fontWeight: FontWeight.w600)),
                backgroundColor: AppDS.accent,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ));
            },
          ),
        ]),
      ),
      Divider(height: 1, color: context.appBorder),

      Expanded(
        child: Row(children: [
          // Left panel — field palette
          Container(
            width: 160,
            color: context.appSurface,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                child: Text('ADD FIELD', style: TextStyle(fontSize: 9, letterSpacing: 1.2,
                    color: context.appTextSecondary, fontWeight: FontWeight.w700)),
              ),
              _PaletteBtn('Text', Icons.text_fields_rounded,
                  () => _addField(LabelFieldType.text)),
              _PaletteBtn('DB Field', Icons.data_object_rounded, _showDbFieldPicker),
              _PaletteBtn('QR Code', Icons.qr_code_2_rounded,
                  () => _addField(LabelFieldType.qrcode, isPlaceholder: true)),
              _PaletteBtn('Divider', Icons.horizontal_rule_rounded,
                  () => _addField(LabelFieldType.divider)),
              Divider(color: context.appBorder, height: 20),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                child: Text('FIELDS', style: TextStyle(fontSize: 9, letterSpacing: 1.2,
                    color: context.appTextSecondary, fontWeight: FontWeight.w700)),
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
          VerticalDivider(width: 1, color: context.appBorder),

          // Center — canvas
          Expanded(
            child: LayoutBuilder(
              builder: (_, constraints) {
                final fitW = (constraints.maxWidth - 48) / _tpl.labelW;
                final fitH = (constraints.maxHeight - 48) / _tpl.labelH;
                final newMin = (fitW < fitH ? fitW : fitH).clamp(0.5, 4.0);
                if ((newMin - _minScale).abs() > 0.01) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _minScale = newMin);
                  });
                }
                return Listener(
              onPointerSignal: (event) {
                if (event is PointerScrollEvent && HardwareKeyboard.instance.isControlPressed) {
                  setState(() => _scale = (_scale - event.scrollDelta.dy * 0.008).clamp(_minScale, 8.0));
                }
              },
              child: Container(
                color: const Color(0xFF0A0F1A),
                child: Center(
                  child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: _BuilderCanvas(
                      template: _tpl,
                      scale: _scale,
                      selectedId: _livePreview ? null : _selectedFieldId,
                      selectedIds: _livePreview ? const {} : _selectedFieldIds,
                      data: _livePreview ? _liveData : null,
                      onSelect: (id) {
                        if (_livePreview) return;
                        setState(() {
                          if (HardwareKeyboard.instance.isControlPressed) {
                            if (_selectedFieldIds.contains(id)) {
                              _selectedFieldIds.remove(id);
                              if (_selectedFieldId == id) {
                                _selectedFieldId = _selectedFieldIds.isNotEmpty ? _selectedFieldIds.last : null;
                              }
                            } else {
                              _selectedFieldIds.add(id);
                              _selectedFieldId = id;
                            }
                          } else {
                            _selectedFieldIds..clear()..add(id);
                            _selectedFieldId = id;
                          }
                        });
                      },
                      onMove: (id, dx, dy) {
                        final f = _tpl.fields.firstWhereOrNull((f) => f.id == id);
                        if (f != null) { _updateField(f.copyWith(
                            x: (f.x + dx / _scale).clamp(0, _tpl.labelW - 5),
                            y: (f.y + dy / _scale).clamp(0, _tpl.labelH - 3))); }
                      },
                      onResize: (id, dw, dh) {
                        final f = _tpl.fields.firstWhereOrNull((f) => f.id == id);
                        if (f != null) { _updateField(f.copyWith(
                            w: (f.w + dw / _scale).clamp(10, _tpl.labelW),
                            h: (f.h + dh / _scale).clamp(5, _tpl.labelH))); }
                      },
                    ),
                  ),
                ),
              ),
            ),
            );          // closes return Listener(...)
          },            // closes LayoutBuilder builder
          ),            // closes LayoutBuilder
          ),            // closes Expanded
          VerticalDivider(width: 1, color: context.appBorder),

          // Right panel — print settings + optional field properties
          Container(
            width: 220,
            color: context.appSurface,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Print Settings ───────────────────────────────────
                  Text('PRINT SETTINGS', style: TextStyle(fontSize: 9, letterSpacing: 1.2,
                      color: context.appTextSecondary, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  _PropLabel('DPI'),
                  const SizedBox(height: 6),
                  Row(children: [300, 600].map((d) {
                    final sel = _tpl.dpi == d;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: GestureDetector(
                        onTap: () => setState(() => _tpl.dpi = d),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: sel ? AppDS.accent.withValues(alpha: 0.15) : context.appBg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: sel ? AppDS.accent : context.appBorder, width: sel ? 1.5 : 1),
                          ),
                          child: Text('$d', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                              color: sel ? AppDS.accent : context.appTextPrimary)),
                        ),
                      ),
                    );
                  }).toList()),
                  const SizedBox(height: 10),
                  _PropLabel('Options'),
                  const SizedBox(height: 4),
                  _SwitchRow('Auto Cut', 'Cut after printing', Icons.content_cut_rounded,
                      _tpl.autoCut, (v) => setState(() => _tpl.autoCut = v)),
                  const SizedBox(height: 4),
                  _SwitchRow('Half Cut', 'Leave backing intact', Icons.cut_rounded,
                      _tpl.halfCut, (v) => setState(() => _tpl.halfCut = v)),
                  const SizedBox(height: 4),
                  _SwitchRow('Rotate 90°', 'Rotate before printing', Icons.rotate_90_degrees_ccw_rounded,
                      _tpl.rotate, (v) => setState(() => _tpl.rotate = v)),
                  const SizedBox(height: 4),
                  _SwitchRow('Continuous Roll', 'Roll tape (not die-cut sheets)', Icons.view_stream_rounded,
                      _tpl.continuousRoll, (v) => setState(() => _tpl.continuousRoll = v)),
                  const SizedBox(height: 10),
                  _PropLabel('Copies'),
                  const SizedBox(height: 6),
                  Row(children: [
                    _ToggleBtn('−', false,
                        () { if (_tpl.copies > 1) setState(() => _tpl.copies--); }),
                    const SizedBox(width: 10),
                    Text('${_tpl.copies}', style: TextStyle(fontSize: 15,
                        fontWeight: FontWeight.w700, color: context.appTextPrimary)),
                    const SizedBox(width: 10),
                    _ToggleBtn('+', false,
                        () { if (_tpl.copies < 99) setState(() => _tpl.copies++); }),
                  ]),

                  // ── Multi-select Alignment ────────────────────────────
                  if (_selectedFieldIds.length > 1) ...[
                    const SizedBox(height: 14),
                    Divider(color: context.appBorder),
                    const SizedBox(height: 6),
                    Text('ALIGN ${_selectedFieldIds.length} FIELDS',
                        style: TextStyle(fontSize: 9, letterSpacing: 1.2,
                            color: context.appTextSecondary, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 4, runSpacing: 4, children: [
                      _AlignBtn(Icons.align_horizontal_left_rounded,   'Left edges',       () => _alignFields('left')),
                      _AlignBtn(Icons.align_horizontal_center_rounded, 'Center horiz.',    () => _alignFields('centerH')),
                      _AlignBtn(Icons.align_horizontal_right_rounded,  'Right edges',      () => _alignFields('right')),
                      _AlignBtn(Icons.align_vertical_top_rounded,      'Top edges',        () => _alignFields('top')),
                      _AlignBtn(Icons.align_vertical_center_rounded,   'Center vert.',     () => _alignFields('centerV')),
                      _AlignBtn(Icons.align_vertical_bottom_rounded,   'Bottom edges',     () => _alignFields('bottom')),
                    ]),
                  ],

                  // ── Field Properties ─────────────────────────────────
                  if (_selectedField != null) ...[
                    const SizedBox(height: 14),
                    Divider(color: context.appBorder),
                    const SizedBox(height: 6),
                    _FieldProperties(
                      field: _selectedField!,
                      onChange: _updateField,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ]),
      ),
    ]);
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
          Text(label, style: TextStyle(fontSize: 12, color: context.appTextPrimary)),
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
    LabelFieldType.text    => Icons.text_fields_rounded,
    LabelFieldType.qrcode  => Icons.qr_code_2_rounded,
    LabelFieldType.barcode => Icons.barcode_reader,
    LabelFieldType.divider => Icons.horizontal_rule_rounded,
    LabelFieldType.image   => Icons.image_outlined,
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
          Icon(_typeIcon, size: 13, color: isSelected ? AppDS.accent : context.appTextSecondary),
          const SizedBox(width: 6),
          Expanded(child: Text(
            field.content.length > 16 ? '${field.content.substring(0, 16)}…' : field.content,
            style: TextStyle(fontSize: 11, color: isSelected ? AppDS.accent : context.appTextPrimary),
            overflow: TextOverflow.ellipsis,
          )),
          InkWell(
            onTap: onDelete,
            child: Icon(Icons.close, size: 12, color: context.appTextSecondary),
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
  final Set<String> selectedIds;
  final void Function(String id) onSelect;
  final void Function(String id, double dx, double dy) onMove;
  final void Function(String id, double dw, double dh) onResize;
  final Map<String, dynamic>? data;

  const _BuilderCanvas({
    required this.template, required this.scale,
    required this.selectedId, required this.selectedIds,
    required this.onSelect,
    required this.onMove, required this.onResize,
    this.data,
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
          CustomPaint(painter: _GridPainter(scale: scale), size: Size(cw, ch)),
          ...template.fields.map((f) {
            final isSelected = selectedId == f.id;
            final isMultiSelected = !isSelected && selectedIds.contains(f.id);
            return Positioned(
              left: f.x * scale, top: f.y * scale,
              child: GestureDetector(
                onTap: () => onSelect(f.id),
                onPanUpdate: (d) => onMove(f.id, d.delta.dx, d.delta.dy),
                child: Stack(clipBehavior: Clip.none, children: [
                  Container(
                    width: f.w * scale, height: f.h * scale,
                    decoration: isSelected
                        ? BoxDecoration(border: Border.all(color: AppDS.accent, width: 1.5))
                        : isMultiSelected
                            ? BoxDecoration(border: Border.all(
                                color: AppDS.accent.withValues(alpha: 0.5), width: 1.0,
                                style: BorderStyle.solid))
                            : null,
                    child: _FieldRenderer(field: f, scale: scale, data: data),
                  ),
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
                value: field.fontSize.clamp(6, 24),
                min: 6, max: 24,
                divisions: 18,
                activeColor: AppDS.accent,
                onChanged: (v) => onChange(field.copyWith(fontSize: v)),
              ),
            ),
            Text('${field.fontSize.toInt()}', style: TextStyle(fontSize: 11, color: context.appTextSecondary)),
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
    child: Text(text, style: TextStyle(fontSize: 10, color: context.appTextSecondary, fontWeight: FontWeight.w600)),
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
    style: TextStyle(fontSize: 12, color: context.appTextPrimary),
    decoration: InputDecoration(
      isDense: true, filled: true, fillColor: context.appBg,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: context.appBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: context.appBorder)),
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
    style: TextStyle(fontSize: 11, color: context.appTextPrimary),
    keyboardType: TextInputType.number,
    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
    decoration: InputDecoration(
      labelText: label,
      labelStyle: TextStyle(fontSize: 10, color: context.appTextSecondary),
      isDense: true, filled: true, fillColor: context.appBg,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: context.appBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: context.appBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppDS.accent)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
    ),
    onChanged: (v) { final d = double.tryParse(v); if (d != null) onChanged(d); },
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
      color: context.appSurface,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: context.appBorder),
    ),
    child: Row(children: [
      Icon(icon, size: 16, color: value ? AppDS.accent : context.appTextSecondary),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: value ? context.appTextPrimary : context.appTextSecondary)),
        Text(subtitle, style: TextStyle(fontSize: 10, color: context.appTextSecondary)),
      ])),
      Switch(value: value, onChanged: onChanged, activeThumbColor: AppDS.accent),
    ]),
  );
}
