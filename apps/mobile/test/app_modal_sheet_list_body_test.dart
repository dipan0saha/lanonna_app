import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/widgets/app_load_more_button.dart';
import 'package:lanonna/core/widgets/app_modal_sheet.dart';
import 'package:lanonna/l10n/app_localizations.dart';

Future<void> _openSheet(WidgetTester tester, List<Widget> rows) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showAppModalSheet<void>(
              context: context,
              title: 'Sheet',
              bodyBuilder: (_) => AppModalSheetListBody(children: rows),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('long list scrolls inside the sheet to the load-more footer', (
    tester,
  ) async {
    var loadMoreTaps = 0;
    await _openSheet(tester, [
      for (var i = 0; i < 40; i++) SizedBox(height: 48, child: Text('row $i')),
      AppLoadMoreButton(loading: false, onPressed: () => loadMoreTaps++),
    ]);

    final list = tester.widget<ListView>(find.byType(ListView));
    expect(list.physics, isNot(isA<NeverScrollableScrollPhysics>()));
    expect(find.text('row 39'), findsNothing);

    await tester.scrollUntilVisible(
      find.byType(AppLoadMoreButton),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('row 39'), findsOneWidget);
    await tester.tap(find.byType(AppLoadMoreButton));
    expect(loadMoreTaps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('short list keeps the sheet compact', (tester) async {
    await _openSheet(tester, [
      for (var i = 0; i < 2; i++) SizedBox(height: 48, child: Text('row $i')),
    ]);

    final listHeight = tester.getSize(find.byType(ListView)).height;
    expect(listHeight, 96);
  });
}
