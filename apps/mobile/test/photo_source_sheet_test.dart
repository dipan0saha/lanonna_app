import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/media/display_encode.dart';
import 'package:lanonna/features/gallery/presentation/sheets/photo_source_sheet.dart';

void main() {
  testWidgets('photo source sheet shows size hint from display constants', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showPhotoSourceSheet(context),
                  child: const Text('Open'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Add a Photo'), findsOneWidget);
    expect(find.text(displayPhotoSourceHint()), findsOneWidget);
    expect(find.text('Take photo'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
  });
}
