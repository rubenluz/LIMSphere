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

class TankDetailPage extends StatefulWidget {
  final ZebrafishTank tank;
  const TankDetailPage({super.key, required this.tank});

  @override
  State<TankDetailPage> createState() => _TankDetailPageState();
}

class _TankDetailPageState extends State<TankDetailPage> {
  late ZebrafishTank _tank;
  bool _editing = false;

  late TextEditingController _lineCtrl, _genoCtrl, _malesCtrl, _femalesCtrl,
      _juvsCtrl, _respCtrl, _expCtrl, _notesCtrl, _tempCtrl, _phCtrl,
      _condCtrl, _lightCtrl, _feedCtrl, _treatCtrl;
  String _status = '', _health = '', _type = '';

  @override
  void initState() {
    super.initState();
    _tank = widget.tank;
    _initCtrls();
  }

  void _initCtrls() {
    _lineCtrl  = TextEditingController(text: _tank.zebraLine ?? '');
    _genoCtrl  = TextEditingController(text: _tank.zebraGenotype ?? '');
    _malesCtrl = TextEditingController(text: '${_tank.zebraMales ?? 0}');
    _femalesCtrl= TextEditingController(text: '${_tank.zebraFemales ?? 0}');
    _juvsCtrl  = TextEditingController(text: '${_tank.zebraJuveniles ?? 0}');
    _respCtrl  = TextEditingController(text: _tank.zebraResponsible ?? '');
    _expCtrl   = TextEditingController(text: _tank.zebraExperimentId ?? '');
    _notesCtrl = TextEditingController(text: _tank.zebraNotes ?? '');
    _tempCtrl  = TextEditingController(
      text: _tank.zebraTemperatureC?.toStringAsFixed(1) ?? '28.0');
    _phCtrl    = TextEditingController(
      text: _tank.zebraPh?.toStringAsFixed(2) ?? '7.20');
    _condCtrl  = TextEditingController(
      text: '${_tank.zebraConductivity?.toStringAsFixed(0) ?? '500'}');
    _lightCtrl = TextEditingController(text: _tank.zebraLightCycle ?? '14/10');
    _feedCtrl  = TextEditingController(text: _tank.zebraFeedingSchedule ?? '');
    _treatCtrl = TextEditingController(text: _tank.zebraTreatment ?? '');
    _status    = _tank.zebraStatus ?? 'active';
    _health    = _tank.zebraHealthStatus ?? 'healthy';
    _type      = _tank.zebraTankType ?? 'holding';
  }

  void _save() {
    setState(() {
      _tank = _tank.copyWith(
        zebraLine:          _lineCtrl.text.isEmpty ? null : _lineCtrl.text,
        zebraGenotype:      _genoCtrl.text,
        zebraMales:         int.tryParse(_malesCtrl.text),
        zebraFemales:       int.tryParse(_femalesCtrl.text),
        zebraJuveniles:     int.tryParse(_juvsCtrl.text),
        zebraResponsible:   _respCtrl.text,
        zebraStatus:        _status,
        zebraHealthStatus:  _health,
        zebraTankType:      _type,
        zebraExperimentId:  _expCtrl.text.isEmpty ? null : _expCtrl.text,
        zebraNotes:         _notesCtrl.text.isEmpty ? null : _notesCtrl.text,
        zebraTemperatureC:  double.tryParse(_tempCtrl.text),
        zebraPh:            double.tryParse(_phCtrl.text),
        zebraConductivity:  double.tryParse(_condCtrl.text),
        zebraLightCycle:    _lightCtrl.text,
        zebraTreatment:     _treatCtrl.text.isEmpty ? null : _treatCtrl.text,
      );
      _editing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 900;

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
              Text(_tank.zebraTankId,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 15, fontWeight: FontWeight.w700,
                  color: _DS.textPrimary)),
              const SizedBox(width: 10),
              // Status + health + tank type badges in AppBar
              StatusBadge(label: _tank.zebraStatus),
              const SizedBox(width: 6),
              if (_tank.zebraHealthStatus != null) ...[
                StatusBadge(label: _tank.zebraHealthStatus),
                const SizedBox(width: 6),
              ],
              if (_tank.zebraTankType != null)
                _typePill(_tank.zebraTankType!),
            ]),
            Text(
              [
                if (_tank.zebraRack   != null) _tank.zebraRack!,
                if (_tank.zebraRow    != null) 'Row ${_tank.zebraRow}',
                if (_tank.zebraColumn != null) 'Col ${_tank.zebraColumn}',
                _tank.volumeLabel,
              ].join(' · '),
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10, color: _DS.textSecondary)),
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
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Quick stats
              Wrap(spacing: 10, runSpacing: 10, children: [
                StatCard(label: 'MALES',   value: '${_tank.zebraMales ?? 0}'),
                StatCard(label: 'FEMALES', value: '${_tank.zebraFemales ?? 0}'),
                StatCard(label: 'JUVENILES',
                    value: '${_tank.zebraJuveniles ?? 0}', color: _DS.yellow),
                StatCard(label: 'TOTAL', value: '${_tank.totalFish}',
                    color: _DS.green),
                StatCard(label: 'VOLUME', value: _tank.volumeLabel),
                if (_tank.zebraTemperatureC != null)
                  StatCard(label: 'TEMP',
                      value: '${_tank.zebraTemperatureC!.toStringAsFixed(1)}°C'),
                if (_tank.zebraPh != null)
                  StatCard(label: 'pH',
                      value: _tank.zebraPh!.toStringAsFixed(2)),
              ]),
              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _leftPanel()),
                    const SizedBox(width: 24),
                    Expanded(child: _rightPanel()),
                  ])
              else
                Column(children: [_leftPanel(), _rightPanel()]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typePill(String type) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: _DS.surface3,
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: _DS.border)),
    child: Text(type, style: GoogleFonts.spaceGrotesk(
      fontSize: 10, color: _DS.textSecondary, fontWeight: FontWeight.w600)),
  );

  Widget _leftPanel() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SectionHeader(title: 'Occupants'),
      _eRow('Fish Line',  _tank.zebraLine ?? '—',     _lineCtrl),
      _eRow('Genotype',   _tank.zebraGenotype ?? '—', _genoCtrl),
      _eRow('Males ♂',    '${_tank.zebraMales ?? 0}', _malesCtrl),
      _eRow('Females ♀',  '${_tank.zebraFemales ?? 0}',_femalesCtrl),
      _eRow('Juveniles',  '${_tank.zebraJuveniles ?? 0}', _juvsCtrl),
      if (_tank.zebraDob != null)
        DetailField(label: 'Date of Birth',
            value: _tank.zebraDob!.toIso8601String().split('T')[0]),

      const SectionHeader(title: 'Status & Type'),
      if (_editing) ...[
        _ddRow('Status', _status,
          ['active', 'empty', 'quarantine', 'retired'],
          (v) => setState(() => _status = v ?? _status)),
        _ddRow('Health', _health,
          ['healthy', 'observation', 'treatment', 'sick'],
          (v) => setState(() => _health = v ?? _health)),
        _ddRow('Type', _type,
          ['breeding', 'holding', 'quarantine', 'experimental'],
          (v) => setState(() => _type = v ?? _type)),
      ] else ...[
        DetailField(label: 'Status',
            trailing: StatusBadge(label: _tank.zebraStatus)),
        DetailField(label: 'Health',
            trailing: StatusBadge(label: _tank.zebraHealthStatus)),
        DetailField(label: 'Type', value: _tank.zebraTankType ?? '—'),
      ],

      const SectionHeader(title: 'Management'),
      _eRow('Responsible',  _tank.zebraResponsible ?? '—',   _respCtrl),
      _eRow('Experiment ID',_tank.zebraExperimentId ?? '—', _expCtrl, mono: true),
      if (_tank.zebraEthicsApproval != null)
        DetailField(label: 'Ethics Approval',
            value: _tank.zebraEthicsApproval, mono: true),
      _eRow('Notes', _tank.zebraNotes ?? '—', _notesCtrl),
    ],
  );

  Widget _rightPanel() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SectionHeader(title: 'Water Quality'),
      _eRow('Temperature',
          '${_tank.zebraTemperatureC?.toStringAsFixed(1) ?? '—'}°C', _tempCtrl),
      _eRow('pH',
          _tank.zebraPh?.toStringAsFixed(2) ?? '—', _phCtrl),
      _eRow('Conductivity',
          '${_tank.zebraConductivity?.toStringAsFixed(0) ?? '—'} µS/cm', _condCtrl),
      _eRow('Light Cycle',
          _tank.zebraLightCycle ?? '14/10', _lightCtrl),
      _eRow('Feeding Schedule',
          _tank.zebraFeedingSchedule ?? '—', _feedCtrl),

      const SectionHeader(title: 'Health & Maintenance'),
      if (_tank.zebraLastHealthCheck != null)
        DetailField(label: 'Last Health Check',
            value: _tank.zebraLastHealthCheck!.toIso8601String().split('T')[0]),
      if (_tank.zebraLastTankCleaning != null)
        DetailField(label: 'Last Cleaning',
            value: _tank.zebraLastTankCleaning!.toIso8601String().split('T')[0]),
      if (_tank.zebraCleaningIntervalDays != null)
        DetailField(label: 'Cleaning Interval',
            value: 'every ${_tank.zebraCleaningIntervalDays} days'),
      _eRow('Treatment', _tank.zebraTreatment ?? '—', _treatCtrl),

      const SectionHeader(title: 'Tank Identity'),
      DetailField(label: 'Tank ID',  value: _tank.zebraTankId, mono: true),
      DetailField(label: 'Rack',     value: _tank.zebraRack ?? '—', mono: true),
      DetailField(label: 'Row',      value: _tank.zebraRow ?? '—', mono: true),
      DetailField(label: 'Column',   value: _tank.zebraColumn ?? '—', mono: true),
      DetailField(label: 'Volume',   value: _tank.volumeLabel),
      DetailField(label: '8 L Config',
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(
                color: _tank.isEightLiter ? _DS.accent : _DS.textMuted,
                shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(_tank.isEightLiter ? 'Yes' : 'No',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 13, color: _DS.textPrimary)),
          ])),
    ],
  );

  Widget _eRow(String label, String value,
      TextEditingController ctrl, {bool mono = false}) {
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
    return DetailField(label: label, value: value, mono: mono);
  }

  Widget _ddRow(String label, String value, List<String> opts,
      ValueChanged<String?> cb) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      SizedBox(width: 150,
        child: Text(label, style: GoogleFonts.spaceGrotesk(
          fontSize: 11, fontWeight: FontWeight.w700,
          letterSpacing: 0.08, color: _DS.textMuted))),
      SizedBox(
        width: 200,
        child: DropdownButtonFormField<String>(
          value: opts.contains(value) ? value : opts.first,
          dropdownColor: _DS.surface2,
          style: GoogleFonts.spaceGrotesk(color: _DS.textPrimary, fontSize: 13),
          items: opts.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
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