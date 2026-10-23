import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/auth/auth_repository.dart';
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

class _FakeFirebaseAuth extends Fake implements FirebaseAuth {}

class _FakeUser extends Fake implements User {
  _FakeUser({required this.emailVerified});

  @override
  final bool emailVerified;

  @override
  String get uid => 'user-1';
}

class _FakeAuth extends AuthRepository {
  _FakeAuth({required this.emailVerified})
    : super(firebaseAuth: _FakeFirebaseAuth());

  final bool emailVerified;

  @override
  User? get currentUser => _FakeUser(emailVerified: emailVerified);
}

void main() {
  for (final (emailVerified, expected) in [
    (true, 'create_baby'),
    (false, 'email_verify'),
  ]) {
    testWidgets(
    'navigateAfterOnboardingAuth lands where cold start would '
    '(emailVerified: $emailVerified)', (
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
        GoRoute(
          path: OnboardingRoutes.emailVerify,
          builder: (_, _) => const SizedBox(key: Key('email_verify')),
        ),
      ],
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<OnboardingCoordinator>.value(
            value: coordinator,
          ),
          ChangeNotifierProvider<AppSession>.value(value: session),
          Provider<AuthRepository>.value(
            value: _FakeAuth(emailVerified: emailVerified),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await navigateAfterOnboardingAuth(
      tester.element(find.byKey(const Key('login'))),
      usedOAuth: false,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(Key(expected)), findsOneWidget);
    expect(
      session.signedInResumeLocation(emailVerified: emailVerified),
      emailVerified
          ? OnboardingRoutes.ownerCreateBaby
          : OnboardingRoutes.emailVerify,
    );
  });
  }

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
