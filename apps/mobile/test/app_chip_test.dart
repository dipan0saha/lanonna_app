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

  testWidgets('AppToggleChipBar selects one option and reports changes', (
    tester,
  ) async {
    var selected = 'a';
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return AppToggleChipBar<String>(
                padding: EdgeInsets.zero,
                options: const [
                  AppToggleChipOption('a', 'Alpha'),
                  AppToggleChipOption(
                    'b',
                    'Beta',
                    selectedAccent: AppChipAccent.peach,
                  ),
                ],
                selected: selected,
                onSelected: (v) {
                  calls++;
                  setState(() => selected = v);
                },
              );
            },
          ),
        ),
      ),
    );

    expect(
      tester.widget<AppToggleChip>(find.widgetWithText(AppToggleChip, 'Alpha'))
          .selected,
      isTrue,
    );

    expect(
      tester.widget<AppToggleChip>(find.widgetWithText(AppToggleChip, 'Alpha'))
          .selectedAccent,
      AppChipAccent.sage,
    );

    await tester.tap(find.text('Beta'));
    await tester.pump();
    expect(selected, 'b');
    expect(calls, 1);
    final beta =
        tester.widget<AppToggleChip>(find.widgetWithText(AppToggleChip, 'Beta'));
    expect(beta.selected, isTrue);
    expect(beta.selectedAccent, AppChipAccent.peach);

    // Re-selecting the current option is a no-op.
    await tester.tap(find.text('Beta'));
    await tester.pump();
    expect(calls, 1);
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
