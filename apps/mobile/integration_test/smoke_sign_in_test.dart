import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lanonna/bootstrap.dart';
import 'package:lanonna/firebase_options.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('smoke user email sign-in reaches signed-in onboarding or home', (tester) async {
    const email = String.fromEnvironment('SMOKE_TEST_EMAIL');
    const password = String.fromEnvironment('SMOKE_TEST_PASSWORD');
    expect(email, isNotEmpty, reason: 'Pass SMOKE_TEST_EMAIL via --dart-define');
    expect(password, isNotEmpty, reason: 'Pass SMOKE_TEST_PASSWORD via --dart-define');

    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await tester.pumpWidget(await bootstrapLaNonnaApp());
    await tester.pumpAndSettle(const Duration(seconds: 10));

    final onLogin = find.byKey(const Key('auth_email_field'));
    if (onLogin.evaluate().isNotEmpty) {
      await tester.ensureVisible(onLogin);
      await tester.enterText(onLogin, email);
      await tester.enterText(find.byKey(const Key('auth_password_field')), password);
      await tester.tap(find.byKey(const Key('sign_in_button')));
      await tester.pumpAndSettle(const Duration(seconds: 25));
    }

    final onHome = find.byKey(const Key('home_section_list'));
    final onOnboarding = find.byKey(const Key('onboarding_display_name'));
    final onCreateBaby = find.byKey(const Key('onboarding_baby_name'));
    expect(
      onHome.evaluate().isNotEmpty ||
          onOnboarding.evaluate().isNotEmpty ||
          onCreateBaby.evaluate().isNotEmpty,
      isTrue,
    );
  });
}
