import 'dart:math' as math;

class LabUnitGroup {
  final String name;
  final List<String> units;
  final Map<String, double> factors;

  const LabUnitGroup({
    required this.name,
    required this.units,
    required this.factors,
  });
}

const labUnitGroups = <LabUnitGroup>[
  LabUnitGroup(
    name: 'Mass',
    units: ['kg', 'g', 'mg', 'µg', 'ng'],
    factors: {'kg': 1000, 'g': 1, 'mg': 1e-3, 'µg': 1e-6, 'ng': 1e-9},
  ),
  LabUnitGroup(
    name: 'Volume',
    units: ['L', 'mL', 'µL', 'nL'],
    factors: {'L': 1, 'mL': 1e-3, 'µL': 1e-6, 'nL': 1e-9},
  ),
  LabUnitGroup(
    name: 'Amount',
    units: ['mol', 'mmol', 'µmol', 'nmol'],
    factors: {'mol': 1, 'mmol': 1e-3, 'µmol': 1e-6, 'nmol': 1e-9},
  ),
  LabUnitGroup(
    name: 'Molar concentration',
    units: ['M', 'mM', 'µM', 'nM'],
    factors: {'M': 1, 'mM': 1e-3, 'µM': 1e-6, 'nM': 1e-9},
  ),
  LabUnitGroup(
    name: 'Mass concentration',
    units: ['g/L', 'mg/mL', 'mg/L', 'µg/mL', 'µg/L', 'ng/mL'],
    factors: {
      'g/L': 1,
      'mg/mL': 1,
      'mg/L': 1e-3,
      'µg/mL': 1e-3,
      'µg/L': 1e-6,
      'ng/mL': 1e-6,
    },
  ),
  LabUnitGroup(name: 'Temperature', units: ['°C', '°F', 'K'], factors: {}),
];

const volumeConcentrationUnitGroup = LabUnitGroup(
  name: 'Volume concentration',
  units: ['mL/mL', 'µL/mL'],
  factors: {'mL/mL': 1, 'µL/mL': 1e-3},
);

const dilutionConcentrationUnits = <String>[
  'M',
  'mM',
  'µM',
  'nM',
  'g/L',
  'mg/mL',
  'mg/L',
  'µg/mL',
  'µg/L',
  'ng/mL',
  'mL/mL',
  'µL/mL',
];

LabUnitGroup concentrationGroupForUnit(String unit) {
  for (final group in [labUnitGroups[3], labUnitGroups[4]]) {
    if (group.units.contains(unit)) return group;
  }
  if (volumeConcentrationUnitGroup.units.contains(unit)) {
    return volumeConcentrationUnitGroup;
  }
  throw const FormatException('Unknown concentration unit.');
}

double convertLabUnit({
  required double value,
  required LabUnitGroup group,
  required String from,
  required String to,
}) {
  if (!value.isFinite) throw const FormatException('Enter a finite value.');
  if (!group.units.contains(from) || !group.units.contains(to)) {
    throw const FormatException('Select compatible units.');
  }
  if (group.name == 'Temperature') {
    final celsius = switch (from) {
      '°C' => value,
      '°F' => (value - 32) * 5 / 9,
      'K' => value - 273.15,
      _ => throw const FormatException('Unknown temperature unit.'),
    };
    if (celsius < -273.15) {
      throw const FormatException('Temperature cannot be below absolute zero.');
    }
    return switch (to) {
      '°C' => celsius,
      '°F' => celsius * 9 / 5 + 32,
      'K' => celsius + 273.15,
      _ => throw const FormatException('Unknown temperature unit.'),
    };
  }
  return value * group.factors[from]! / group.factors[to]!;
}

class DilutionResult {
  final double stockVolume;
  final double diluentVolume;

  const DilutionResult({
    required this.stockVolume,
    required this.diluentVolume,
  });
}

DilutionResult calculateDilution({
  required double stockConcentration,
  required double targetConcentration,
  required double finalVolume,
}) {
  if (!stockConcentration.isFinite || stockConcentration <= 0) {
    throw const FormatException('Stock concentration must be greater than 0.');
  }
  if (!targetConcentration.isFinite || targetConcentration < 0) {
    throw const FormatException('Target concentration cannot be negative.');
  }
  if (targetConcentration > stockConcentration) {
    throw const FormatException(
      'Target concentration cannot exceed the stock concentration.',
    );
  }
  if (!finalVolume.isFinite || finalVolume <= 0) {
    throw const FormatException('Final volume must be greater than 0.');
  }
  final stockVolume = targetConcentration * finalVolume / stockConcentration;
  return DilutionResult(
    stockVolume: stockVolume,
    diluentVolume: finalVolume - stockVolume,
  );
}

double calculateMolarity({
  required double massGrams,
  required double molecularWeight,
  required double volumeLiters,
}) {
  if (!massGrams.isFinite || massGrams < 0) {
    throw const FormatException('Mass cannot be negative.');
  }
  if (!molecularWeight.isFinite || molecularWeight <= 0) {
    throw const FormatException('Molecular weight must be greater than 0.');
  }
  if (!volumeLiters.isFinite || volumeLiters <= 0) {
    throw const FormatException('Volume must be greater than 0.');
  }
  return massGrams / molecularWeight / volumeLiters;
}

double calculateRequiredMass({
  required double molarity,
  required double molecularWeight,
  required double volumeLiters,
}) {
  if (!molarity.isFinite || molarity < 0) {
    throw const FormatException('Molarity cannot be negative.');
  }
  if (!molecularWeight.isFinite || molecularWeight <= 0) {
    throw const FormatException('Molecular weight must be greater than 0.');
  }
  if (!volumeLiters.isFinite || volumeLiters <= 0) {
    throw const FormatException('Volume must be greater than 0.');
  }
  return molarity * molecularWeight * volumeLiters;
}

class SerialDilutionStep {
  final int step;
  final double concentration;
  final double cumulativeDilution;
  final double transferVolume;
  final double diluentVolume;
  final double remainingAfterTransfer;

  const SerialDilutionStep({
    required this.step,
    required this.concentration,
    required this.cumulativeDilution,
    required this.transferVolume,
    required this.diluentVolume,
    required this.remainingAfterTransfer,
  });
}

List<SerialDilutionStep> calculateSerialDilution({
  required double startingConcentration,
  required double dilutionFactor,
  required int steps,
  required double mixedVolume,
}) {
  if (!startingConcentration.isFinite || startingConcentration <= 0) {
    throw const FormatException(
      'Starting concentration must be greater than 0.',
    );
  }
  if (!dilutionFactor.isFinite || dilutionFactor <= 1) {
    throw const FormatException('Dilution factor must be greater than 1.');
  }
  if (steps < 1 || steps > 100) {
    throw const FormatException('Steps must be between 1 and 100.');
  }
  if (!mixedVolume.isFinite || mixedVolume <= 0) {
    throw const FormatException('Mixed volume must be greater than 0.');
  }

  final transferVolume = mixedVolume / dilutionFactor;
  final diluentVolume = mixedVolume - transferVolume;
  return List.generate(steps, (index) {
    final step = index + 1;
    final cumulative = math.pow(dilutionFactor, step).toDouble();
    if (!cumulative.isFinite) {
      throw const FormatException(
        'This factor and step count produce a series that is too large.',
      );
    }
    return SerialDilutionStep(
      step: step,
      concentration: startingConcentration / cumulative,
      cumulativeDilution: cumulative,
      transferVolume: transferVolume,
      diluentVolume: diluentVolume,
      remainingAfterTransfer: step == steps
          ? mixedVolume
          : mixedVolume - transferVolume,
    );
  });
}

String formatLabNumber(double value, {int significantDigits = 6}) {
  if (value == 0) return '0';
  final abs = value.abs();
  if (abs > 1e6 || abs < 1e-4) {
    return value.toStringAsExponential(significantDigits - 1);
  }
  final integerDigits = abs >= 1 ? (math.log(abs) / math.ln10).floor() + 1 : 0;
  final decimals = (significantDigits - integerDigits).clamp(0, 10);
  final fixed = value.toStringAsFixed(decimals);
  if (decimals == 0) return fixed;
  return fixed
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}
