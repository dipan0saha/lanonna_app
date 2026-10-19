import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/auth/auth_repository.dart';
import 'package:lanonna/core/auth/biometric_credential_repository.dart';
import 'package:lanonna/core/auth/biometric_sign_in_service.dart';
import 'package:lanonna/core/auth/biometric_sign_in_store.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/features/onboarding/data/onboarding_repository.dart';
import 'package:lanonna/features/onboarding/data/onboarding_storage.dart';
import 'package:lanonna/features/onboarding/domain/onboarding_routes.dart';
import 'package:lanonna/features/onboarding/presentation/onboarding_coordinator.dart';
import 'package:lanonna/features/invitations/presentation/invite_flow_state.dart';
import 'package:lanonna/features/onboarding/presentation/screens/onboarding_login_screen.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _StubBiometricSignInService extends BiometricSignInService {
  _StubBiometricSignInService(this._enrollment)
      : super(
          credentials: BiometricCredentialRepository(
            ApiClient(idTokenProvider: () async => null),
          ),
          store: BiometricSignInStore(),
          authRepository: AuthRepository(),
        );

  final BiometricSignInEnrollment? _enrollment;

  @override
  Future<BiometricSignInEnrollment?> localEnrollment() async => _enrollment;
}

Future<void> _pumpLogin(
  WidgetTester tester,
  BiometricSignInService biometricService,
) async {
  SharedPreferences.setMockInitialValues({});
  final storage = OnboardingStorage(await SharedPreferences.getInstance());
  final coordinator = OnboardingCoordinator(
    storage: storage,
    repository: OnboardingRepository(
      ApiClient(idTokenProvider: () async => null),
    ),
  );
  await coordinator.hydrate();

  final router = GoRouter(
    initialLocation: OnboardingRoutes.login,
    routes: [
      GoRoute(
        path: OnboardingRoutes.login,
        builder: (_, __) => const OnboardingLoginScreen(),
      ),
    ],
  );

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<OnboardingCoordinator>.value(value: coordinator),
        ChangeNotifierProvider<InviteFlowState>.value(value: InviteFlowState()),
        Provider<BiometricSignInService>.value(value: biometricService),
        Provider<AuthRepository>.value(value: AuthRepository()),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('login shows biometric CTA when device enrolled', (tester) async {
    final biometric = _StubBiometricSignInService(
      const BiometricSignInEnrollment(
        credentialId: 'cred',
        firebaseUid: 'uid',
        accountHint: 'a***@example.com',
      ),
    );
    await _pumpLogin(tester, biometric);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('biometric_sign_in_button')), findsOneWidget);
  });

  testWidgets('login hides biometric CTA without enrollment', (tester) async {
    final biometric = _StubBiometricSignInService(null);
    await _pumpLogin(tester, biometric);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('biometric_sign_in_button')), findsNothing);
  });
}
