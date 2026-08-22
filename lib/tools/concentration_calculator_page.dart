import 'package:flutter/material.dart';

import 'lab_tool_widgets.dart';
import 'lab_tools_calculations.dart';

enum _ConcentrationMode { dilution, molarity, requiredMass }

class ConcentrationCalculatorPage extends StatefulWidget {
  const ConcentrationCalculatorPage({super.key});

  @override
  State<ConcentrationCalculatorPage> createState() =>
      _ConcentrationCalculatorPageState();
}

class _ConcentrationCalculatorPageState
    extends State<ConcentrationCalculatorPage> {
  static const _accent = Color(0xFF22C55E);
  final _stockController = TextEditingController(text: '10');
  final _targetController = TextEditingController(text: '25');
  final _finalVolumeController = TextEditingController(text: '200');
  final _massController = TextEditingController(text: '1');
  final _molecularWeightController = TextEditingController(text: '180.16');
  final _solutionVolumeController = TextEditingController(text: '100');
  final _requiredMolarityController = TextEditingController(text: '100');

  _ConcentrationMode _mode = _ConcentrationMode.dilution;
  String _stockUnit = 'mg/mL';
  String _targetUnit = 'µg/mL';
  String _finalVolumeUnit = 'µL';
  String _massUnit = 'mg';
  String _solutionVolumeUnit = 'mL';
  String _requiredMolarityUnit = 'mM';

  LabUnitGroup get _molarGroup => labUnitGroups[3];
  LabUnitGroup get _massGroup => labUnitGroups[0];
  LabUnitGroup get _volumeGroup => labUnitGroups[1];

  @override
  void dispose() {
    for (final controller in [
      _stockController,
      _targetController,
      _finalVolumeController,
      _massController,
      _molecularWeightController,
      _solutionVolumeController,
      _requiredMolarityController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _reset() {
    _stockController.text = '10';
    _targetController.text = '25';
    _finalVolumeController.text = '200';
    _massController.text = '1';
    _molecularWeightController.text = '180.16';
    _solutionVolumeController.text = '100';
    _requiredMolarityController.text = '100';
    setState(() {
      _stockUnit = 'mg/mL';
      _targetUnit = 'µg/mL';
      _finalVolumeUnit = 'µL';
      _massUnit = 'mg';
      _solutionVolumeUnit = 'mL';
      _requiredMolarityUnit = 'mM';
    });
  }

  @override
  Widget build(BuildContext context) {
    return LabToolPage(
      title: 'Concentration Calculator',
      subtitle: 'Prepare a dilution, calculate molarity from mass, or determine the mass required for a solution.',
      icon: Icons.calculate_outlined,
      accent: _accent,
      actions: [
        IconButton(
          tooltip: 'Reset current values',
          onPressed: _reset,
          icon: const Icon(Icons.restart_alt_rounded),
        ),
      ],
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<_ConcentrationMode>(
                segments: const [
                  ButtonSegment(
                    value: _ConcentrationMode.dilution,
                    label: Text('Dilution C₁V₁ = C₂V₂'),
                  ),
                  ButtonSegment(
                    value: _ConcentrationMode.molarity,
                    label: Text('Molarity from mass'),
                  ),
                  ButtonSegment(
                    value: _ConcentrationMode.requiredMass,
                    label: Text('Mass required'),
                  ),
                ],
                selected: {_mode},
                showSelectedIcon: false,
                onSelectionChanged: (selection) =>
                    setState(() => _mode = selection.first),
              ),
            ),
          ),
          const SizedBox(height: 14),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: KeyedSubtree(
              key: ValueKey(_mode),
              child: switch (_mode) {
                _ConcentrationMode.dilution => _buildDilution(context),
                _ConcentrationMode.molarity => _buildMolarity(context),
                _ConcentrationMode.requiredMass => _buildRequiredMass(context),
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _responsivePair(Widget input, Widget result) => LayoutBuilder(
    builder: (_, constraints) {
      if (constraints.maxWidth < 720) {
        return Column(children: [input, const SizedBox(height: 14), result]);
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: input),
          const SizedBox(width: 14),
          Expanded(child: result),
        ],
      );
    },
  );

  Widget _numberWithUnit({
    required TextEditingController controller,
    required String label,
    required String unit,
    required List<String> units,
    required ValueChanged<String> onUnit,
  }) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        flex: 2,
        child: LabNumberField(
          controller: controller,
          label: label,
          onChanged: (_) => setState(() {}),
        ),
      ),
      const SizedBox(width: 10),
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

  Widget _buildDilution(BuildContext context) {
    String? error;
    DilutionResult? result;
    String? workingSolutionAdvice;
    try {
      final stock = parseLabNumber(_stockController.text);
      final target = parseLabNumber(_targetController.text);
      final finalVolume = parseLabNumber(_finalVolumeController.text);
      if (stock == null || target == null || finalVolume == null) {
        throw const FormatException('Complete all numeric fields.');
      }
      final stockGroup = concentrationGroupForUnit(_stockUnit);
      final targetGroup = concentrationGroupForUnit(_targetUnit);
      if (stockGroup.name != targetGroup.name) {
        throw const FormatException(
          'Stock and target concentration units must be the same type.',
        );
      }
      result = calculateDilution(
        stockConcentration: convertLabUnit(
          value: stock,
          group: stockGroup,
          from: _stockUnit,
          to: stockGroup.units.first,
        ),
        targetConcentration: convertLabUnit(
          value: target,
          group: targetGroup,
          from: _targetUnit,
          to: targetGroup.units.first,
        ),
        finalVolume: finalVolume,
      );
      final stockVolumeMicroliters = convertLabUnit(
        value: result.stockVolume,
        group: _volumeGroup,
        from: _finalVolumeUnit,
        to: 'µL',
      );
      final finalVolumeMicroliters = convertLabUnit(
        value: finalVolume,
        group: _volumeGroup,
        from: _finalVolumeUnit,
        to: 'µL',
      );
      if (stockVolumeMicroliters > 0 &&
          stockVolumeMicroliters < 1 &&
          finalVolumeMicroliters >= 10) {
        final workingMultiplier = finalVolumeMicroliters / 10;
        final workingConcentration = target * workingMultiplier;
        final stockDilutionFactor = 10 / stockVolumeMicroliters;
        workingSolutionAdvice =
            'The direct stock volume is below 1 µL. Prepare a '
            '${formatLabNumber(workingConcentration)} $_targetUnit working '
            'solution by diluting the original stock 1:'
            '${formatLabNumber(stockDilutionFactor)} '
            '(1 part stock + ${formatLabNumber(stockDilutionFactor - 1)} parts '
            'diluent). Then add 10 µL working solution and '
            '${formatLabNumber(finalVolumeMicroliters - 10)} µL diluent.';
      }
    } on FormatException catch (exception) {
      error = exception.message;
    }

    final input = LabToolCard(
      title: 'Solution inputs',
      child: Column(
        children: [
          _numberWithUnit(
            controller: _stockController,
            label: 'Stock concentration (C₁)',
            unit: _stockUnit,
            units: dilutionConcentrationUnits,
            onUnit: (value) => setState(() => _stockUnit = value),
          ),
          const SizedBox(height: 12),
          _numberWithUnit(
            controller: _targetController,
            label: 'Target concentration (C₂)',
            unit: _targetUnit,
            units: dilutionConcentrationUnits,
            onUnit: (value) => setState(() => _targetUnit = value),
          ),
          const SizedBox(height: 12),
          _numberWithUnit(
            controller: _finalVolumeController,
            label: 'Final volume (V₂)',
            unit: _finalVolumeUnit,
            units: _volumeGroup.units,
            onUnit: (value) => setState(() => _finalVolumeUnit = value),
          ),
        ],
      ),
    );
    final output = LabToolCard(
      title: 'Preparation',
      child: error != null
          ? _ToolError(error)
          : Column(
              children: [
                LabResultRow(
                  label: 'Stock solution (V₁)',
                  value:
                      '${formatLabNumber(result!.stockVolume)} $_finalVolumeUnit',
                  valueColor: _accent,
                ),
                LabResultRow(
                  label: 'Diluent',
                  value:
                      '${formatLabNumber(result.diluentVolume)} $_finalVolumeUnit',
                ),
                LabResultRow(
                  label: 'Final volume',
                  value:
                      '${formatLabNumber(result.stockVolume + result.diluentVolume)} $_finalVolumeUnit',
                ),
                const Divider(height: 24),
                if (workingSolutionAdvice != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _accent.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      workingSolutionAdvice,
                      style: const TextStyle(fontSize: 12, height: 1.4),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  workingSolutionAdvice == null
                      ? 'Add the stock solution to the diluent and mix thoroughly.'
                      : 'Use the working solution volumes above and mix thoroughly.',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
    );
    return _responsivePair(input, output);
  }

  Widget _buildMolarity(BuildContext context) {
    String? error;
    double? molarity;
    try {
      final mass = parseLabNumber(_massController.text);
      final molecularWeight = parseLabNumber(_molecularWeightController.text);
      final volume = parseLabNumber(_solutionVolumeController.text);
      if (mass == null || molecularWeight == null || volume == null) {
        throw const FormatException('Complete all numeric fields.');
      }
      molarity = calculateMolarity(
        massGrams: convertLabUnit(
          value: mass,
          group: _massGroup,
          from: _massUnit,
          to: 'g',
        ),
        molecularWeight: molecularWeight,
        volumeLiters: convertLabUnit(
          value: volume,
          group: _volumeGroup,
          from: _solutionVolumeUnit,
          to: 'L',
        ),
      );
    } on FormatException catch (exception) {
      error = exception.message;
    }

    final input = LabToolCard(
      title: 'Solution inputs',
      child: Column(
        children: [
          _numberWithUnit(
            controller: _massController,
            label: 'Solute mass',
            unit: _massUnit,
            units: _massGroup.units,
            onUnit: (value) => setState(() => _massUnit = value),
          ),
          const SizedBox(height: 12),
          LabNumberField(
            controller: _molecularWeightController,
            label: 'Molecular weight',
            suffix: 'g/mol',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          _numberWithUnit(
            controller: _solutionVolumeController,
            label: 'Final solution volume',
            unit: _solutionVolumeUnit,
            units: _volumeGroup.units,
            onUnit: (value) => setState(() => _solutionVolumeUnit = value),
          ),
        ],
      ),
    );
    final output = LabToolCard(
      title: 'Molarity',
      child: error != null
          ? _ToolError(error)
          : Column(
              children: [
                LabResultRow(
                  label: 'Molar',
                  value: '${formatLabNumber(molarity!)} M',
                  valueColor: _accent,
                ),
                LabResultRow(
                  label: 'Millimolar',
                  value: '${formatLabNumber(molarity * 1000)} mM',
                ),
                LabResultRow(
                  label: 'Micromolar',
                  value: '${formatLabNumber(molarity * 1e6)} µM',
                ),
              ],
            ),
    );
    return _responsivePair(input, output);
  }

  Widget _buildRequiredMass(BuildContext context) {
    String? error;
    double? grams;
    try {
      final concentration = parseLabNumber(_requiredMolarityController.text);
      final molecularWeight = parseLabNumber(_molecularWeightController.text);
      final volume = parseLabNumber(_solutionVolumeController.text);
      if (concentration == null || molecularWeight == null || volume == null) {
        throw const FormatException('Complete all numeric fields.');
      }
      grams = calculateRequiredMass(
        molarity: convertLabUnit(
          value: concentration,
          group: _molarGroup,
          from: _requiredMolarityUnit,
          to: 'M',
        ),
        molecularWeight: molecularWeight,
        volumeLiters: convertLabUnit(
          value: volume,
          group: _volumeGroup,
          from: _solutionVolumeUnit,
          to: 'L',
        ),
      );
    } on FormatException catch (exception) {
      error = exception.message;
    }

    final input = LabToolCard(
      title: 'Target solution',
      child: Column(
        children: [
          _numberWithUnit(
            controller: _requiredMolarityController,
            label: 'Target molarity',
            unit: _requiredMolarityUnit,
            units: _molarGroup.units,
            onUnit: (value) => setState(() => _requiredMolarityUnit = value),
          ),
          const SizedBox(height: 12),
          LabNumberField(
            controller: _molecularWeightController,
            label: 'Molecular weight',
            suffix: 'g/mol',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          _numberWithUnit(
            controller: _solutionVolumeController,
            label: 'Final solution volume',
            unit: _solutionVolumeUnit,
            units: _volumeGroup.units,
            onUnit: (value) => setState(() => _solutionVolumeUnit = value),
          ),
        ],
      ),
    );
    final output = LabToolCard(
      title: 'Mass to weigh',
      child: error != null
          ? _ToolError(error)
          : Column(
              children: [
                LabResultRow(
                  label: 'Grams',
                  value: '${formatLabNumber(grams!)} g',
                  valueColor: _accent,
                ),
                LabResultRow(
                  label: 'Milligrams',
                  value: '${formatLabNumber(grams * 1000)} mg',
                ),
                LabResultRow(
                  label: 'Micrograms',
                  value: '${formatLabNumber(grams * 1e6)} µg',
                ),
              ],
            ),
    );
    return _responsivePair(input, output);
  }
}

class _ToolError extends StatelessWidget {
  final String message;
  const _ToolError(this.message);

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
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
