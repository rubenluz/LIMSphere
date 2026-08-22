import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:limsphere/theme/grid_widgets.dart';

void main() {
  testWidgets('column resize handle reports drag updates and completion', (
    tester,
  ) async {
    var draggedBy = 0.0;
    var dragEnded = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 12,
              height: 40,
              child: AppColumnResizeHandle(
                onDrag: (delta) => draggedBy += delta,
                onDragEnd: () => dragEnded = true,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.drag(find.byType(AppColumnResizeHandle), const Offset(30, 0));
    await tester.pump();

    expect(draggedBy, greaterThan(0));
    expect(dragEnded, isTrue);
  });
}
