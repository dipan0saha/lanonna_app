import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/domain/baby_gender.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/core/widgets/app_chip.dart';
import 'package:lanonna/features/onboarding/presentation/widgets/onboarding_prototype_widgets.dart';
import 'package:lanonna/l10n/app_localizations.dart';

bool _isSelected(WidgetTester tester, String label) => tester
    .widget<AppToggleChip>(find.widgetWithText(AppToggleChip, label))
    .selected;

void main() {
  testWidgets('PrototypeMiniGenderToggle selects Boy or Girl chips', (
    tester,
  ) async {
    var selected = BabyGender.male;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return PrototypeMiniGenderToggle(
                selected: selected,
                onSelected: (g) => setState(() => selected = g),
              );
            },
          ),
        ),
      ),
    );

    expect(_isSelected(tester, 'Boy'), isTrue);
    expect(_isSelected(tester, 'Girl'), isFalse);

    await tester.tap(find.byKey(const Key('prototype_mini_gender_girl')));
    await tester.pumpAndSettle();

    expect(selected, BabyGender.female);
    expect(_isSelected(tester, 'Girl'), isTrue);

    await tester.tap(find.byKey(const Key('prototype_mini_gender_girl')));
    await tester.pump();
    expect(selected, BabyGender.female);
  });
}
