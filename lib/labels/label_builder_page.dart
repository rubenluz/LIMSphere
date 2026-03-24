// label_builder_page.dart - Part of label_page.dart.
// Label template builder UI: drag-to-place fields, paper size selector,
// live preview, ZPL/Brother QL rendering.
part of 'label_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
class _BuilderTab extends StatefulWidget {
  final LabelTemplate? template;
  final Future<void> Function(LabelTemplate) onSave;
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
  final _canvasKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _tpl = widget.template?.clone() ?? LabelTemplate(id: 'new', name: 'New Template');
    _nameCtrl = TextEditingController(text: _tpl.name);
    _loadZoom();
    if (widget.template != null) _togglePreview();
  }

  Future<void> _loadZoom() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _scale = (prefs.getDouble('label_builder_zoom') ?? 4.0).clamp(_minScale, 12.0);
    });
  }

  Future<void> _saveZoom() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('label_builder_zoom', _scale);
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

  void _addField(LabelFieldType type, {String? content, bool isPlaceholder = false, double? atX, double? atY}) {
    final id = 'f${DateTime.now().millisecondsSinceEpoch}';
    final field = LabelField(
      id: id, type: type,
      content: content ?? (type == LabelFieldType.text
          ? 'Text'
          : type == LabelFieldType.qrcode
              ? _qrKeyForCategory(_tpl.category)
              : _fieldsForCategory(_tpl.category).first.key),
      x: atX ?? 4, y: atY ?? 4,
      w: type == LabelFieldType.qrcode ? 24 : type == LabelFieldType.barcode ? 60 : isPlaceholder ? 20 : 40,
      h: type == LabelFieldType.qrcode ? 24 : type == LabelFieldType.barcode ? 16 : isPlaceholder ? 5.5 : 8,
      // QR code content is always a {placeholder} regardless of how it was added
      isPlaceholder: isPlaceholder || type == LabelFieldType.qrcode,
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
      final rows = await Supabase.instance.client
          .from(table).select(_selectForCategory(_tpl.category)).limit(limit);
      final loaded = rows.isNotEmpty
          ? rows.map((r) => _flattenJoins(r)).toList()
          : [_sampleDataFor(_tpl.category)];
      _previewRows = _sortPreviewRows(loaded, _tpl.category);
      _injectQr(_previewRows, _tpl.category);
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
          final na = (a['strain_name'] ?? a['strain_code'] ?? '').toString().toLowerCase();
          final nb = (b['strain_name'] ?? b['strain_code'] ?? '').toString().toLowerCase();
          return na.compareTo(nb);
        });
      case 'Stocks':
        rows.sort((a, b) {
          final ra = (a['fish_stocks_tank_id'] ?? '').toString();
          final rb = (b['fish_stocks_tank_id'] ?? '').toString();
          final re = RegExp(r'(\d+)|(\D+)');
          final ta = re.allMatches(ra).toList();
          final tb = re.allMatches(rb).toList();
          for (var i = 0; i < ta.length && i < tb.length; i++) {
            final sa = ta[i].group(0)!;
            final sb = tb[i].group(0)!;
            final na = int.tryParse(sa);
            final nb = int.tryParse(sb);
            final c = (na != null && nb != null) ? na.compareTo(nb) : sa.compareTo(sb);
            if (c != 0) return c;
          }
          return ra.length.compareTo(rb.length);
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PrintLabelPage(
          template: _tpl.clone(),
          printer: printer,
          entityType: _tpl.category,
        ),
      ),
    );
  }

  void _addHourField() =>
      _addField(LabelFieldType.text, content: '{current_time}', isPlaceholder: true);

  void _addDateField({int plusDays = 0}) {
    final content = plusDays == 0 ? '{current_date}' : '{date+$plusDays}';
    _addField(LabelFieldType.text, content: content, isPlaceholder: true);
  }

  void _showDateOffsetMenu() {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black26,
      builder: (_) => Dialog(
        backgroundColor: AppDS.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ADD DATE FIELD', style: TextStyle(fontSize: 9, letterSpacing: 1.2,
                  color: context.appTextSecondary, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: [
                  for (final d in [0, 1, 2, 3, 7, 14, 30])
                    GestureDetector(
                      onTap: () { Navigator.pop(context); _addDateField(plusDays: d); },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppDS.surface2,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppDS.border),
                        ),
                        child: Text(d == 0 ? 'Today' : '+$d days',
                            style: const TextStyle(fontSize: 11, color: AppDS.textPrimary)),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
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
              onTap: () { setState(() => _scale = (_scale - 0.5).clamp(_minScale, 12.0)); _saveZoom(); },
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
              onTap: () { setState(() => _scale = (_scale + 0.5).clamp(_minScale, 12.0)); _saveZoom(); },
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
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              try {
                await widget.onSave(_tpl.clone());
                if (!mounted) return;
                messenger.showSnackBar(SnackBar(
                  content: const Text('Template saved',
                      style: TextStyle(color: AppDS.bg, fontWeight: FontWeight.w600)),
                  backgroundColor: AppDS.accent,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ));
              } catch (e) {
                if (!mounted) return;
                messenger.showSnackBar(SnackBar(
                  content: Text('Save failed: $e',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  backgroundColor: AppDS.red,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ));
              }
            },
          ),
        ]),
      ),
      Divider(height: 1, color: context.appBorder),

      // ── Print Settings bar ────────────────────────────────────────────────
      Container(
        color: context.appSurface,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(children: [
          Text('DPI', style: TextStyle(fontSize: 9, letterSpacing: 1.1,
              color: context.appTextSecondary, fontWeight: FontWeight.w700)),
          const SizedBox(width: 6),
          ...([300, 600].map((d) {
            final sel = _tpl.dpi == d;
            return GestureDetector(
              onTap: () => setState(() => _tpl.dpi = d),
              child: Container(
                margin: const EdgeInsets.only(right: 4),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: sel ? AppDS.accent.withValues(alpha: 0.15) : context.appBg,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: sel ? AppDS.accent : context.appBorder),
                ),
                child: Text('$d', style: TextStyle(fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: sel ? AppDS.accent : context.appTextPrimary)),
              ),
            );
          })),
          SizedBox(width: 8, child: VerticalDivider(color: context.appBorder)),
          _CompactToggle(Icons.content_cut_rounded,  'Auto Cut',   _tpl.autoCut,       (v) => setState(() => _tpl.autoCut = v)),
          _CompactToggle(Icons.cut_rounded,           'Half Cut',   _tpl.halfCut,       (v) => setState(() => _tpl.halfCut = v)),
          _CompactToggle(Icons.rotate_90_degrees_ccw_rounded, 'Rotate 90°', _tpl.rotate, (v) => setState(() => _tpl.rotate = v)),
          _CompactToggle(Icons.view_stream_rounded,  'Continuous', _tpl.continuousRoll,  (_) => setState(() => _tpl.continuousRoll = true)),
          _CompactToggle(Icons.crop_square_rounded,  'Pre-cut',   !_tpl.continuousRoll,  (_) => setState(() => _tpl.continuousRoll = false)),
          SizedBox(width: 8, child: VerticalDivider(color: context.appBorder)),
          Text('Copies', style: TextStyle(fontSize: 9, letterSpacing: 1.1,
              color: context.appTextSecondary, fontWeight: FontWeight.w700)),
          const SizedBox(width: 6),
          _ToggleBtn('−', false, () { if (_tpl.copies > 1)  setState(() => _tpl.copies--); }),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text('${_tpl.copies}', style: TextStyle(fontSize: 13,
                fontWeight: FontWeight.w700, color: context.appTextPrimary)),
          ),
          _ToggleBtn('+', false, () { if (_tpl.copies < 99) setState(() => _tpl.copies++); }),
        ]),
      ),
      Divider(height: 1, color: context.appBorder),

      Expanded(
        child: Row(children: [
          // Left panel — field palette
          Container(
            width: 210,
            color: context.appSurface,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                child: Text('ADD FIELD', style: TextStyle(fontSize: 9, letterSpacing: 1.2,
                    color: context.appTextSecondary, fontWeight: FontWeight.w700)),
              ),
              _PaletteBtn('Text', Icons.text_fields_rounded,
                  () => _addField(LabelFieldType.text)),
              _PaletteBtn('QR Code', Icons.qr_code_2_rounded,
                  () => _addField(LabelFieldType.qrcode)),
              _PaletteBtn('Hour', Icons.schedule_rounded, _addHourField),
              _PaletteBtn('Date', Icons.today_rounded, _showDateOffsetMenu),
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
                    isMultiSelected: _selectedFieldIds.contains(f.id) && _selectedFieldId != f.id,
                    onTap: () => setState(() {
                      _selectedFieldIds..clear()..add(f.id);
                      _selectedFieldId = f.id;
                    }),
                    onToggleMultiSelect: () => setState(() {
                      if (_selectedFieldIds.contains(f.id)) {
                        _selectedFieldIds.remove(f.id);
                        if (_selectedFieldId == f.id) {
                          _selectedFieldId = _selectedFieldIds.isNotEmpty
                              ? _selectedFieldIds.last : null;
                        }
                      } else {
                        _selectedFieldIds.add(f.id);
                        _selectedFieldId = f.id;
                      }
                    }),
                    onDelete: () => _deleteField(f.id),
                  )).toList(),
                ),
              ),
            ]),
          ),
          VerticalDivider(width: 1, color: context.appBorder),

          // Center — canvas + DB fields panel
          Expanded(
            child: Column(children: [
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
                    return DragTarget<_FieldSpec>(
                      onAcceptWithDetails: (details) {
                        final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
                        if (box == null) return;
                        final local = box.globalToLocal(details.offset);
                        final x = (local.dx / _scale).clamp(0.0, _tpl.labelW - 5.0);
                        final y = (local.dy / _scale).clamp(0.0, _tpl.labelH - 3.0);
                        _addField(details.data.type,
                            content: details.data.key,
                            isPlaceholder: details.data.isPlaceholder,
                            atX: x, atY: y);
                      },
                      builder: (context, candidateData, _) => Listener(
                        onPointerSignal: (event) {
                          if (event is PointerScrollEvent && HardwareKeyboard.instance.isControlPressed) {
                            setState(() => _scale = (_scale - event.scrollDelta.dy * 0.008).clamp(_minScale, 12.0)); _saveZoom();
                          }
                        },
                        child: Container(
                          color: candidateData.isNotEmpty
                              ? AppDS.accent.withValues(alpha: 0.06)
                              : const Color(0xFF0A0F1A),
                          child: Center(
                            child: SingleChildScrollView(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: KeyedSubtree(
                                  key: _canvasKey,
                                  child: _BuilderCanvas(
                                    template: _tpl,
                                    scale: _scale,
                                    selectedId: _selectedFieldId,
                                    selectedIds: _selectedFieldIds,
                                    data: _livePreview ? _liveData : null,
                                    onSelect: (id) {
                                      setState(() {
                                        if (HardwareKeyboard.instance.isControlPressed) {
                                          if (_selectedFieldIds.contains(id)) {
                                            _selectedFieldIds.remove(id);
                                            if (_selectedFieldId == id) {
                                              _selectedFieldId = _selectedFieldIds.isNotEmpty
                                                  ? _selectedFieldIds.last : null;
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
                                      if (f != null) {
                                        var newW = (f.w + dw / _scale).clamp(10.0, _tpl.labelW);
                                        var newH = (f.h + dh / _scale).clamp(5.0, _tpl.labelH);
                                        if (f.type == LabelFieldType.qrcode) {
                                          final s = math.max(newW, newH).clamp(10.0, math.min(_tpl.labelW, _tpl.labelH)) as double;
                                          newW = s; newH = s;
                                        }
                                        _updateField(f.copyWith(w: newW, h: newH));
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              _DbFieldsPanel(
                category: _tpl.category,
                selectedContent: _selectedField?.content,
              ),
            ]),
          ),
          // Right panel — alignment (multi-select) + field properties
          if (_selectedFieldIds.length > 1 || _selectedField != null) ...[
            VerticalDivider(width: 1, color: context.appBorder),
            Container(
              width: 240,
              color: context.appSurface,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_selectedFieldIds.length > 1) ...[
                      Text('ALIGN ${_selectedFieldIds.length} FIELDS',
                          style: TextStyle(fontSize: 9, letterSpacing: 1.2,
                              color: context.appTextSecondary, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Wrap(spacing: 4, runSpacing: 4, children: [
                        _AlignBtn(Icons.align_horizontal_left_rounded,   'Left edges',    () => _alignFields('left')),
                        _AlignBtn(Icons.align_horizontal_center_rounded, 'Center horiz.', () => _alignFields('centerH')),
                        _AlignBtn(Icons.align_horizontal_right_rounded,  'Right edges',   () => _alignFields('right')),
                        _AlignBtn(Icons.align_vertical_top_rounded,      'Top edges',     () => _alignFields('top')),
                        _AlignBtn(Icons.align_vertical_center_rounded,   'Center vert.',  () => _alignFields('centerV')),
                        _AlignBtn(Icons.align_vertical_bottom_rounded,   'Bottom edges',  () => _alignFields('bottom')),
                      ]),
                    ],
                    if (_selectedField != null) ...[
                      if (_selectedFieldIds.length > 1) ...[
                        const SizedBox(height: 14),
                        Divider(color: context.appBorder),
                        const SizedBox(height: 6),
                      ],
                      _FieldProperties(
                        field: _selectedField!,
                        onChange: _updateField,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ]),
      ),
    ]);
  }

}

