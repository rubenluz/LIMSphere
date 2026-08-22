// well_randomizer_page.dart - 96-well plate randomization tool.
// Left panel: unique sample count, default replicates, per-sample name and rep
// count (with colored masked ID prefix), exclusion shortcuts.
// Right panel: interactive plate grid. Export to CSV and PNG.

import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '/theme/theme.dart';

const _rows = 8; // A..H
const _cols = 12; // 1..12
const _accent = Color(0xFFA855F7);

String _wellId(int r, int c) => '${String.fromCharCode(65 + r)}${c + 1}';
String _maskedId(int index) => _wellId(index ~/ _cols, index % _cols);

String _twoDigits(int value) => value.toString().padLeft(2, '0');

String _defaultPlateName(DateTime dateTime) =>
    '${dateTime.year}${_twoDigits(dateTime.month)}${_twoDigits(dateTime.day)}_'
    '${_twoDigits(dateTime.hour)}${_twoDigits(dateTime.minute)}';

// Distinct color per sample index using the golden-angle hue cycle.
Color _sampleColor(int i) {
  final hue = (i * 137.50776) % 360;
  return HSVColor.fromAHSV(1.0, hue, 0.55, 0.90).toColor();
}

class WellRandomizerPage extends StatefulWidget {
  const WellRandomizerPage({super.key});

  @override
  State<WellRandomizerPage> createState() => _WellRandomizerPageState();
}

class _WellRandomizerPageState extends State<WellRandomizerPage> {
  int _uniqueCount = 6;
  int _defaultReps = 10;
  bool _masked = false;
  final Set<String> _excluded = {};
  final List<TextEditingController> _names = [];
  final List<TextEditingController> _repCtrls = [];
  late final TextEditingController _defaultRepsCtrl;
  late final TextEditingController _plateNameCtrl;
  final Map<String, int> _assignment = {}; // well -> sample index

  final GlobalKey _plateKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _defaultRepsCtrl = TextEditingController(text: '$_defaultReps');
    _plateNameCtrl = TextEditingController(
      text: _defaultPlateName(DateTime.now()),
    );
    for (int r = 0; r < _rows; r++) {
      for (int c = 0; c < _cols; c++) {
        if (r == 0 || r == _rows - 1 || c == 0 || c == _cols - 1) {
          _excluded.add(_wellId(r, c));
        }
      }
    }
    _resizeSamples(_uniqueCount);
  }

  @override
  void dispose() {
    for (final c in _names) {
      c.dispose();
    }
    for (final c in _repCtrls) {
      c.dispose();
    }
    _defaultRepsCtrl.dispose();
    _plateNameCtrl.dispose();
    super.dispose();
  }

  int get _includedCount => _rows * _cols - _excluded.length;

  int get _totalReps {
    var t = 0;
    for (final c in _repCtrls) {
      t += (int.tryParse(c.text) ?? 0);
    }
    return t;
  }

  int _repsAt(int i) => int.tryParse(_repCtrls[i].text) ?? 0;

  void _resizeSamples(int n) {
    while (_names.length < n) {
      final defaultName = switch (_names.length) {
        0 => 'Positive Control',
        1 => 'Solvent Control',
        _ => '',
      };
      _names.add(TextEditingController(text: defaultName));
      _repCtrls.add(TextEditingController(text: '$_defaultReps'));
    }
    while (_names.length > n) {
      _names.removeLast().dispose();
      _repCtrls.removeLast().dispose();
    }
  }

  void _setUniqueCount(int n) {
    final maxUnique = _includedCount < 1 ? 1 : _includedCount;
    final clamped = n.clamp(1, maxUnique);
    setState(() {
      _uniqueCount = clamped;
      _resizeSamples(clamped);
      _assignment.clear();
    });
  }

  void _setDefaultReps(int n) {
    final clamped = n.clamp(1, 96);
    setState(() {
      _defaultReps = clamped;
      _defaultRepsCtrl.text = '$clamped';
      for (final c in _repCtrls) {
        c.text = '$clamped';
      }
      _assignment.clear();
    });
  }

  void _toggleWell(String id) {
    setState(() {
      if (_excluded.contains(id)) {
        _excluded.remove(id);
      } else {
        _excluded.add(id);
      }
      if (_uniqueCount > _includedCount && _includedCount > 0) {
        _uniqueCount = _includedCount;
        _resizeSamples(_uniqueCount);
      }
      _assignment.clear();
    });
  }

  void _applyExclusionMask(int layers) {
    setState(() {
      _excluded.clear();
      for (int r = 0; r < _rows; r++) {
        for (int c = 0; c < _cols; c++) {
          if (r < layers ||
              r >= _rows - layers ||
              c < layers ||
              c >= _cols - layers) {
            _excluded.add(_wellId(r, c));
          }
        }
      }
      if (_uniqueCount > _includedCount && _includedCount > 0) {
        _uniqueCount = _includedCount;
        _resizeSamples(_uniqueCount);
      }
      _assignment.clear();
    });
  }

  void _clearExclusions() {
    setState(() {
      _excluded.clear();
      _assignment.clear();
    });
  }

  void _randomize() {
    final slots = <int>[];
    for (int i = 0; i < _uniqueCount; i++) {
      final reps = _repsAt(i);
      for (int r = 0; r < reps; r++) {
        slots.add(i);
      }
    }
    if (slots.isEmpty) return;
    if (slots.length > _includedCount) {
      _toast(
        'Total wells (${slots.length}) exceeds available '
        '($_includedCount). Reduce replicates or samples.',
        error: true,
      );
      return;
    }
    final included = <String>[];
    for (int r = 0; r < _rows; r++) {
      for (int c = 0; c < _cols; c++) {
        final id = _wellId(r, c);
        if (!_excluded.contains(id)) included.add(id);
      }
    }
    included.shuffle(Random());
    setState(() {
      _assignment.clear();
      for (int k = 0; k < slots.length; k++) {
        _assignment[included[k]] = slots[k];
      }
    });
  }

  String _labelForWell(String well) {
    final idx = _assignment[well];
    if (idx == null) return '';
    if (_masked) return _maskedId(idx);
    final name = _names[idx].text.trim();
    return name.isEmpty ? _maskedId(idx) : name;
  }

  String _csvEscape(String v) => '"${v.replaceAll('"', '""')}"';

  String get _exportBaseName {
    final sanitized = _plateNameCtrl.text.trim().replaceAll(
      RegExp(r'[<>:"/\\|?*\x00-\x1F]'),
      '_',
    );
    return sanitized.isEmpty ? _defaultPlateName(DateTime.now()) : sanitized;
  }

  Future<void> _exportCsv() async {
    try {
      final repCounter = <int, int>{};
      final buf = StringBuffer()
        ..writeln('well,masked_id,sample_name,replicate,excluded');
      for (int r = 0; r < _rows; r++) {
        for (int c = 0; c < _cols; c++) {
          final id = _wellId(r, c);
          final idx = _assignment[id];
          String masked = '';
          String name = '';
          String rep = '';
          if (idx != null) {
            final n = (repCounter[idx] ?? 0) + 1;
            repCounter[idx] = n;
            masked = _maskedId(idx);
            name = _names[idx].text.trim();
            rep = '$n';
          }
          buf.writeln(
            [
              _csvEscape(id),
              _csvEscape(masked),
              _csvEscape(name),
              rep,
              _excluded.contains(id) ? 'yes' : 'no',
            ].join(','),
          );
        }
      }
      final dir = await getDownloadsDirectory();
      final path = '${dir!.path}/$_exportBaseName.csv';
      await File(path).writeAsString(buf.toString());
      await OpenFilex.open(path);
    } catch (e) {
      _toast('CSV export failed: $e', error: true);
    }
  }

  Future<void> _exportImage() async {
    try {
      final boundary =
          _plateKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!
          .buffer
          .asUint8List();
      final dir = await getDownloadsDirectory();
      final path = '${dir!.path}/$_exportBaseName.png';
      await File(path).writeAsBytes(bytes);
      await OpenFilex.open(path);
    } catch (e) {
      _toast('Image export failed: $e', error: true);
    }
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppDS.red : AppDS.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBg,
      appBar: AppBar(
        backgroundColor: AppDS.surface2,
        foregroundColor: AppDS.textPrimary,
        title: Row(
          children: [
            const Icon(Icons.grid_on_outlined, size: 18, color: _accent),
            const SizedBox(width: 8),
            Text(
              '96 Well Randomizer',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppDS.textPrimary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Export CSV',
            onPressed: _assignment.isEmpty ? null : _exportCsv,
            icon: const Icon(Icons.table_chart_outlined, size: 20),
          ),
          IconButton(
            tooltip: 'Export PNG',
            onPressed: _assignment.isEmpty ? null : _exportImage,
            icon: const Icon(Icons.image_outlined, size: 20),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 12, 10),
            child: ElevatedButton.icon(
              onPressed: _randomize,
              icon: const Icon(Icons.shuffle_rounded, size: 16),
              label: const Text('Randomize'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (ctx, cons) {
          final wide = cons.maxWidth >= 900;
          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: 380, child: _buildControls()),
                Container(width: 1, color: context.appBorder),
                Expanded(child: _buildPlate()),
              ],
            );
          }
          return Column(
            children: [
              AspectRatio(
                aspectRatio: (_cols + 1) / (_rows + 1),
                child: _buildPlate(),
              ),
              Container(height: 1, color: context.appBorder),
              Expanded(child: _buildControls()),
            ],
          );
        },
      ),
    );
  }

  Widget _buildControls() {
    return ColoredBox(
      color: context.appSurface,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _plateNameCtrl,
                decoration: InputDecoration(
                  labelText: 'Plate name',
                  helperText: 'Used as the CSV and PNG file name',
                  isDense: true,
                  filled: true,
                  fillColor: context.appSurface2,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _controlsWarning(),
              const SizedBox(height: 14),
              _sectionLabel('Number of unique samples'),
              _sampleCountRow(),
              const SizedBox(height: 4),
              _totalsRow(),
              const SizedBox(height: 14),
              _replicatesRow(),
              const SizedBox(height: 14),
              _maskToggleRow(),
              const SizedBox(height: 14),
              _sectionLabel('Exclude wells'),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _chipBtn('Outer ring', () => _applyExclusionMask(1)),
                  _chipBtn('Outer 2 rings', () => _applyExclusionMask(2)),
                  _chipBtn('Clear', _clearExclusions),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Click any well on the plate to toggle.',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 11,
                  color: context.appTextMuted,
                ),
              ),
              const SizedBox(height: 14),
              _sectionLabel('Samples  ·  reps  ·  name'),
              ..._sampleFields(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _totalsRow() {
    final total = _totalReps;
    final over = total > _includedCount;
    final color = over
        ? AppDS.red
        : (total == 0 ? context.appTextMuted : AppDS.green);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          '$_includedCount wells available · ',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 11,
            color: context.appTextMuted,
          ),
        ),
        Text(
          '$total required',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _controlsWarning() => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
      border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.warning_amber_rounded,
          size: 16,
          color: Color(0xFFF59E0B),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Always include positive and negative controls on the plate.',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 11.5,
              color: const Color(0xFFF59E0B),
              height: 1.35,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _sampleCountRow() {
    final maxN = _includedCount < 1 ? 1 : _includedCount;
    final divisions = maxN > 1 ? maxN - 1 : 1;
    return Row(
      children: [
        _roundIconBtn(
          Icons.remove_rounded,
          () => _setUniqueCount(_uniqueCount - 1),
        ),
        Expanded(
          child: Slider(
            activeColor: _accent,
            inactiveColor: context.appBorder,
            min: 1,
            max: maxN.toDouble(),
            divisions: divisions,
            value: _uniqueCount.toDouble().clamp(1, maxN.toDouble()),
            onChanged: (v) => _setUniqueCount(v.round()),
          ),
        ),
        _roundIconBtn(
          Icons.add_rounded,
          () => _setUniqueCount(_uniqueCount + 1),
        ),
        const SizedBox(width: 6),
        Container(
          width: 42,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: context.appSurface2,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: context.appBorder),
          ),
          child: Text(
            '$_uniqueCount',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.appTextPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _replicatesRow() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Replicates (default)',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.appTextPrimary,
                ),
              ),
              Text(
                'Applied to all samples — override per-sample below',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 11,
                  color: context.appTextMuted,
                ),
              ),
            ],
          ),
        ),
        _roundIconBtn(
          Icons.remove_rounded,
          () => _setDefaultReps(_defaultReps - 1),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 54,
          child: TextField(
            controller: _defaultRepsCtrl,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: GoogleFonts.jetBrainsMono(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: context.appTextPrimary,
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              filled: true,
              fillColor: context.appSurface2,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: context.appBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: context.appBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: _accent),
              ),
            ),
            onSubmitted: (v) => _setDefaultReps(int.tryParse(v) ?? 1),
          ),
        ),
        const SizedBox(width: 6),
        _roundIconBtn(
          Icons.add_rounded,
          () => _setDefaultReps(_defaultReps + 1),
        ),
      ],
    );
  }

  Widget _maskToggleRow() => Row(
    children: [
      Switch(
        value: _masked,
        activeThumbColor: _accent,
        onChanged: (v) => setState(() => _masked = v),
      ),
      const SizedBox(width: 4),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Masking',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.appTextPrimary,
              ),
            ),
            Text(
              _masked
                  ? 'Plate shows masked IDs (A1, A2…)'
                  : 'Plate shows sample names',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 11,
                color: context.appTextMuted,
              ),
            ),
          ],
        ),
      ),
    ],
  );

  List<Widget> _sampleFields() => List.generate(_uniqueCount, (i) {
    final color = _sampleColor(i);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 44,
            padding: const EdgeInsets.symmetric(vertical: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color.withValues(alpha: 0.6)),
            ),
            child: Text(
              _maskedId(i),
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 44,
            child: TextField(
              controller: _repCtrls[i],
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: context.appTextPrimary,
              ),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                filled: true,
                fillColor: context.appSurface2,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: context.appBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: context.appBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: color),
                ),
              ),
              onChanged: (_) => setState(() => _assignment.clear()),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: _names[i],
              style: GoogleFonts.spaceGrotesk(
                fontSize: 13,
                color: context.appTextPrimary,
              ),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Sample ${i + 1}',
                hintStyle: GoogleFonts.spaceGrotesk(
                  fontSize: 12,
                  color: context.appTextMuted,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                filled: true,
                fillColor: context.appSurface2,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: context.appBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: context.appBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: color),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ],
      ),
    );
  });

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text.toUpperCase(),
      style: GoogleFonts.spaceGrotesk(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
        color: context.appTextMuted,
      ),
    ),
  );

  Widget _roundIconBtn(IconData icon, VoidCallback onTap) => Material(
    color: context.appSurface2,
    borderRadius: BorderRadius.circular(6),
    child: InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: context.appBorder),
        ),
        child: Icon(icon, size: 16, color: context.appTextPrimary),
      ),
    ),
  );

  Widget _chipBtn(String label, VoidCallback onTap) => Material(
    color: context.appSurface2,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.appBorder),
        ),
        child: Text(
          label,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: context.appTextPrimary,
          ),
        ),
      ),
    ),
  );

  Widget _buildPlate() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'Plate layout',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.appTextPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${_assignment.length}/$_totalReps assigned',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: (_cols + 1) / (_rows + 1),
                child: RepaintBoundary(
                  key: _plateKey,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: context.appSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.appBorder),
                    ),
                    child: _plateGrid(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _plateGrid() {
    return LayoutBuilder(
      builder: (ctx, cons) {
        final cellSize = min(
          cons.maxWidth / (_cols + 1),
          cons.maxHeight / (_rows + 1),
        );
        return Center(
          child: SizedBox(
            width: cellSize * (_cols + 1),
            height: cellSize * (_rows + 1),
            child: Column(
              children: [
                SizedBox(
                  height: cellSize,
                  child: Row(
                    children: [
                      SizedBox(width: cellSize),
                      ...List.generate(
                        _cols,
                        (c) => SizedBox(
                          width: cellSize,
                          height: cellSize,
                          child: Center(
                            child: Text(
                              '${c + 1}',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: cellSize * 0.28,
                                fontWeight: FontWeight.w600,
                                color: context.appTextMuted,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                ...List.generate(
                  _rows,
                  (r) => SizedBox(
                    height: cellSize,
                    child: Row(
                      children: [
                        SizedBox(
                          width: cellSize,
                          height: cellSize,
                          child: Center(
                            child: Text(
                              String.fromCharCode(65 + r),
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: cellSize * 0.28,
                                fontWeight: FontWeight.w600,
                                color: context.appTextMuted,
                              ),
                            ),
                          ),
                        ),
                        ...List.generate(_cols, (c) {
                          final id = _wellId(r, c);
                          final idx = _assignment[id];
                          return _Well(
                            size: cellSize,
                            excluded: _excluded.contains(id),
                            label: _labelForWell(id),
                            color: idx == null ? null : _sampleColor(idx),
                            onTap: () => _toggleWell(id),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Well extends StatelessWidget {
  final double size;
  final bool excluded;
  final String label;
  final Color? color;
  final VoidCallback onTap;
  const _Well({
    required this.size,
    required this.excluded,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final filled = label.isNotEmpty && color != null;
    final Color bg;
    final Color border;
    final Color textColor;
    if (excluded) {
      bg = context.appSurface2.withValues(alpha: 0.4);
      border = context.appBorder;
      textColor = context.appTextMuted;
    } else if (filled) {
      bg = color!.withValues(alpha: 0.75);
      border = color!;
      textColor = Colors.black;
    } else {
      bg = context.appSurface2;
      border = context.appBorder;
      textColor = context.appTextMuted;
    }
    return SizedBox(
      width: size,
      height: size,
      child: Padding(
        padding: EdgeInsets.all(size * 0.08),
        child: Material(
          color: bg,
          shape: CircleBorder(side: BorderSide(color: border, width: 1.4)),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Center(
              child: excluded
                  ? Icon(
                      Icons.close_rounded,
                      size: size * 0.42,
                      color: context.appTextMuted,
                    )
                  : filled
                  ? Padding(
                      padding: EdgeInsets.all(size * 0.08),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: size * 0.30,
                            fontWeight: FontWeight.w900,
                            color: textColor,
                            height: 1.1,
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }
}
