import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/core/widgets/app_button_label.dart';
import 'package:lanonna/core/widgets/app_gift_pill_button.dart';

void main() {
  Future<void> pumpPill(
    WidgetTester tester, {
    required double width,
    required double textScale,
  }) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: MaterialApp(
                  localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
theme: AppTheme.light,
          home: Scaffold(
            body: SizedBox(
              width: width,
              child: AppGiftPillButton(
                label: 'Mark as purchased',
                onPressed: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  void expectNoMidWordBreak(WidgetTester tester) {
    expect(tester.takeException(), isNull);
    final label = tester.widget<Text>(
      find.descendant(
        of: find.byType(AppButtonLabel),
        matching: find.byType(Text),
      ),
    );
    expect(label.data, 'Mark as purchased');
  }

  for (final width in [320.0, 360.0, 412.0]) {
    testWidgets('gift pill label at ${width.toInt()}dp', (tester) async {
      await pumpPill(tester, width: width, textScale: 1);
      expectNoMidWordBreak(tester);
    });

    testWidgets('gift pill label at ${width.toInt()}dp 1.3x text', (
      tester,
    ) async {
      await pumpPill(tester, width: width, textScale: 1.3);
      expectNoMidWordBreak(tester);
    });
  }
}
