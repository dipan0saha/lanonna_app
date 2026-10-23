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
import 'package:lanonna/core/domain/baby_summary.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/features/home/data/home_repository.dart';
import 'package:lanonna/features/home/data/selected_baby_store.dart';
import 'package:lanonna/features/invitations/data/invitations_repository.dart';
import 'package:lanonna/features/invitations/data/models/invitation_accept_result.dart';
import 'package:lanonna/features/invitations/presentation/invite_flow_state.dart';
import 'package:lanonna/features/onboarding/domain/onboarding_path.dart';
import 'package:lanonna/features/onboarding/domain/onboarding_step.dart';
import 'package:lanonna/features/onboarding/presentation/utils/onboarding_auth_navigation.dart';
import 'package:lanonna/l10n/app_localizations.dart';
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

class _TrackingInvitations extends InvitationsRepository {
  _TrackingInvitations()
    : super(ApiClient(idTokenProvider: () async => 'token'));

  final acceptedTokens = <String>[];

  @override
  Future<InvitationAcceptResult> accept(String token) async {
    acceptedTokens.add(token);
    return const InvitationAcceptResult(
      alreadyMember: false,
      babyProfileId: 'baby-invite-1',
    );
  }
}

class _TrackingHome extends HomeRepository {
  _TrackingHome() : super(ApiClient(idTokenProvider: () async => 'token'));

  String? rememberedBabyId;

  @override
  Future<void> rememberJoinedBaby(
    SelectedBabyStore store,
    String babyId,
  ) async {
    rememberedBabyId = babyId;
    await store.setSelectedBabyId(babyId);
  }

  @override
  Future<BabySummary?> babyById(String babyId) async => null;
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

  testWidgets(
    'invite login sign-in accepts pending invite instead of looping (#427)',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = OnboardingStorage(prefs);
      await storage.saveOnboardingPath(OnboardingPath.follower);
      await storage.savePendingInviteToken('invite-token-427');
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
      await coordinator.setStep(OnboardingStep.login);
      final session = AppSession(
        repository: repository,
        storage: storage,
        coordinator: coordinator,
        currentUserId: () => 'user-1',
      );
      final invitations = _TrackingInvitations();
      final home = _TrackingHome();
      final store = SelectedBabyStore(prefs);

      final router = GoRouter(
        initialLocation: OnboardingRoutes.login,
        routes: [
          GoRoute(
            path: OnboardingRoutes.login,
            builder: (_, _) => const SizedBox(key: Key('login')),
          ),
          GoRoute(
            path: '/home',
            builder: (_, _) => const SizedBox(key: Key('home')),
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
              value: _FakeAuth(emailVerified: true),
            ),
            Provider<InvitationsRepository>.value(value: invitations),
            Provider<HomeRepository>.value(value: home),
            ChangeNotifierProvider<SelectedBabyStore>.value(value: store),
            ChangeNotifierProvider(create: (_) => InviteFlowState()),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );

      await navigateAfterOnboardingAuth(
        tester.element(find.byKey(const Key('login'))),
        usedOAuth: false,
      );
      await tester.pumpAndSettle();

      expect(invitations.acceptedTokens, ['invite-token-427']);
      expect(home.rememberedBabyId, 'baby-invite-1');
      expect(find.byKey(const Key('home')), findsOneWidget);
      expect(find.byKey(const Key('login')), findsNothing);
    },
  );
}
