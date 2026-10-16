import 'package:flutter/material.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/features/onboarding/presentation/widgets/onboarding_fields.dart';
import 'package:lanonna/core/validation/form_validators.dart';

void main() {
  testWidgets('parent hydration can update terms field inside Form', (
    tester,
  ) async {
    var accepted = false;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Form(
            child: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  children: [
                    OnboardingTermsFormField(
                      value: accepted,
                      autovalidateMode: AutovalidateMode.disabled,
                      validator: validateTermsAccepted,
                      onChanged: (v) => setState(() => accepted = v),
                      onTermsTap: () {},
                      onPrivacyTap: () {},
                    ),
                    TextButton(
                      onPressed: () => setState(() => accepted = true),
                      child: const Text('hydrate'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('hydrate'));
    await tester.pump();
    await tester.pump();
    expect(accepted, isTrue);
  });

  testWidgets('parent hydration can update relationship field inside Form', (
    tester,
  ) async {
    String? relationship;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Form(
            child: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  children: [
                    OnboardingRelationshipFormField(
                      value: relationship,
                      autovalidateMode: AutovalidateMode.disabled,
                      validator: validateOnboardingRelationshipToBaby,
                      onSelected: (label) =>
                          setState(() => relationship = label),
                    ),
                    TextButton(
                      onPressed: () => setState(() => relationship = 'Mother'),
                      child: const Text('hydrate'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('hydrate'));
    await tester.pump();
    await tester.pump();
    expect(relationship, 'Mother');
  });
}
