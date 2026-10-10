import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/features/onboarding/presentation/widgets/forgot_password_dialog.dart';
import 'package:lanonna/l10n/app_localizations.dart';

void main() {
  testWidgets('forgot password dialog returns trimmed email when valid', (tester) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: FilledButton(
                onPressed: () async {
                  result = await showForgotPasswordEmailDialog(context);
                },
                child: const Text('Open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('forgot_password_email')), '  reset@example.com  ');
    await tester.tap(find.byKey(const Key('forgot_password_send')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(result, 'reset@example.com');
  });
}
