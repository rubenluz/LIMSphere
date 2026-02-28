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
  static const Color yellow   = Color(0xFFEAB308);
  static const Color textPrimary   = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted     = Color(0xFF64748B);
}

class StockDetailPage extends StatefulWidget {
  final FishStock stock;
  const StockDetailPage({super.key, required this.stock});

  @override
  State<StockDetailPage> createState() => _StockDetailPageState();
}

class _StockDetailPageState extends State<StockDetailPage> {
  late FishStock _stock;
  bool _editing = false;

  late TextEditingController _lineCtrl, _genoCtrl, _ageCtrl,
      _malesCtrl, _femalesCtrl, _juvenilesCtrl, _tankCtrl,
      _respCtrl, _expCtrl, _notesCtrl;
  String _editStatus = '';
  String _editHealth = '';

  @override
  void initState() {
    super.initState();
    _stock = widget.stock;
    _initControllers();
  }

  void _initControllers() {
    _lineCtrl     = TextEditingController(text: _stock.line);
    _genoCtrl     = TextEditingController(text: _stock.genotype);
    _ageCtrl      = TextEditingController(text: '${_stock.ageMonths}');
    _malesCtrl    = TextEditingController(text: '${_stock.males}');
    _femalesCtrl  = TextEditingController(text: '${_stock.females}');
    _juvenilesCtrl= TextEditingController(text: '${_stock.juveniles}');
    _tankCtrl     = TextEditingController(text: _stock.tankId);
    _respCtrl     = TextEditingController(text: _stock.responsible);
    _expCtrl      = TextEditingController(text: _stock.experiment ?? '');
    _notesCtrl    = TextEditingController(text: _stock.notes ?? '');
    _editStatus   = _stock.status;
    _editHealth   = _stock.health;
  }

  void _save() {
    setState(() {
      _stock.line        = _lineCtrl.text;
      _stock.genotype    = _genoCtrl.text;
      _stock.ageMonths   = int.tryParse(_ageCtrl.text) ?? _stock.ageMonths;
      _stock.males       = int.tryParse(_malesCtrl.text) ?? _stock.males;
      _stock.females     = int.tryParse(_femalesCtrl.text) ?? _stock.females;
      _stock.juveniles   = int.tryParse(_juvenilesCtrl.text) ?? _stock.juveniles;
      _stock.tankId      = _tankCtrl.text;
      _stock.responsible = _respCtrl.text;
      _stock.status      = _editStatus;
      _stock.health      = _editHealth;
      _stock.experiment  = _expCtrl.text.isEmpty ? null : _expCtrl.text;
      _stock.notes       = _notesCtrl.text.isEmpty ? null : _notesCtrl.text;
      _editing = false;
    });
  }

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
            Row(children: [
              Text(_stock.stockId,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 15, fontWeight: FontWeight.w700,
                  color: _DS.textPrimary)),
              const SizedBox(width: 10),
              // Status and health badges integrated in AppBar
              StatusBadge(label: _stock.status),
              const SizedBox(width: 6),
              StatusBadge(label: _stock.health),
            ]),
            Text(_stock.line,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11, color: _DS.textSecondary)),
          ],
        ),
        actions: [
          if (_editing) ...[
            OutlinedButton(
              onPressed: () { setState(() => _editing = false); _initControllers(); },
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
            const SizedBox(width: 12),
          ] else ...[
            OutlinedButton.icon(
              icon: const Icon(Icons.edit_outlined, size: 14),
              label: const Text('Edit'),
              onPressed: () => setState(() => _editing = true),
              style: OutlinedButton.styleFrom(
                foregroundColor: _DS.textSecondary,
                side: const BorderSide(color: _DS.border))),
            const SizedBox(width: 12),
          ],
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _DS.border)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Quick stats row
              Wrap(spacing: 10, runSpacing: 10, children: [
                StatCard(label: 'TOTAL FISH',
                    value: '${_stock.totalFish}', color: _DS.green),
                StatCard(label: 'MALES',    value: '${_stock.males}'),
                StatCard(label: 'FEMALES',  value: '${_stock.females}'),
                StatCard(label: 'JUVENILES',
                    value: '${_stock.juveniles}', color: _DS.yellow),
                StatCard(label: 'AGE', value: '${_stock.ageMonths} mo'),
              ]),

              const SectionHeader(title: 'Identity'),
              _row('Stock ID',   _stock.stockId,    null, readOnly: true, mono: true),
              _row('Fish Line',  _stock.line,        _lineCtrl),
              _row('Genotype',   _stock.genotype,    _genoCtrl),
              _row('Tank',       _stock.tankId,      _tankCtrl, mono: true),
              _row('Responsible',_stock.responsible, _respCtrl),

              const SectionHeader(title: 'Population'),
              _row('Age (months)', '${_stock.ageMonths}', _ageCtrl),
              _row('Males ♂',     '${_stock.males}',      _malesCtrl),
              _row('Females ♀',   '${_stock.females}',    _femalesCtrl),
              _row('Juveniles',    '${_stock.juveniles}',  _juvenilesCtrl),

              const SectionHeader(title: 'Status'),
              if (_editing) ...[
                _dropRow('Status', _editStatus,
                    ['active', 'breeding', 'observation', 'archiving'],
                    (v) => setState(() => _editStatus = v ?? _editStatus)),
                _dropRow('Health', _editHealth,
                    ['healthy', 'observation', 'treatment', 'sick'],
                    (v) => setState(() => _editHealth = v ?? _editHealth)),
              ] else ...[
                DetailField(label: 'Status',
                    trailing: StatusBadge(label: _stock.status)),
                DetailField(label: 'Health',
                    trailing: StatusBadge(label: _stock.health)),
              ],

              const SectionHeader(title: 'Research'),
              _row('Experiment ID', _stock.experiment ?? '—', _expCtrl, mono: true),
              _row('Notes', _stock.notes ?? '—', _notesCtrl),

              const SectionHeader(title: 'Metadata'),
              DetailField(label: 'Created',
                  value: _stock.created.toIso8601String().split('T')[0]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value, TextEditingController? ctrl,
      {bool mono = false, bool readOnly = false}) {
    if (_editing && ctrl != null && !readOnly) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          SizedBox(width: 170,
            child: Text(label, style: GoogleFonts.spaceGrotesk(
              fontSize: 11, fontWeight: FontWeight.w700,
              letterSpacing: 0.08, color: _DS.textMuted))),
          SizedBox(
            width: 280,
            child: TextField(
              controller: ctrl,
              style: (mono ? GoogleFonts.jetBrainsMono(fontSize: 13)
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
    return DetailField(label: label, value: value, mono: mono);
  }

  Widget _dropRow(String label, String value, List<String> opts,
      ValueChanged<String?> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        SizedBox(width: 170,
          child: Text(label, style: GoogleFonts.spaceGrotesk(
            fontSize: 11, fontWeight: FontWeight.w700,
            letterSpacing: 0.08, color: _DS.textMuted))),
        SizedBox(
          width: 200,
          child: DropdownButtonFormField<String>(
            value: value,
            dropdownColor: _DS.surface2,
            style: GoogleFonts.spaceGrotesk(color: _DS.textPrimary, fontSize: 13),
            items: opts.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: onChanged,
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
}