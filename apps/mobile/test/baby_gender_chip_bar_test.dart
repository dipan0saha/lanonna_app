import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/domain/baby_gender.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/core/widgets/app_chip.dart';
import 'package:lanonna/core/widgets/baby_gender_chip_bar.dart';
import 'package:lanonna/l10n/app_localizations.dart';

AppToggleChip _chip(WidgetTester tester, String label) =>
    tester.widget<AppToggleChip>(find.widgetWithText(AppToggleChip, label));

void main() {
  test('chipAccent is peach for Girl and sage otherwise', () {
    expect(BabyGender.female.chipAccent, AppChipAccent.peach);
    expect(BabyGender.male.chipAccent, AppChipAccent.sage);
    expect(BabyGender.unknown.chipAccent, AppChipAccent.sage);
  });

  testWidgets('BabyGenderChipBar selects Boy or Girl, Girl in peach', (
    tester,
  ) async {
    var selected = BabyGender.male;
    var calls = 0;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return BabyGenderChipBar(
                selected: selected,
                onSelected: (g) {
                  calls++;
                  setState(() => selected = g);
                },
              );
            },
          ),
        ),
      ),
    );

    expect(_chip(tester, 'Boy').selected, isTrue);
    expect(_chip(tester, 'Boy').selectedAccent, AppChipAccent.sage);
    expect(_chip(tester, 'Girl').selected, isFalse);
    expect(_chip(tester, 'Girl').selectedAccent, AppChipAccent.peach);

    await tester.tap(find.byKey(BabyGenderChipBar.girlKey));
    await tester.pumpAndSettle();

    expect(selected, BabyGender.female);
    expect(calls, 1);
    expect(_chip(tester, 'Girl').selected, isTrue);

    // Re-tapping the selected option does not report a change.
    await tester.tap(find.byKey(BabyGenderChipBar.girlKey));
    await tester.pump();
    expect(selected, BabyGender.female);
    expect(calls, 1);
  });
}
