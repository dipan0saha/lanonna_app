import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:lanonna/core/theme/app_metrics.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/features/onboarding/presentation/widgets/onboarding_fields.dart';

void main() {
  testWidgets('equalWidthRow gives Mother and Father equal width', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
theme: AppTheme.light,
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: OnboardingPillSelect(
              layout: OnboardingPillLayout.equalWidthRow,
              options: const ['Mother', 'Father'],
              selectedIndex: null,
              onSelected: (_) {},
            ),
          ),
        ),
      ),
    );

    final motherFinder = find.text('Mother');
    final fatherFinder = find.text('Father');
    final motherBox = tester.getRect(motherFinder);
    final fatherBox = tester.getRect(fatherFinder);

    expect(motherBox.width, closeTo(fatherBox.width, 1));
  });

  testWidgets('wrap uses intrinsic pill widths', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
theme: AppTheme.light,
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: OnboardingPillSelect(
              layout: OnboardingPillLayout.wrap,
              options: const ['Mother', 'Father'],
              selectedIndex: null,
              onSelected: (_) {},
            ),
          ),
        ),
      ),
    );

    final motherWidth = tester.getRect(find.text('Mother')).width;
    final halfRow = (320 - AppMetrics.choicePillGap) / 2;
    expect(motherWidth, lessThan(halfRow - 8));
  });

  testWidgets('equalWidthRow shows no selected styling when index is null',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
theme: AppTheme.light,
        home: Scaffold(
          body: OnboardingPillSelect(
            layout: OnboardingPillLayout.equalWidthRow,
            options: const ['Mother', 'Father'],
            selectedIndex: null,
            onSelected: (_) {},
          ),
        ),
      ),
    );

    final containers = tester.widgetList<AnimatedContainer>(
      find.byType(AnimatedContainer),
    );
    for (final container in containers) {
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, AppTheme.light.colorScheme.surface);
    }
  });
}
