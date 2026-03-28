// item_register_page.dart - Camera-OCR reagent registration.
// Mobile: capture image → OCR → parse brand/reference → DB lookup.
// Desktop: manual brand + reference entry → DB lookup.
// Found → update quantity dialog. Not found → create reagent dialog.

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide LocalStorage;
import '/theme/theme.dart';
import '/resources/reagents/reagent_model.dart';

enum _Step { idle, processing, results }

class ItemRegisterPage extends StatefulWidget {
  const ItemRegisterPage({super.key});

  @override
  State<ItemRegisterPage> createState() => _ItemRegisterPageState();
}

class _ItemRegisterPageState extends State<ItemRegisterPage> {
  _Step _step = _Step.idle;
  bool get _isMobile =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  // Mobile OCR state
  Uint8List? _imageBytes;

  // Parsed / editable fields
  final _brandCtrl = TextEditingController();
  final _refCtrl = TextEditingController();

  // Results
  List<ReagentModel> _matches = [];
  bool _searched = false;

  @override
  void dispose() {
    _brandCtrl.dispose();
    _refCtrl.dispose();
    super.dispose();
  }

  // ── OCR capture (mobile only) ───────────────────────────────────────────────
  Future<void> _captureAndProcess() async {
    final img = await ImagePicker()
        .pickImage(source: ImageSource.camera, imageQuality: 85);
    if (img == null || !mounted) return;

    setState(() {
      _step = _Step.processing;
      _imageBytes = null;
    });

    try {
      _imageBytes = await img.readAsBytes();
      final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final result =
          await recognizer.processImage(InputImage.fromFilePath(img.path));
      recognizer.close();
      _parseText(result.text);
    } catch (_) {}

    await _doSearch();
  }

  // ── Parse OCR text for brand + catalog number ───────────────────────────────
  static const _knownBrands = [
    'Sigma-Aldrich', 'Sigma', 'Merck', 'Abcam',
    'Thermo Fisher', 'Thermo', 'Fisher Scientific', 'Fisher',
    'Invitrogen', 'Gibco', 'Bio-Rad', 'Qiagen',
    'Roche', 'Promega', 'New England Biolabs', 'NEB',
    'Eppendorf', 'Cayman Chemical', 'Santa Cruz Biotechnology',
    'Cell Signaling', 'BD Biosciences', 'Miltenyi Biotec',
    'R&D Systems', 'VWR', 'AppliChem', 'TCI', 'Fluka',
  ];

  void _parseText(String text) {
    final upper = text.toUpperCase();
    for (final b in _knownBrands) {
      if (upper.contains(b.toUpperCase())) {
        _brandCtrl.text = b;
        break;
      }
    }

    // Catalog number patterns (in priority order)
    final patterns = [
      RegExp(r'\b[A-Z]{1,3}\d{3,7}\b'),                        // T1503, AB12345
      RegExp(r'\b[A-Z]{2,4}-\d{4,7}\b'),                       // SC-12345
      RegExp(r'\bab\d{4,8}\b', caseSensitive: false),           // ab123456 (Abcam)
      RegExp(r'\b\d{6,8}\b'),                                    // 1234567 (Merck)
    ];
    for (final p in patterns) {
      final m = p.firstMatch(text);
      if (m != null) {
        _refCtrl.text = m.group(0)!;
        break;
      }
    }
  }

  // ── DB lookup ───────────────────────────────────────────────────────────────
  Future<void> _doSearch() async {
    setState(() {
      _step = _Step.processing;
      _searched = false;
      _matches = [];
    });

    final brand = _brandCtrl.text.trim();
    final ref = _refCtrl.text.trim();

    if (brand.isNotEmpty || ref.isNotEmpty) {
      try {
        final List rows;
        if (ref.isNotEmpty) {
          rows = await Supabase.instance.client
              .from('reagents')
              .select('*, location:reagent_location_id(location_name)')
              .ilike('reagent_reference', '%$ref%')
              .limit(5);
        } else {
          rows = await Supabase.instance.client
              .from('reagents')
              .select('*, location:reagent_location_id(location_name)')
              .ilike('reagent_brand', '%$brand%')
              .limit(5);
        }
        if (!mounted) return;
        _matches = rows.map<ReagentModel>((r) {
          final loc = (r as Map)['location'];
          final locName =
              loc is Map ? loc['location_name'] as String? : null;
          return ReagentModel.fromMap(
              {...Map<String, dynamic>.from(r), 'location_name': locName});
        }).toList();
      } catch (_) {}
    }

    if (mounted) setState(() { _step = _Step.results; _searched = true; });
  }

  // ── Update quantity dialog ──────────────────────────────────────────────────
  Future<void> _showUpdateQuantity(ReagentModel r) async {
    final ctrl =
        TextEditingController(text: r.quantity?.toString() ?? '');
    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: context.appSurface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text('Update Quantity',
              style: GoogleFonts.spaceGrotesk(
                  color: context.appTextPrimary,
                  fontWeight: FontWeight.w600)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(r.name,
                style: GoogleFonts.spaceGrotesk(
                    color: context.appTextSecondary, fontSize: 14)),
            if (r.brand != null)
              Text(r.brand!,
                  style: GoogleFonts.spaceGrotesk(
                      color: context.appTextMuted, fontSize: 12)),
            const SizedBox(height: 16),
            _field(ctx, ctrl,
                r.unit != null ? 'Quantity (${r.unit})' : 'Quantity',
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                autofocus: true),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style: GoogleFonts.spaceGrotesk(
                      color: context.appTextSecondary)),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('Save', style: GoogleFonts.spaceGrotesk()),
            ),
          ],
        ),
      );

      if (saved != true || !mounted) return;
      final newQty = double.tryParse(ctrl.text.trim());
      if (newQty == null) return;

      await Supabase.instance.client
          .from('reagents')
          .update({
            'reagent_quantity': newQty,
            'reagent_updated_at':
                DateTime.now().toUtc().toIso8601String(),
          })
          .eq('reagent_id', r.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Quantity updated',
            style: GoogleFonts.spaceGrotesk(color: Colors.white)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppDS.green,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: $e',
              style: GoogleFonts.spaceGrotesk(color: Colors.white)),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppDS.red,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ));
      }
    } finally {
      ctrl.dispose();
    }
  }

  // ── Create reagent dialog ───────────────────────────────────────────────────
  Future<void> _showCreateReagent() async {
    final nameCtrl = TextEditingController();
    final lotCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    final unitCtrl = TextEditingController();
    String type = 'chemical';

    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setS) => AlertDialog(
            backgroundColor: context.appSurface,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            title: Text('Register New Reagent',
                style: GoogleFonts.spaceGrotesk(
                    color: context.appTextPrimary,
                    fontWeight: FontWeight.w600)),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _field(ctx, nameCtrl, 'Name *', autofocus: true),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(
                            child: _field(ctx, _brandCtrl, 'Brand')),
                        const SizedBox(width: 10),
                        Expanded(
                            child: _field(
                                ctx, _refCtrl, 'Reference / Cat #')),
                      ]),
                      const SizedBox(height: 10),
                      _dropdownField(ctx,
                        label: 'Type',
                        value: type,
                        items: ReagentModel.typeOptions
                            .map((t) => DropdownMenuItem(
                                  value: t,
                                  child: Text(ReagentModel.typeLabel(t),
                                      style: GoogleFonts.spaceGrotesk(
                                          color: context.appTextPrimary,
                                          fontSize: 13)),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setS(() => type = v ?? 'chemical'),
                      ),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(
                          child: _field(ctx, qtyCtrl, 'Quantity',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                            child: _field(ctx, unitCtrl, 'Unit')),
                      ]),
                      const SizedBox(height: 10),
                      _field(ctx, lotCtrl, 'Lot Number'),
                    ]),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Cancel',
                    style: GoogleFonts.spaceGrotesk(
                        color: context.appTextSecondary)),
              ),
              FilledButton(
                onPressed: () {
                  if (nameCtrl.text.trim().isEmpty) return;
                  Navigator.pop(ctx, true);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child:
                    Text('Create', style: GoogleFonts.spaceGrotesk()),
              ),
            ],
          ),
        ),
      );

      if (saved != true || !mounted) return;

      await Supabase.instance.client.from('reagents').insert({
        'reagent_name': nameCtrl.text.trim(),
        'reagent_type': type,
        if (_brandCtrl.text.isNotEmpty)
          'reagent_brand': _brandCtrl.text.trim(),
        if (_refCtrl.text.isNotEmpty)
          'reagent_reference': _refCtrl.text.trim(),
        if (qtyCtrl.text.isNotEmpty)
          'reagent_quantity':
              double.tryParse(qtyCtrl.text.trim()),
        if (unitCtrl.text.isNotEmpty)
          'reagent_unit': unitCtrl.text.trim(),
        if (lotCtrl.text.isNotEmpty)
          'reagent_lot_number': lotCtrl.text.trim(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Reagent created',
            style: GoogleFonts.spaceGrotesk(color: Colors.white)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppDS.green,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
      ));
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: $e',
              style: GoogleFonts.spaceGrotesk(color: Colors.white)),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppDS.red,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ));
      }
    } finally {
      nameCtrl.dispose();
      lotCtrl.dispose();
      qtyCtrl.dispose();
      unitCtrl.dispose();
    }
  }

  // ── Form helpers ────────────────────────────────────────────────────────────
  Widget _field(
    BuildContext context,
    TextEditingController ctrl,
    String label, {
    TextInputType? keyboardType,
    bool autofocus = false,
  }) {
    return TextField(
      controller: ctrl,
      autofocus: autofocus,
      keyboardType: keyboardType,
      style: GoogleFonts.spaceGrotesk(
          color: context.appTextPrimary, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.spaceGrotesk(
            color: context.appTextSecondary, fontSize: 12),
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

  Widget _dropdownField<T>(
    BuildContext context, {
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.spaceGrotesk(
            color: context.appTextSecondary, fontSize: 12),
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

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBg,
      appBar: AppBar(
        backgroundColor: AppDS.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppDS.textSecondary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Register Reagent',
            style: GoogleFonts.spaceGrotesk(
                color: AppDS.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600)),
      ),
      body: switch (_step) {
        _Step.idle => _buildIdle(),
        _Step.processing => _buildProcessing(),
        _Step.results => _buildResults(),
      },
    );
  }

  // ── Idle ────────────────────────────────────────────────────────────────────
  Widget _buildIdle() {
    if (_isMobile) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppDS.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.camera_alt_outlined,
                  color: AppDS.accent, size: 36),
            ),
            const SizedBox(height: 20),
            Text('Scan Reagent Label',
                style: GoogleFonts.spaceGrotesk(
                    color: AppDS.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Point the camera at the product label',
                style: GoogleFonts.spaceGrotesk(
                    color: AppDS.textMuted, fontSize: 13)),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: _captureAndProcess,
                icon: const Icon(Icons.camera_alt, size: 18),
                label: Text('Open Camera',
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                style: FilledButton.styleFrom(
                  backgroundColor: AppDS.accent,
                  foregroundColor: AppDS.bg,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => setState(() => _step = _Step.results),
              child: Text('Search manually instead',
                  style: GoogleFonts.spaceGrotesk(
                      color: AppDS.textSecondary, fontSize: 13)),
            ),
          ]),
        ),
      );
    }

    return _buildDesktopSearch();
  }

  // Desktop: manual search panel ─────────────────────────────────────────────
  Widget _buildDesktopSearch() {
    return Center(
      child: SizedBox(
        width: 380,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.water_drop_outlined,
              color: AppDS.accent, size: 36),
          const SizedBox(height: 16),
          Text('Look up Reagent',
              style: GoogleFonts.spaceGrotesk(
                  color: AppDS.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Search by brand or catalog number',
              style: GoogleFonts.spaceGrotesk(
                  color: AppDS.textMuted, fontSize: 13)),
          const SizedBox(height: 24),
          _field(context, _brandCtrl, 'Brand (e.g. Sigma)'),
          const SizedBox(height: 10),
          _field(context, _refCtrl, 'Reference / Cat # (e.g. T1503)'),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton(
              onPressed: _doSearch,
              style: FilledButton.styleFrom(
                backgroundColor: AppDS.accent,
                foregroundColor: AppDS.bg,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('Search Database',
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Processing ──────────────────────────────────────────────────────────────
  Widget _buildProcessing() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (_imageBytes != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(_imageBytes!,
                width: 200, height: 200, fit: BoxFit.cover),
          ),
          const SizedBox(height: 24),
        ],
        const CircularProgressIndicator(color: AppDS.accent),
        const SizedBox(height: 16),
        Text('Processing label…',
            style: GoogleFonts.spaceGrotesk(
                color: AppDS.textSecondary, fontSize: 14)),
      ]),
    );
  }

  // ── Results ─────────────────────────────────────────────────────────────────
  Widget _buildResults() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Captured image preview (mobile)
        if (_imageBytes != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(_imageBytes!,
                width: double.infinity, height: 160, fit: BoxFit.cover),
          ),
          const SizedBox(height: 16),
        ],

        // Search fields
        Text('SEARCH CRITERIA',
            style: GoogleFonts.spaceGrotesk(
                color: context.appTextMuted,
                fontSize: 10,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _field(context, _brandCtrl, 'Brand')),
          const SizedBox(width: 10),
          Expanded(
              child:
                  _field(context, _refCtrl, 'Reference / Cat #')),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 40,
          child: FilledButton(
            onPressed: _doSearch,
            style: FilledButton.styleFrom(
              backgroundColor: AppDS.accent,
              foregroundColor: AppDS.bg,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Re-search',
                style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w600)),
          ),
        ),

        const SizedBox(height: 28),

        // Results section
        if (_searched) ...[
          if (_matches.isNotEmpty) ...[
            _sectionHeader('Found in database', AppDS.green),
            const SizedBox(height: 10),
            ..._matches.map(_buildMatchCard),
          ] else ...[
            _sectionHeader('Not found in database', AppDS.yellow),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.appSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.appBorder),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No matching reagent was found.',
                      style: GoogleFonts.spaceGrotesk(
                          color: context.appTextSecondary,
                          fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _showCreateReagent,
                      icon: const Icon(Icons.add, size: 16),
                      label: Text('Create new reagent',
                          style: GoogleFonts.spaceGrotesk(
                              fontSize: 13)),
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            const Color(0xFFF59E0B),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(8)),
                      ),
                    ),
                  ]),
            ),
          ],
        ],
      ]),
    );
  }

  Widget _sectionHeader(String label, Color color) {
    return Row(children: [
      Container(
          width: 8,
          height: 8,
          decoration:
              BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 8),
      Text(label,
          style: GoogleFonts.spaceGrotesk(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600)),
    ]);
  }

  Widget _buildMatchCard(ReagentModel r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: AppDS.green.withValues(alpha: 0.35)),
      ),
      child: Row(children: [
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.name,
                    style: GoogleFonts.spaceGrotesk(
                        color: context.appTextPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                if (r.brand != null || r.reference != null)
                  Text(
                    [
                      if (r.brand != null) r.brand!,
                      if (r.reference != null) r.reference!,
                    ].join(' · '),
                    style: GoogleFonts.spaceGrotesk(
                        color: context.appTextSecondary,
                        fontSize: 12),
                  ),
                if (r.displayQuantity != '—')
                  Text('In stock: ${r.displayQuantity}',
                      style: GoogleFonts.jetBrainsMono(
                          color: context.appTextMuted,
                          fontSize: 11)),
              ]),
        ),
        const SizedBox(width: 12),
        FilledButton(
          onPressed: () => _showUpdateQuantity(r),
          style: FilledButton.styleFrom(
            backgroundColor:
                AppDS.accent.withValues(alpha: 0.15),
            foregroundColor: AppDS.accent,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
          ),
          child: Text('Update qty',
              style:
                  GoogleFonts.spaceGrotesk(fontSize: 12)),
        ),
      ]),
    );
  }
}
