import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/features/onboarding/presentation/widgets/onboarding_fields.dart';
import 'package:lanonna/l10n/app_localizations.dart';

Widget _host(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: AppTheme.light,
  home: Scaffold(body: SizedBox(width: 360, child: child)),
);

void main() {
  testWidgets(
    'pill select exposes one Maestro id per option and taps through it',
    (tester) async {
      int? tapped;
      await tester.pumpWidget(
        _host(
          OnboardingPillSelect(
            options: const ['Mother', 'Father'],
            semanticsIds: const ['pill_mother', 'pill_father'],
            selectedIndex: null,
            onSelected: (i) => tapped = i,
          ),
        ),
      );

      expect(find.bySemanticsIdentifier('pill_mother'), findsOneWidget);
      expect(find.bySemanticsIdentifier('pill_father'), findsOneWidget);
      await tester.tap(find.bySemanticsIdentifier('pill_father'));
      expect(tapped, 1);
    },
  );

  testWidgets('relationship field uses the onboarding_relationship ids', (
    tester,
  ) async {
    String? picked;
    await tester.pumpWidget(
      _host(
        Form(
          child: OnboardingRelationshipFormField(
            value: null,
            onSelected: (v) => picked = v,
          ),
        ),
      ),
    );

    await tester.tap(
      find.bySemanticsIdentifier('onboarding_relationship_mother'),
    );
    expect(picked, isNotNull);
    expect(
      find.bySemanticsIdentifier('onboarding_relationship_father'),
      findsOneWidget,
    );
  });

  testWidgets('terms checkbox is reachable by onboarding_terms_checkbox', (
    tester,
  ) async {
    bool? accepted;
    await tester.pumpWidget(
      _host(
        OnboardingTermsAgreementCheckbox(
          value: false,
          onChanged: (v) => accepted = v,
          onTermsTap: () {},
          onPrivacyTap: () {},
        ),
      ),
    );

    await tester.tap(find.bySemanticsIdentifier('onboarding_terms_checkbox'));
    expect(accepted, isTrue);
  });

  testWidgets('bottom link exposes its Maestro id only when given one', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(
        Column(
          children: [
            OnboardingBottomLink(
              semanticsId: 'auth_signup_login_link',
              message: (a) => 'Already have an account? $a',
              actionText: 'Log in',
              onTap: () => taps++,
            ),
            OnboardingBottomLink(
              message: (a) => 'Plain $a',
              actionText: 'link',
              onTap: () {},
            ),
          ],
        ),
      ),
    );

    expect(
      find.bySemanticsIdentifier('auth_signup_login_link'),
      findsOneWidget,
    );
    await tester.tap(find.bySemanticsIdentifier('auth_signup_login_link'));
    expect(taps, 1);
  });
}
