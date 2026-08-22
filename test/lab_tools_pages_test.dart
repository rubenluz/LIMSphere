import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:limsphere/tools/concentration_calculator_page.dart';
import 'package:limsphere/tools/serial_dilution_page.dart';
import 'package:limsphere/tools/unit_converter_page.dart';

void main() {
  testWidgets('unit converter renders a live conversion', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: UnitConverterPage()));
    await tester.pump();

    expect(find.text('1000 g'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('concentration calculator renders dilution volumes', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: ConcentrationCalculatorPage()),
    );
    await tester.pump();

    expect(find.text('0.5 µL'), findsOneWidget);
    expect(find.text('199.5 µL'), findsOneWidget);
    expect(find.textContaining('500 µg/mL working solution'), findsOneWidget);
    expect(find.textContaining('Then add 10 µL'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('serial dilution planner renders its complete series', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SerialDilutionPage()));
    await tester.pump();

    expect(find.text('Dilution series'), findsOneWidget);
    expect(find.text('1:1000000'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('remaining lab tools render on a narrow screen', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final page in const <Widget>[
      UnitConverterPage(),
      ConcentrationCalculatorPage(),
      SerialDilutionPage(),
    ]) {
      await tester.pumpWidget(MaterialApp(home: page));
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
  });
}
