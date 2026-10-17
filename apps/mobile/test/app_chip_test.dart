import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:lanonna/core/theme/app_colors.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/core/widgets/app_chip.dart';

void main() {
  testWidgets('AppToggleChip shows plus prefix and toggles selection', (
    tester,
  ) async {
    var selected = false;
    await tester.pumpWidget(
      MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
theme: AppTheme.light,
        home: Scaffold(
          body: AppToggleChip(
            label: 'Gender Reveal',
            selected: selected,
            showPlusPrefix: true,
            onTap: () => selected = !selected,
          ),
        ),
      ),
    );

    expect(find.text('+ Gender Reveal'), findsOneWidget);

    await tester.tap(find.text('+ Gender Reveal'));
    await tester.pumpWidget(
      MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
theme: AppTheme.light,
        home: Scaffold(
          body: AppToggleChip(
            label: 'Gender Reveal',
            selected: true,
            showPlusPrefix: true,
            onTap: () {},
          ),
        ),
      ),
    );

    final text = tester.widget<Text>(find.text('+ Gender Reveal'));
    expect(text.style?.color, AppColors.primaryDark);
  });

  testWidgets('AppRemovableChip uses peach vs sage accent', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
theme: AppTheme.light,
        home: Scaffold(
          body: Column(
            children: [
              AppRemovableChip(
                label: 'Emma',
                accent: AppChipAccent.peach,
                onRemove: () {},
              ),
              AppRemovableChip(
                label: 'Liam',
                accent: AppChipAccent.sage,
                onRemove: () {},
              ),
            ],
          ),
        ),
      ),
    );

    final emma = tester.widget<Text>(find.text('Emma'));
    final liam = tester.widget<Text>(find.text('Liam'));
    expect(emma.style?.color, AppColors.secondaryDark);
    expect(liam.style?.color, AppColors.primaryDark);
  });

  testWidgets('AppRemovableChip onRemove fires from close control', (
    tester,
  ) async {
    var removed = false;
    await tester.pumpWidget(
      MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
theme: AppTheme.light,
        home: Scaffold(
          body: AppRemovableChip(
            label: 'Ava',
            accent: AppChipAccent.sage,
            onRemove: () => removed = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.close));
    expect(removed, isTrue);
  });
}
