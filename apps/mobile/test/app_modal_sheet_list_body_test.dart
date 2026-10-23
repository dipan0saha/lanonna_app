import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/widgets/app_modal_sheet.dart';

void main() {
  testWidgets('AppModalSheetListBody scrolls inside Flexible', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const SizedBox(height: 100),
              Flexible(
                child: AppModalSheetListBody(
                  children: List.generate(
                    40,
                    (i) => SizedBox(height: 48, child: Text('row $i')),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final listFinder = find.byType(ListView);
    expect(listFinder, findsOneWidget);
    final list = tester.widget<ListView>(listFinder);
    expect(list.physics, isNot(isA<NeverScrollableScrollPhysics>()));
    expect(list.shrinkWrap, isFalse);

    await tester.drag(listFinder, const Offset(0, -400));
    await tester.pump();
    expect(find.text('row 20'), findsOneWidget);
  });
}
