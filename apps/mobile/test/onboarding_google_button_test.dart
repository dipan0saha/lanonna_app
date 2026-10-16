import 'package:flutter/material.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/theme/app_colors.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/core/widgets/google_logo_mark.dart';
import 'package:lanonna/features/onboarding/presentation/widgets/onboarding_buttons.dart';

void main() {
  testWidgets('Google button shows brand mark and dark label', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light,
        home: Scaffold(body: OnboardingGoogleButton(onPressed: () {})),
      ),
    );

    expect(find.byType(GoogleLogoMark), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);

    final label = tester.widget<Text>(find.text('Continue with Google'));
    expect(label.style?.color, AppColors.textPrimary);

    expect(find.text('G'), findsNothing);
  });
}
