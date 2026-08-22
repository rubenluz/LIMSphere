import 'package:flutter/material.dart';

import 'lab_tool_widgets.dart';
import 'lab_tools_calculations.dart';

class SerialDilutionPage extends StatefulWidget {
  const SerialDilutionPage({super.key});

  @override
  State<SerialDilutionPage> createState() => _SerialDilutionPageState();
}

class _SerialDilutionPageState extends State<SerialDilutionPage> {
  static const _accent = Color(0xFF38BDF8);
  final _startingController = TextEditingController(text: '100');
  final _factorController = TextEditingController(text: '10');
  final _stepsController = TextEditingController(text: '6');
  final _volumeController = TextEditingController(text: '1000');
  String _concentrationUnit = 'µM';
  String _volumeUnit = 'µL';

  LabUnitGroup get _volumeGroup => labUnitGroups[1];

  @override
  void dispose() {
    _startingController.dispose();
    _factorController.dispose();
    _stepsController.dispose();
    _volumeController.dispose();
    super.dispose();
  }

  void _reset() {
    _startingController.text = '100';
    _factorController.text = '10';
    _stepsController.text = '6';
    _volumeController.text = '1000';
    setState(() {
      _concentrationUnit = 'µM';
      _volumeUnit = 'µL';
    });
  }

  ({List<SerialDilutionStep>? steps, String? error}) get _plan {
    final starting = parseLabNumber(_startingController.text);
    final factor = parseLabNumber(_factorController.text);
    final stepValue = parseLabNumber(_stepsController.text);
    final volume = parseLabNumber(_volumeController.text);
    if (starting == null ||
        factor == null ||
        stepValue == null ||
        volume == null) {
      return (steps: null, error: 'Complete all numeric fields.');
    }
    if (stepValue != stepValue.roundToDouble()) {
      return (steps: null, error: 'Number of steps must be a whole number.');
    }
    try {
      return (
        steps: calculateSerialDilution(
          startingConcentration: starting,
          dilutionFactor: factor,
          steps: stepValue.toInt(),
          mixedVolume: volume,
        ),
        error: null,
      );
    } on FormatException catch (error) {
      return (steps: null, error: error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    return LabToolPage(
      title: 'Serial Dilution Planner',
      subtitle: 'Plan equal-factor serial dilutions. “Mixed volume” is the volume in each tube immediately after mixing.',
      icon: Icons.opacity_outlined,
      accent: _accent,
      actions: [
        IconButton(
          tooltip: 'Reset',
          onPressed: _reset,
          icon: const Icon(Icons.restart_alt_rounded),
        ),
      ],
      child: Column(
        children: [
          LabToolCard(
            title: 'Series settings',
            child: LayoutBuilder(
              builder: (_, constraints) {
                final fields = <Widget>[
                  _fieldWithUnit(
                    controller: _startingController,
                    label: 'Starting concentration',
                    unit: _concentrationUnit,
                    units: dilutionConcentrationUnits,
                    onUnit: (value) =>
                        setState(() => _concentrationUnit = value),
                  ),
                  LabNumberField(
                    controller: _factorController,
                    label: 'Dilution factor',
                    hint: 'e.g. 10 for 1:10',
                    onChanged: (_) => setState(() {}),
                  ),
                  LabNumberField(
                    controller: _stepsController,
                    label: 'Number of steps',
                    onChanged: (_) => setState(() {}),
                  ),
                  _fieldWithUnit(
                    controller: _volumeController,
                    label: 'Mixed volume per step',
                    unit: _volumeUnit,
                    units: _volumeGroup.units,
                    onUnit: (value) => setState(() => _volumeUnit = value),
                  ),
                ];
                final columns = constraints.maxWidth >= 860
                    ? 4
                    : constraints.maxWidth >= 520
                    ? 2
                    : 1;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final field in fields)
                      SizedBox(
                        width:
                            (constraints.maxWidth - (columns - 1) * 12) /
                            columns,
                        child: field,
                      ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          if (plan.error != null)
            LabToolCard(title: 'Plan', child: _PlanError(plan.error!))
          else ...[
            _buildSummary(plan.steps!),
            const SizedBox(height: 14),
            _buildTable(plan.steps!),
            const SizedBox(height: 14),
            _buildInstructions(plan.steps!),
          ],
        ],
      ),
    );
  }

  Widget _fieldWithUnit({
    required TextEditingController controller,
    required String label,
    required String unit,
    required List<String> units,
    required ValueChanged<String> onUnit,
  }) => Row(
    children: [
      Expanded(
        flex: 2,
        child: LabNumberField(
          controller: controller,
          label: label,
          onChanged: (_) => setState(() {}),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: LabSelect<String>(
          key: ValueKey('$label-$unit'),
          value: unit,
          label: 'Unit',
          values: units,
          labelOf: (value) => value,
          onChanged: (value) {
            if (value != null) onUnit(value);
          },
        ),
      ),
    ],
  );

  Widget _buildSummary(List<SerialDilutionStep> steps) {
    final first = steps.first;
    return LabToolCard(
      title: 'Volumes summary',
      child: Wrap(
        spacing: 22,
        runSpacing: 8,
        children: [
          _summaryItem(
            'Transfer each step',
            '${formatLabNumber(first.transferVolume)} $_volumeUnit',
          ),
          _summaryItem(
            'Diluent per tube',
            '${formatLabNumber(first.diluentVolume)} $_volumeUnit',
          ),
          _summaryItem(
            'Total diluent',
            '${formatLabNumber(first.diluentVolume * steps.length)} $_volumeUnit',
          ),
          _summaryItem('New tip recommended', '${steps.length} tips'),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value) => SizedBox(
    width: 210,
    child: LabResultRow(label: label, value: value, valueColor: _accent),
  );

  Widget _buildTable(List<SerialDilutionStep> steps) => LabToolCard(
    title: 'Dilution series',
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 40,
        dataRowMinHeight: 38,
        dataRowMaxHeight: 44,
        columns: const [
          DataColumn(label: Text('Tube')),
          DataColumn(label: Text('Cumulative dilution')),
          DataColumn(label: Text('Concentration')),
          DataColumn(label: Text('Transfer in')),
          DataColumn(label: Text('Diluent')),
          DataColumn(label: Text('Remaining after transfer')),
        ],
        rows: [
          for (final step in steps)
            DataRow(
              cells: [
                DataCell(Text('${step.step}')),
                DataCell(Text('1:${formatLabNumber(step.cumulativeDilution)}')),
                DataCell(
                  Text(
                    '${formatLabNumber(step.concentration)} $_concentrationUnit',
                  ),
                ),
                DataCell(
                  Text('${formatLabNumber(step.transferVolume)} $_volumeUnit'),
                ),
                DataCell(
                  Text('${formatLabNumber(step.diluentVolume)} $_volumeUnit'),
                ),
                DataCell(
                  Text(
                    '${formatLabNumber(step.remainingAfterTransfer)} $_volumeUnit',
                  ),
                ),
              ],
            ),
        ],
      ),
    ),
  );

  Widget _buildInstructions(List<SerialDilutionStep> steps) {
    final first = steps.first;
    return LabToolCard(
      title: 'Procedure',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '1. Add ${formatLabNumber(first.diluentVolume)} $_volumeUnit diluent to every tube.',
          ),
          const SizedBox(height: 7),
          Text(
            '2. Transfer ${formatLabNumber(first.transferVolume)} $_volumeUnit from the stock into tube 1 and mix thoroughly.',
          ),
          const SizedBox(height: 7),
          Text(
            '3. Transfer the same volume from each mixed tube into the next tube, using a fresh tip each time.',
          ),
          const SizedBox(height: 7),
          Text(
            '4. Do not transfer out of tube ${steps.length}; it retains the full mixed volume.',
          ),
        ],
      ),
    );
  }
}

class _PlanError extends StatelessWidget {
  final String message;
  const _PlanError(this.message);

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 18),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          message,
          style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12),
        ),
      ),
    ],
  );
}
