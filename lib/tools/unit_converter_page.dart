import 'package:flutter/material.dart';

import 'lab_tool_widgets.dart';
import 'lab_tools_calculations.dart';

class UnitConverterPage extends StatefulWidget {
  const UnitConverterPage({super.key});

  @override
  State<UnitConverterPage> createState() => _UnitConverterPageState();
}

class _UnitConverterPageState extends State<UnitConverterPage> {
  static const _accent = Color(0xFFF97316);
  final _valueController = TextEditingController(text: '1');
  int _groupIndex = 0;
  late String _fromUnit;
  late String _toUnit;

  LabUnitGroup get _group => labUnitGroups[_groupIndex];

  @override
  void initState() {
    super.initState();
    _fromUnit = _group.units.first;
    _toUnit = _group.units[1];
  }

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  void _selectGroup(int? index) {
    if (index == null) return;
    setState(() {
      _groupIndex = index;
      _fromUnit = _group.units.first;
      _toUnit = _group.units.length > 1 ? _group.units[1] : _group.units.first;
    });
  }

  void _reset() {
    _valueController.text = '1';
    setState(() {
      _groupIndex = 0;
      _fromUnit = _group.units.first;
      _toUnit = _group.units[1];
    });
  }

  ({double? value, String? error}) get _conversion {
    final input = parseLabNumber(_valueController.text);
    if (input == null) return (value: null, error: 'Enter a valid number.');
    try {
      return (
        value: convertLabUnit(
          value: input,
          group: _group,
          from: _fromUnit,
          to: _toUnit,
        ),
        error: null,
      );
    } on FormatException catch (error) {
      return (value: null, error: error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final conversion = _conversion;
    return LabToolPage(
      title: 'Units Converter',
      subtitle: 'Convert common laboratory mass, volume, amount, concentration, and temperature units.',
      icon: Icons.swap_horiz_rounded,
      accent: _accent,
      actions: [
        IconButton(
          tooltip: 'Reset',
          onPressed: _reset,
          icon: const Icon(Icons.restart_alt_rounded),
        ),
      ],
      child: LayoutBuilder(
        builder: (context, constraints) {
          final input = LabToolCard(
            title: 'Conversion',
            child: Column(
              children: [
                LabSelect<int>(
                  key: ValueKey(_groupIndex),
                  value: _groupIndex,
                  label: 'Measurement type',
                  values: List.generate(labUnitGroups.length, (index) => index),
                  labelOf: (index) => labUnitGroups[index].name,
                  onChanged: _selectGroup,
                ),
                const SizedBox(height: 13),
                LabNumberField(
                  controller: _valueController,
                  label: 'Value',
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 13),
                Row(
                  children: [
                    Expanded(
                      child: LabSelect<String>(
                        key: ValueKey('from-$_groupIndex-$_fromUnit'),
                        value: _fromUnit,
                        label: 'From',
                        values: _group.units,
                        labelOf: (unit) => unit,
                        onChanged: (unit) {
                          if (unit != null) setState(() => _fromUnit = unit);
                        },
                      ),
                    ),
                    IconButton(
                      tooltip: 'Swap units',
                      color: _accent,
                      onPressed: () => setState(() {
                        final oldFrom = _fromUnit;
                        _fromUnit = _toUnit;
                        _toUnit = oldFrom;
                      }),
                      icon: const Icon(Icons.swap_horiz_rounded),
                    ),
                    Expanded(
                      child: LabSelect<String>(
                        key: ValueKey('to-$_groupIndex-$_toUnit'),
                        value: _toUnit,
                        label: 'To',
                        values: _group.units,
                        labelOf: (unit) => unit,
                        onChanged: (unit) {
                          if (unit != null) setState(() => _toUnit = unit);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );

          final result = LabToolCard(
            title: 'Result',
            child: conversion.error != null
                ? _ErrorText(conversion.error!)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: _accent.withValues(alpha: .1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _accent.withValues(alpha: .3),
                          ),
                        ),
                        child: SelectableText(
                          '${formatLabNumber(conversion.value!)} $_toUnit',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: _accent,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${formatLabNumber(parseLabNumber(_valueController.text)!)} $_fromUnit = '
                        '${formatLabNumber(conversion.value!)} $_toUnit',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
          );

          if (constraints.maxWidth < 720) {
            return Column(
              children: [input, const SizedBox(height: 14), result],
            );
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
      ),
    );
  }
}

class _ErrorText extends StatelessWidget {
  final String message;
  const _ErrorText(this.message);

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
