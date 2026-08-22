import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:limsphere/dashboard/global_search.dart';

void main() {
  group('GlobalSearchService.normalizeQuery', () {
    test('trims and collapses whitespace', () {
      expect(
        GlobalSearchService.normalizeQuery('  green   algae  '),
        'green algae',
      );
    });

    test('removes PostgREST OR syntax and wildcard characters', () {
      expect(
        GlobalSearchService.normalizeQuery('abc),id.eq.1%_*'),
        'abc id.eq.1',
      );
    });
  });

  test('global results rank identity prefixes before incidental matches', () {
    const prefix = GlobalSearchResult(
      type: 'strains',
      id: 1,
      category: 'Strain',
      title: 'BACA0001',
      subtitle: 'Kamptonema animale',
    );
    const incidental = GlobalSearchResult(
      type: 'sops',
      id: 2,
      category: 'SOP',
      title: 'Microscopy procedure',
    );

    expect(GlobalSearchService.resultRelevance(prefix, 'kamptonem'), 1);
    expect(GlobalSearchService.resultRelevance(incidental, 'kamptonem'), 4);
  });

  testWidgets('clicking an overlay result opens it', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    GlobalSearchResult? opened;
    const result = GlobalSearchResult(
      type: 'samples',
      id: 7,
      category: 'Sample',
      title: 'Sample 7',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: DashboardGlobalSearch(
                searchOverride: (_) async => const [result],
                openOverride: (value) async => opened = value,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'sample');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Sample 7'), findsOneWidget);

    await tester.tap(find.text('Sample 7'));
    await tester.pumpAndSettle();
    debugDefaultTargetPlatformOverride = null;

    expect(opened, same(result));
    expect(find.text('Sample 7'), findsNothing);
  });

  testWidgets('desktop pointer-down opens before the overlay can dismiss', (
    tester,
  ) async {
    GlobalSearchResult? opened;
    const result = GlobalSearchResult(
      type: 'fish_stocks',
      id: 12,
      category: 'Fish tank',
      title: 'Tank 12',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: DashboardGlobalSearch(
              searchOverride: (_) async => const [result],
              openOverride: (value) async => opened = value,
            ),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'tank');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.set_meal_outlined), findsOneWidget);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Tank 12')),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    expect(opened, same(result));
    await gesture.up();
    await tester.pumpAndSettle();
  });
}
