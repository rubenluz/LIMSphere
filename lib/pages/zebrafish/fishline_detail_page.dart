import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/models/connection_model.dart';
import 'shared_widgets.dart';

// Design tokens
class _DS {
  static const Color bg       = Color(0xFF0F172A);
  static const Color surface  = Color(0xFF1E293B);
  static const Color surface2 = Color(0xFF1A2438);
  static const Color surface3 = Color(0xFF243044);
  static const Color border   = Color(0xFF334155);
  static const Color border2  = Color(0xFF2D3F55);
  static const Color accent   = Color(0xFF38BDF8);
  static const Color green    = Color(0xFF22C55E);
  static const Color textPrimary   = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted     = Color(0xFF64748B);
}

class FishLineDetailPage extends StatefulWidget {
  final FishLine fishLine;
  final ValueChanged<FishLine>? onSave;

  const FishLineDetailPage({super.key, required this.fishLine, this.onSave});

  @override
  State<FishLineDetailPage> createState() => _FishLineDetailPageState();
}

class _FishLineDetailPageState extends State<FishLineDetailPage> {
  late FishLine _line;
  bool _editing = false;

  late TextEditingController _nameCtrl, _aliasCtrl, _geneCtrl, _chromoCtrl,
      _mutDescCtrl, _transgeneCtrl, _constructCtrl, _promoterCtrl,
      _reporterCtrl, _tissueCtrl, _labCtrl, _personCtrl,
      _sourceCtrl, _permitCtrl, _mtaCtrl, _zfinCtrl, _pubmedCtrl, _doiCtrl,
      _cryoLocCtrl, _cryoMethodCtrl, _phenoCtrl, _lethalCtrl,
      _healthNotesCtrl, _riskCtrl, _notesCtrl;
  String _type = '', _status = '', _zygosity = '', _generation = '',
      _mutationType = '', _spfStatus = '';
  bool _cryopreserved = false;

  @override
  void initState() {
    super.initState();
    _line = widget.fishLine;
    _initCtrls();
  }

  void _initCtrls() {
    final l = _line;
    _nameCtrl       = TextEditingController(text: l.fishlineName);
    _aliasCtrl      = TextEditingController(text: l.fishlineAlias ?? '');
    _geneCtrl       = TextEditingController(text: l.fishlineAffectedGene ?? '');
    _chromoCtrl     = TextEditingController(text: l.fishlineAffectedChromosome ?? '');
    _mutDescCtrl    = TextEditingController(text: l.fishlineMutationDescription ?? '');
    _transgeneCtrl  = TextEditingController(text: l.fishlineTransgene ?? '');
    _constructCtrl  = TextEditingController(text: l.fishlineConstruct ?? '');
    _promoterCtrl   = TextEditingController(text: l.fishlinePromoter ?? '');
    _reporterCtrl   = TextEditingController(text: l.fishlineReporter ?? '');
    _tissueCtrl     = TextEditingController(text: l.fishlineTargetTissue ?? '');
    _labCtrl        = TextEditingController(text: l.fishlineOriginLab ?? '');
    _personCtrl     = TextEditingController(text: l.fishlineOriginPerson ?? '');
    _sourceCtrl     = TextEditingController(text: l.fishlineSource ?? '');
    _permitCtrl     = TextEditingController(text: l.fishlineImportPermit ?? '');
    _mtaCtrl        = TextEditingController(text: l.fishlineMta ?? '');
    _zfinCtrl       = TextEditingController(text: l.fishlineZfinId ?? '');
    _pubmedCtrl     = TextEditingController(text: l.fishlinePubmed ?? '');
    _doiCtrl        = TextEditingController(text: l.fishlineDoi ?? '');
    _cryoLocCtrl    = TextEditingController(text: l.fishlineCryoLocation ?? '');
    _cryoMethodCtrl = TextEditingController(text: l.fishlineCryoMethod ?? '');
    _phenoCtrl      = TextEditingController(text: l.fishlinePhenotype ?? '');
    _lethalCtrl     = TextEditingController(text: l.fishlineLethality ?? '');
    _healthNotesCtrl= TextEditingController(text: l.fishlineHealthNotes ?? '');
    _riskCtrl       = TextEditingController(text: l.fishlineRiskLevel ?? '');
    _notesCtrl      = TextEditingController(text: l.fishlineNotes ?? '');
    _type        = l.fishlineType ?? 'transgenic';
    _status      = l.fishlineStatus ?? 'active';
    _zygosity    = l.fishlineZygosity ?? 'heterozygous';
    _generation  = l.fishlineGeneration ?? 'F3';
    _mutationType= l.fishlineMutationType ?? '';
    _spfStatus   = l.fishlineSpfStatus ?? 'SPF';
    _cryopreserved = l.fishlineCryopreserved;
  }

  void _save() {
    _line.fishlineName               = _nameCtrl.text;
    _line.fishlineAlias              = _n(_aliasCtrl);
    _line.fishlineType               = _type;
    _line.fishlineStatus             = _status;
    _line.fishlineZygosity           = _zygosity;
    _line.fishlineGeneration         = _generation;
    _line.fishlineAffectedGene       = _n(_geneCtrl);
    _line.fishlineAffectedChromosome = _n(_chromoCtrl);
    _line.fishlineMutationType       = _mutationType.isEmpty ? null : _mutationType;
    _line.fishlineMutationDescription= _n(_mutDescCtrl);
    _line.fishlineTransgene          = _n(_transgeneCtrl);
    _line.fishlineConstruct          = _n(_constructCtrl);
    _line.fishlinePromoter           = _n(_promoterCtrl);
    _line.fishlineReporter           = _n(_reporterCtrl);
    _line.fishlineTargetTissue       = _n(_tissueCtrl);
    _line.fishlineOriginLab          = _n(_labCtrl);
    _line.fishlineOriginPerson       = _n(_personCtrl);
    _line.fishlineSource             = _n(_sourceCtrl);
    _line.fishlineImportPermit       = _n(_permitCtrl);
    _line.fishlineMta                = _n(_mtaCtrl);
    _line.fishlineZfinId             = _n(_zfinCtrl);
    _line.fishlinePubmed             = _n(_pubmedCtrl);
    _line.fishlineDoi                = _n(_doiCtrl);
    _line.fishlineCryopreserved      = _cryopreserved;
    _line.fishlineCryoLocation       = _n(_cryoLocCtrl);
    _line.fishlineCryoMethod         = _n(_cryoMethodCtrl);
    _line.fishlinePhenotype          = _n(_phenoCtrl);
    _line.fishlineLethality          = _n(_lethalCtrl);
    _line.fishlineHealthNotes        = _n(_healthNotesCtrl);
    _line.fishlineRiskLevel          = _n(_riskCtrl);
    _line.fishlineNotes              = _n(_notesCtrl);
    _line.fishlineSpfStatus          = _spfStatus;
    _line.fishlineUpdatedAt          = DateTime.now();
    widget.onSave?.call(_line);
    setState(() => _editing = false);
  }

  String? _n(TextEditingController c) => c.text.isEmpty ? null : c.text;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _DS.bg,
      appBar: AppBar(
        backgroundColor: _DS.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 16, color: _DS.textSecondary),
          onPressed: () => Navigator.pop(context)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Name + status badges — integrated into app bar
            Row(
              children: [
                Flexible(
                  child: Text(_line.fishlineName,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 14, fontWeight: FontWeight.w700,
                      color: _DS.textPrimary),
                    overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 8),
                StatusBadge(label: _line.fishlineStatus),
                if (_line.fishlineType != null) ...[
                  const SizedBox(width: 6),
                  StatusBadge(
                    label: _line.fishlineType,
                    overrideStatus: _line.fishlineType?.toLowerCase()),
                ],
                if (_line.fishlineZygosity != null) ...[
                  const SizedBox(width: 6),
                  _infoTag(_line.fishlineZygosity!),
                ],
                if (_line.fishlineGeneration != null) ...[
                  const SizedBox(width: 4),
                  _infoTag(_line.fishlineGeneration!),
                ],
              ],
            ),
            if (_line.fishlineZfinId != null || _line.fishlineAlias != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  [
                    if (_line.fishlineAlias != null) _line.fishlineAlias!,
                    if (_line.fishlineZfinId != null) _line.fishlineZfinId!,
                  ].join('  ·  '),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10, color: _DS.textSecondary),
                ),
              ),
          ],
        ),
        actions: [
          if (_editing) ...[
            OutlinedButton(
              onPressed: () { setState(() => _editing = false); _initCtrls(); },
              style: OutlinedButton.styleFrom(
                foregroundColor: _DS.textSecondary,
                side: const BorderSide(color: _DS.border)),
              child: const Text('Cancel')),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.check, size: 14),
              label: const Text('Save'),
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: _DS.accent, foregroundColor: _DS.bg)),
          ] else
            OutlinedButton.icon(
              icon: const Icon(Icons.edit_outlined, size: 14),
              label: const Text('Edit'),
              onPressed: () => setState(() => _editing = true),
              style: OutlinedButton.styleFrom(
                foregroundColor: _DS.textSecondary,
                side: const BorderSide(color: _DS.border))),
          const SizedBox(width: 12),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _DS.border)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: MediaQuery.of(context).size.width > 900
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _leftCol()),
                    const SizedBox(width: 28),
                    Expanded(child: _rightCol()),
                  ])
              : Column(children: [_leftCol(), _rightCol()]),
        ),
      ),
    );
  }

  Widget _infoTag(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: _DS.surface3,
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: _DS.border)),
    child: Text(text, style: GoogleFonts.jetBrainsMono(
      fontSize: 9, color: _DS.textSecondary)),
  );

  Widget _leftCol() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SectionHeader(title: 'Core Identity'),
      _e('Name', _nameCtrl),
      _e('Alias', _aliasCtrl),
      _d('Type', _type, ['WT','transgenic','mutant','CRISPR','KO','KI'],
          (v) => setState(() => _type = v ?? _type)),
      _d('Status', _status, ['active','archived','cryopreserved','lost'],
          (v) => setState(() => _status = v ?? _status)),
      _d('Zygosity', _zygosity, ['homozygous','heterozygous','unknown'],
          (v) => setState(() => _zygosity = v ?? _zygosity)),
      _d('Generation', _generation, ['F1','F2','F3','F4','F5','F6'],
          (v) => setState(() => _generation = v ?? _generation)),

      const SectionHeader(title: 'Genetic Details'),
      _e('Affected Gene', _geneCtrl, mono: true),
      _e('Affected Chromosome', _chromoCtrl),
      _d('Mutation Type', _mutationType,
          ['', 'insertion','deletion','point mutation','inversion'],
          (v) => setState(() => _mutationType = v ?? '')),
      _e('Mutation Description', _mutDescCtrl),
      _e('Transgene', _transgeneCtrl),
      _e('Construct', _constructCtrl),
      _e('Promoter', _promoterCtrl),
      _e('Reporter', _reporterCtrl),
      _e('Target Tissue', _tissueCtrl),

      const SectionHeader(title: 'Phenotype & Health'),
      _e('Phenotype', _phenoCtrl),
      _e('Lethality', _lethalCtrl),
      _e('Health Notes', _healthNotesCtrl),
    ],
  );

  Widget _rightCol() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SectionHeader(title: 'Origin & Provenance'),
      _e('Origin Lab', _labCtrl),
      _e('Origin Person', _personCtrl),
      if (_line.fishlineDateCreated != null)
        DetailField(label: 'Date Created',
            value: _line.fishlineDateCreated!.toIso8601String().split('T')[0]),
      if (_line.fishlineDateReceived != null)
        DetailField(label: 'Date Received',
            value: _line.fishlineDateReceived!.toIso8601String().split('T')[0]),
      _e('Source', _sourceCtrl),
      _e('Import Permit', _permitCtrl, mono: true),
      _e('MTA', _mtaCtrl, mono: true),

      const SectionHeader(title: 'Publications & Identifiers'),
      _e('ZFIN ID', _zfinCtrl, mono: true),
      _e('PubMed ID', _pubmedCtrl, mono: true),
      _e('DOI', _doiCtrl, mono: true),

      const SectionHeader(title: 'Cryopreservation'),
      if (_editing)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [
            SizedBox(width: 150,
              child: Text('Cryopreserved', style: GoogleFonts.spaceGrotesk(
                fontSize: 11, fontWeight: FontWeight.w700,
                letterSpacing: 0.08, color: _DS.textMuted))),
            Switch(value: _cryopreserved, activeColor: _DS.accent,
              onChanged: (v) => setState(() => _cryopreserved = v)),
          ]),
        )
      else
        DetailField(
          label: 'Cryopreserved',
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(_line.fishlineCryopreserved ? Icons.ac_unit : Icons.remove,
              size: 14,
              color: _line.fishlineCryopreserved ? _DS.accent : _DS.textMuted),
            const SizedBox(width: 6),
            Text(_line.fishlineCryopreserved ? 'Yes' : 'No',
              style: GoogleFonts.spaceGrotesk(fontSize: 13, color: _DS.textPrimary)),
          ]),
        ),
      _e('Cryo Location', _cryoLocCtrl),
      _e('Cryo Method', _cryoMethodCtrl),
      if (_line.fishlineCryoDate != null)
        DetailField(label: 'Cryo Date',
            value: _line.fishlineCryoDate!.toIso8601String().split('T')[0]),

      const SectionHeader(title: 'Facility & Risk'),
      _d('SPF Status', _spfStatus, ['SPF','non-SPF','unknown'],
          (v) => setState(() => _spfStatus = v ?? _spfStatus)),
      _e('Risk Level', _riskCtrl),
      if (_line.fishlineQrcode != null)
        DetailField(label: 'QR Code', value: _line.fishlineQrcode, mono: true),
      if (_line.fishlineBarcode != null)
        DetailField(label: 'Barcode', value: _line.fishlineBarcode, mono: true),

      const SectionHeader(title: 'Notes & Metadata'),
      _e('Notes', _notesCtrl),
      if (_line.fishlineCreatedAt != null)
        DetailField(label: 'Record Created',
            value: _line.fishlineCreatedAt!.toIso8601String().split('T')[0]),
      if (_line.fishlineUpdatedAt != null)
        DetailField(label: 'Last Updated',
            value: _line.fishlineUpdatedAt!.toIso8601String().split('T')[0]),
    ],
  );

  Widget _e(String label, TextEditingController ctrl, {bool mono = false}) {
    if (_editing) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          SizedBox(width: 150,
            child: Text(label, style: GoogleFonts.spaceGrotesk(
              fontSize: 11, fontWeight: FontWeight.w700,
              letterSpacing: 0.08, color: _DS.textMuted))),
          Expanded(
            child: TextField(
              controller: ctrl,
              style: (mono ? GoogleFonts.jetBrainsMono(fontSize: 12.5)
                  : GoogleFonts.spaceGrotesk(fontSize: 13))
                  .copyWith(color: _DS.textPrimary),
              decoration: InputDecoration(
                isDense: true,
                filled: true, fillColor: _DS.surface3,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: _DS.border)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: _DS.accent, width: 1.5)),
              ),
            ),
          ),
        ]),
      );
    }
    final val = ctrl.text.isEmpty ? null : ctrl.text;
    return DetailField(label: label, value: val, mono: mono);
  }

  Widget _d(String label, String value, List<String> opts,
      ValueChanged<String?> cb) {
    if (_editing) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          SizedBox(width: 150,
            child: Text(label, style: GoogleFonts.spaceGrotesk(
              fontSize: 11, fontWeight: FontWeight.w700,
              letterSpacing: 0.08, color: _DS.textMuted))),
          SizedBox(
            width: 200,
            child: DropdownButtonFormField<String>(
              value: opts.contains(value) ? value : (opts.isNotEmpty ? opts.first : null),
              dropdownColor: _DS.surface2,
              style: GoogleFonts.spaceGrotesk(color: _DS.textPrimary, fontSize: 13),
              items: opts.map((v) => DropdownMenuItem(
                value: v, child: Text(v.isEmpty ? '—' : v))).toList(),
              onChanged: cb,
              decoration: InputDecoration(
                isDense: true,
                filled: true, fillColor: _DS.surface3,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: _DS.border)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: _DS.accent, width: 1.5)),
              ),
            ),
          ),
        ]),
      );
    }
    return DetailField(label: label, value: value.isEmpty ? null : value);
  }
}