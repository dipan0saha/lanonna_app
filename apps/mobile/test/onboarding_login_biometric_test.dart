import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/auth/auth_repository.dart';
import 'package:lanonna/core/auth/biometric_credential_repository.dart';
import 'package:lanonna/core/auth/biometric_sign_in_service.dart';
import 'package:lanonna/core/auth/biometric_sign_in_store.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/features/invitations/presentation/invite_flow_state.dart';
import 'package:lanonna/features/onboarding/data/onboarding_repository.dart';
import 'package:lanonna/features/onboarding/data/onboarding_storage.dart';
import 'package:lanonna/features/onboarding/domain/onboarding_routes.dart';
import 'package:lanonna/features/onboarding/presentation/onboarding_coordinator.dart';
import 'package:lanonna/features/onboarding/presentation/screens/onboarding_login_screen.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuth implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pumpLogin(
  WidgetTester tester, {
  BiometricSignInEnrollment? enrollment,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final store = BiometricSignInStore(prefs);
  if (enrollment != null) await store.save(enrollment);
  final api = ApiClient(idTokenProvider: () async => null);
  final auth = _FakeAuth();
  final biometric = BiometricSignInService(
    credentials: BiometricCredentialRepository(api),
    store: store,
    authRepository: auth,
  );
  final coordinator = OnboardingCoordinator(
    storage: OnboardingStorage(prefs),
    repository: OnboardingRepository(api),
  );
  await coordinator.hydrate();

  final router = GoRouter(
    initialLocation: OnboardingRoutes.login,
    routes: [
      GoRoute(
        path: OnboardingRoutes.login,
        builder: (_, _) => const OnboardingLoginScreen(),
      ),
    ],
  );

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<OnboardingCoordinator>.value(value: coordinator),
        ChangeNotifierProvider<InviteFlowState>.value(value: InviteFlowState()),
        Provider<BiometricSignInService>.value(value: biometric),
        Provider<AuthRepository>.value(value: auth),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('login offers biometric sign-in for the enrolled account', (
    tester,
  ) async {
    await _pumpLogin(
      tester,
      enrollment: const BiometricSignInEnrollment(
        credentialId: 'cred',
        firebaseUid: 'uid',
        displayName: 'Ana',
      ),
    );
    expect(find.byKey(const Key('biometric_sign_in_button')), findsOneWidget);
    expect(find.text('Sign in with biometrics'), findsOneWidget);
    expect(find.text('Continue as Ana'), findsOneWidget);
  });

  testWidgets('login hides biometric sign-in without an enrollment', (
    tester,
  ) async {
    await _pumpLogin(tester);
    expect(find.byKey(const Key('biometric_sign_in_button')), findsNothing);
  });
}
