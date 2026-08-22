import 'package:flutter_test/flutter_test.dart';
import 'package:limsphere/tools/lab_tools_calculations.dart';

void main() {
  group('unit conversion', () {
    test('converts mass, volume, and concentration units', () {
      expect(
        convertLabUnit(value: 1, group: labUnitGroups[0], from: 'g', to: 'mg'),
        1000,
      );
      expect(
        convertLabUnit(
          value: 250,
          group: labUnitGroups[1],
          from: 'µL',
          to: 'mL',
        ),
        closeTo(.25, 1e-12),
      );
      expect(
        convertLabUnit(value: 2, group: labUnitGroups[3], from: 'mM', to: 'µM'),
        closeTo(2000, 1e-9),
      );
      expect(
        convertLabUnit(
          value: 10,
          group: concentrationGroupForUnit('mg/mL'),
          from: 'mg/mL',
          to: 'µg/mL',
        ),
        10000,
      );
      expect(
        convertLabUnit(
          value: 1,
          group: concentrationGroupForUnit('µL/mL'),
          from: 'µL/mL',
          to: 'mL/mL',
        ),
        .001,
      );
    });

    test('converts temperatures', () {
      expect(
        convertLabUnit(value: 0, group: labUnitGroups[5], from: '°C', to: '°F'),
        closeTo(32, 1e-12),
      );
      expect(
        convertLabUnit(
          value: 273.15,
          group: labUnitGroups[5],
          from: 'K',
          to: '°C',
        ),
        closeTo(0, 1e-12),
      );
      expect(
        () => convertLabUnit(
          value: -1,
          group: labUnitGroups[5],
          from: 'K',
          to: '°C',
        ),
        throwsFormatException,
      );
    });
  });

  test('calculates C1V1 dilution volumes', () {
    final result = calculateDilution(
      stockConcentration: 100,
      targetConcentration: 10,
      finalVolume: 50,
    );

    expect(result.stockVolume, 5);
    expect(result.diluentVolume, 45);
  });

  test('calculates molarity and required mass as inverse operations', () {
    final mass = calculateRequiredMass(
      molarity: .1,
      molecularWeight: 180.16,
      volumeLiters: .25,
    );
    final molarity = calculateMolarity(
      massGrams: mass,
      molecularWeight: 180.16,
      volumeLiters: .25,
    );

    expect(mass, closeTo(4.504, 1e-12));
    expect(molarity, closeTo(.1, 1e-12));
  });

  test('builds a serial dilution plan', () {
    final steps = calculateSerialDilution(
      startingConcentration: 100,
      dilutionFactor: 10,
      steps: 3,
      mixedVolume: 1000,
    );

    expect(steps, hasLength(3));
    expect(steps.first.concentration, 10);
    expect(steps.last.concentration, closeTo(.1, 1e-12));
    expect(steps.first.transferVolume, 100);
    expect(steps.first.diluentVolume, 900);
    expect(steps.first.remainingAfterTransfer, 900);
    expect(steps.last.remainingAfterTransfer, 1000);
  });

  test('rejects impossible dilution settings', () {
    expect(
      () => calculateDilution(
        stockConcentration: 10,
        targetConcentration: 20,
        finalVolume: 1,
      ),
      throwsFormatException,
    );
    expect(
      () => calculateSerialDilution(
        startingConcentration: 10,
        dilutionFactor: 1,
        steps: 2,
        mixedVolume: 1,
      ),
      throwsFormatException,
    );
  });

  test('formats whole dilution ratios without removing significant zeroes', () {
    expect(formatLabNumber(1000000), '1000000');
    expect(formatLabNumber(1000), '1000');
  });
}
