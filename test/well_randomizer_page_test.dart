import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:limsphere/tools/well_randomizer_page.dart';

void main() {
  testWidgets('randomizer starts unmasked with controls at the top left', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: WellRandomizerPage()));
    await tester.pump();

    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    final plateName = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Plate name'),
    );
    expect(plateName.controller!.text, matches(r'^\d{8}_\d{4}$'));
    final plateNameTop = tester.getTopLeft(
      find.widgetWithText(TextField, 'Plate name'),
    );
    expect(plateNameTop.dy, lessThan(100));
    expect(plateNameTop.dx, lessThan(420));
    final warningTop = tester.getTopLeft(
      find.text('Always include positive and negative controls on the plate.'),
    );
    expect(warningTop.dy, lessThan(220));
  });

  testWidgets('CSV and PNG export do not require module permissions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: WellRandomizerPage()));
    await tester.tap(find.text('Randomize'));
    await tester.pump();

    final csvButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.table_chart_outlined),
    );
    final pngButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.image_outlined),
    );
    expect(csvButton.onPressed, isNotNull);
    expect(pngButton.onPressed, isNotNull);
  });
}
