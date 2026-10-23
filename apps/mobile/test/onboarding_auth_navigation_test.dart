import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/features/onboarding/data/models/onboarding_status.dart';
import 'package:lanonna/features/onboarding/data/onboarding_repository.dart';
import 'package:lanonna/features/onboarding/data/onboarding_storage.dart';
import 'package:lanonna/features/onboarding/domain/onboarding_routes.dart';
import 'package:lanonna/features/onboarding/presentation/app_session.dart';
import 'package:lanonna/features/onboarding/presentation/onboarding_coordinator.dart';
import 'package:lanonna/features/onboarding/presentation/utils/onboarding_auth_navigation.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeOnboardingRepository extends OnboardingRepository {
  _FakeOnboardingRepository(this._status)
    : super(ApiClient(idTokenProvider: () async => null));

  final OnboardingStatus _status;

  @override
  Future<OnboardingStatus> fetchStatus() async => _status;
}

void main() {
  testWidgets('navigateAfterOnboardingAuth uses signedInResumeLocation', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = OnboardingStorage(prefs);
    const status = OnboardingStatus(
      emailVerified: true,
      profileComplete: true,
      hasOwnerBaby: false,
      hasBabyMembership: false,
      ownerOnboardingCompleted: false,
      needsOwnerOnboarding: false,
      canAccessMainApp: false,
    );
    final repository = _FakeOnboardingRepository(status);
    final coordinator = OnboardingCoordinator(
      storage: storage,
      repository: repository,
    );
    await coordinator.hydrate();
    final session = AppSession(
      repository: repository,
      storage: storage,
      coordinator: coordinator,
      currentUserId: () => 'user-1',
    );

    final router = GoRouter(
      initialLocation: OnboardingRoutes.login,
      routes: [
        GoRoute(
          path: OnboardingRoutes.login,
          builder: (_, _) => const SizedBox(key: Key('login')),
        ),
        GoRoute(
          path: OnboardingRoutes.ownerCreateBaby,
          builder: (_, _) => const SizedBox(key: Key('create_baby')),
        ),
        GoRoute(
          path: OnboardingRoutes.completeProfile,
          builder: (_, _) => const SizedBox(key: Key('complete_profile')),
        ),
      ],
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<OnboardingCoordinator>.value(value: coordinator),
          Provider<AppSession>.value(value: session),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await navigateAfterOnboardingAuth(
      tester.element(find.byType(MaterialApp)),
      isSignUp: false,
      usedOAuth: false,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('create_baby')), findsOneWidget);
    expect(find.byKey(const Key('complete_profile')), findsNothing);
  });

  test('sign-in resume matches cold-start resume for profile-complete no-baby', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = OnboardingStorage(prefs);
    const status = OnboardingStatus(
      emailVerified: true,
      profileComplete: true,
      hasOwnerBaby: false,
      hasBabyMembership: false,
      ownerOnboardingCompleted: false,
      needsOwnerOnboarding: false,
      canAccessMainApp: false,
    );
    final repository = _FakeOnboardingRepository(status);
    final coordinator = OnboardingCoordinator(
      storage: storage,
      repository: repository,
    );
    await coordinator.hydrate();
    final session = AppSession(
      repository: repository,
      storage: storage,
      coordinator: coordinator,
      currentUserId: () => 'user-1',
    );
    session.debugSetStatus(status);

    expect(
      session.signedInResumeLocation(emailVerified: true),
      OnboardingRoutes.ownerCreateBaby,
    );
  });
}
