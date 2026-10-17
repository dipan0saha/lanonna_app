import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:lanonna/core/theme/app_metrics.dart';
import 'package:lanonna/core/widgets/app_responsive_button_pair.dart';

void main() {
  testWidgets('stacks paired buttons vertically on narrow widths', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
home: Scaffold(
          body: Center(
            child: SizedBox(
              width: AppMetrics.responsiveButtonPairBreakpoint - 1,
              child: AppResponsiveButtonPair(
                start: const ElevatedButton(onPressed: null, child: Text('First')),
                end: const ElevatedButton(onPressed: null, child: Text('Second')),
              ),
            ),
          ),
        ),
      ),
    );

    final first = tester.getRect(find.text('First'));
    final second = tester.getRect(find.text('Second'));
    expect(second.top, greaterThan(first.bottom));
  });
}
