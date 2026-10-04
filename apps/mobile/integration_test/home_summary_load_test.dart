import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lanonna/bootstrap.dart';
import 'package:lanonna/firebase_options.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('signed-in home loads home-summary (no error banner)', (tester) async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await tester.pumpWidget(await bootstrapLaNonnaApp());
    await tester.pumpAndSettle(const Duration(seconds: 30));

    expect(find.byKey(const Key('home_section_list')), findsOneWidget);

    // Summary failure shows MaterialBanner + Retry on home.
    expect(
      find.descendant(
        of: find.byKey(const Key('home_section_list')),
        matching: find.widgetWithText(MaterialBanner, ''),
      ),
      findsNothing,
    );
    final retryOnHome = find.descendant(
      of: find.byKey(const Key('home_section_list')),
      matching: find.text('Retry'),
    );
    expect(retryOnHome, findsNothing);

    final prdSection = find.byWidgetPredicate(
      (w) =>
          w is Text &&
          (w.data?.contains('Getting Started') == true ||
              w.data?.contains('Activity Recap') == true ||
              w.data?.contains('Registry Highlights') == true ||
              w.data?.contains('items still needed') == true ||
              w.data?.contains('FAMILY INSIGHT') == true ||
              w.data?.contains('DAYS TO DUE DATE') == true),
    );
    expect(prdSection, findsWidgets);
  });
}
