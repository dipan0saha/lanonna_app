import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/auth/auth_repository.dart';
import 'package:lanonna/core/domain/baby_lifecycle.dart';
import 'package:lanonna/core/domain/baby_summary.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/features/home/data/home_repository.dart';
import 'package:lanonna/features/home/data/selected_baby_store.dart';
import 'package:lanonna/features/invitations/data/invitations_repository.dart';
import 'package:lanonna/features/invitations/data/models/invitation_accept_result.dart';
import 'package:lanonna/features/invitations/data/models/invitation_preview.dart';
import 'package:lanonna/features/invitations/domain/invitation_status.dart';
import 'package:lanonna/features/invitations/presentation/invite_flow_state.dart';
import 'package:lanonna/features/onboarding/data/models/onboarding_status.dart';
import 'package:lanonna/features/onboarding/data/onboarding_repository.dart';
import 'package:lanonna/features/onboarding/data/onboarding_storage.dart';
import 'package:lanonna/features/onboarding/domain/onboarding_routes.dart';
import 'package:lanonna/features/onboarding/presentation/app_session.dart';
import 'package:lanonna/features/onboarding/presentation/onboarding_coordinator.dart';
import 'package:lanonna/features/onboarding/presentation/screens/follower/onboarding_follower_invite_screen.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// #427: an Accept tapped before sign-in is continued by the invite landing,
/// through the same primary action as a tap (accept, or the #374 member no-op).

const _token = 'invite-token-427';

InvitationPreview _preview(InvitationStatus status) => InvitationPreview(
  status: status,
  babyName: 'Liam',
  inviterDisplayName: 'Alex',
  inviteeEmail: 'grandma@example.test',
  relationshipLabel: 'Grandma',
  invitedRole: 'follower',
  babyProfileId: 'baby-invite-1',
  lifecycle: BabyLifecycle.expecting,
  expectedBirthDate: '2026-06-01',
);

const _memberStatus = OnboardingStatus(
  emailVerified: true,
  profileComplete: true,
  hasOwnerBaby: false,
  hasBabyMembership: true,
  ownerOnboardingCompleted: false,
  needsOwnerOnboarding: false,
  canAccessMainApp: true,
);

class _FakeOnboardingRepository extends OnboardingRepository {
  _FakeOnboardingRepository()
    : super(ApiClient(idTokenProvider: () async => null));

  @override
  Future<OnboardingStatus> fetchStatus() async => _memberStatus;
}

class _FakeFirebaseAuth extends Fake implements FirebaseAuth {}

class _FakeUser extends Fake implements User {
  @override
  bool get emailVerified => true;

  @override
  String get uid => 'user-1';
}

class _SignedInAuth extends AuthRepository {
  _SignedInAuth() : super(firebaseAuth: _FakeFirebaseAuth());

  @override
  User? get currentUser => _FakeUser();
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

class _FakeHome extends HomeRepository {
  _FakeHome({required this.isMember})
    : super(ApiClient(idTokenProvider: () async => 'token'));

  final bool isMember;
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
  Future<BabySummary?> babyById(String babyId) async => isMember
      ? BabySummary(
          id: babyId,
          name: 'Liam',
          lifecycle: BabyLifecycle.expecting,
          role: 'follower',
        )
      : null;
}

Future<
  ({
    OnboardingCoordinator coordinator,
    _TrackingInvitations invitations,
    _FakeHome home,
  })
>
_pumpLanding(
  WidgetTester tester, {
  required InvitationStatus status,
  required bool acceptRequested,
  bool isMember = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final storage = OnboardingStorage(prefs);
  final repository = _FakeOnboardingRepository();
  final coordinator = OnboardingCoordinator(
    storage: storage,
    repository: repository,
  );
  await coordinator.hydrate();
  await coordinator.bindInviteFromPreview(_token, _preview(status));
  if (acceptRequested) coordinator.requestAcceptAfterSignIn(_token);
  final session = AppSession(
    repository: repository,
    storage: storage,
    coordinator: coordinator,
    currentUserId: () => 'user-1',
  );
  final invitations = _TrackingInvitations();
  final home = _FakeHome(isMember: isMember);

  final router = GoRouter(
    initialLocation: OnboardingRoutes.followerInvite,
    routes: [
      GoRoute(
        path: OnboardingRoutes.followerInvite,
        builder: (_, _) => const OnboardingFollowerInviteScreen(),
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
        ChangeNotifierProvider<OnboardingCoordinator>.value(value: coordinator),
        ChangeNotifierProvider<AppSession>.value(value: session),
        Provider<AuthRepository>.value(value: _SignedInAuth()),
        Provider<InvitationsRepository>.value(value: invitations),
        Provider<HomeRepository>.value(value: home),
        ChangeNotifierProvider<SelectedBabyStore>.value(
          value: SelectedBabyStore(prefs),
        ),
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
  await tester.pumpAndSettle();
  return (coordinator: coordinator, invitations: invitations, home: home);
}

void main() {
  testWidgets('landing continues the Accept tapped before sign-in, once', (
    tester,
  ) async {
    final r = await _pumpLanding(
      tester,
      status: InvitationStatus.pending,
      acceptRequested: true,
    );

    expect(r.invitations.acceptedTokens, [_token]);
    expect(r.home.rememberedBabyId, 'baby-invite-1');
    expect(find.byKey(const Key('home')), findsOneWidget);
    expect(r.coordinator.acceptRequestedBeforeSignIn, isFalse);
  });

  testWidgets('signed-in landing without a request waits for the tap', (
    tester,
  ) async {
    final r = await _pumpLanding(
      tester,
      status: InvitationStatus.pending,
      acceptRequested: false,
    );

    expect(r.invitations.acceptedTokens, isEmpty);
    expect(find.text('Accept Invitation'), findsOneWidget);
  });

  testWidgets(
    'already-member invite opens Home without an accept call (#374)',
    (tester) async {
      final r = await _pumpLanding(
        tester,
        status: InvitationStatus.accepted,
        acceptRequested: true,
        isMember: true,
      );

      expect(r.invitations.acceptedTokens, isEmpty);
      expect(find.byKey(const Key('home')), findsOneWidget);
    },
  );

  test(
    'accept request is tied to the current invite and cleared with it',
    () async {
      SharedPreferences.setMockInitialValues({});
      final storage = OnboardingStorage(await SharedPreferences.getInstance());
      final coordinator = OnboardingCoordinator(
        storage: storage,
        repository: _FakeOnboardingRepository(),
      );
      await coordinator.hydrate();
      await coordinator.bindInviteFromPreview(
        _token,
        _preview(InvitationStatus.pending),
      );

      coordinator.requestAcceptAfterSignIn('some-other-invite');
      expect(coordinator.acceptRequestedBeforeSignIn, isFalse);

      coordinator.requestAcceptAfterSignIn(_token);
      expect(coordinator.acceptRequestedBeforeSignIn, isTrue);
      await coordinator.clearPendingInvite();
      expect(coordinator.acceptRequestedBeforeSignIn, isFalse);
    },
  );
}
