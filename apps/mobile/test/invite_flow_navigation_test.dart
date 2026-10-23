import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/auth/auth_repository.dart';
import 'package:lanonna/core/domain/baby_lifecycle.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/features/home/data/home_repository.dart';
import 'package:lanonna/features/home/data/selected_baby_store.dart';
import 'package:lanonna/features/invitations/domain/invitation_status.dart';
import 'package:lanonna/features/invitations/data/invitations_repository.dart';
import 'package:lanonna/features/invitations/data/models/invitation_accept_result.dart';
import 'package:lanonna/features/invitations/data/models/invitation_preview.dart';
import 'package:lanonna/features/invitations/presentation/invite_flow_state.dart';
import 'package:lanonna/features/onboarding/data/onboarding_repository.dart';
import 'package:lanonna/features/onboarding/data/onboarding_storage.dart';
import 'package:lanonna/features/onboarding/presentation/app_session.dart';
import 'package:lanonna/features/onboarding/presentation/onboarding_coordinator.dart';
import 'package:lanonna/features/onboarding/presentation/utils/invite_flow_navigation.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SignedInAuth extends AuthRepository {
  _SignedInAuth() : super(firebaseAuth: _FakeFirebaseAuth());

  @override
  User? get currentUser => _FakeUser();
}

class _FakeFirebaseAuth extends Fake implements FirebaseAuth {}

class _FakeUser extends Fake implements User {}

class _TrackingHome extends HomeRepository {
  _TrackingHome() : super(ApiClient(idTokenProvider: () async => 't'));

  String? rememberedBabyId;

  @override
  Future<void> rememberJoinedBaby(
    SelectedBabyStore store,
    String babyId,
  ) async {
    rememberedBabyId = babyId;
    await store.setSelectedBabyId(babyId);
  }
}

class _Invitations extends InvitationsRepository {
  _Invitations(this.result) : super(ApiClient(idTokenProvider: () async => 't'));

  final InvitationAcceptResult result;
  final acceptedTokens = <String>[];

  @override
  Future<InvitationAcceptResult> accept(String token) async {
    acceptedTokens.add(token);
    return result;
  }
}

InvitationPreview _preview(InvitationStatus status) => InvitationPreview(
  status: status,
  babyName: 'Luna',
  inviterDisplayName: 'Alex',
  inviteeEmail: 'follower@test.com',
  relationshipLabel: 'Parent',
  invitedRole: 'follower',
  babyProfileId: 'luna-baby-id',
  lifecycle: BabyLifecycle.born,
);

class _Harness {
  _Harness(this.coordinator, this.home, this.invitations);

  final OnboardingCoordinator coordinator;
  final _TrackingHome home;
  final _Invitations invitations;
  String? lastMessage;
}

/// Invite landing stand-in: one button that runs the shared primary CTA.
Future<_Harness> _pump(
  WidgetTester tester, {
  required InvitationPreview? preview,
  required String? token,
  InvitationAcceptResult acceptResult = const InvitationAcceptResult(
    alreadyMember: true,
    babyProfileId: 'luna-baby-id',
  ),
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final storage = OnboardingStorage(prefs);
  final repo = OnboardingRepository(ApiClient(idTokenProvider: () async => 't'));
  final coordinator = OnboardingCoordinator(storage: storage, repository: repo);
  await coordinator.hydrate();
  if (preview != null) {
    await coordinator.bindInviteFromPreview('invite-token', preview);
  }
  await coordinator.setPendingInviteToken(token);

  final harness = _Harness(coordinator, _TrackingHome(), _Invitations(acceptResult));
  final store = SelectedBabyStore(prefs);
  final session = AppSession(
    repository: repo,
    storage: storage,
    coordinator: coordinator,
    currentUserId: () => 'user-1',
  );
  final shownPreview = preview ?? _preview(InvitationStatus.accepted);

  final router = GoRouter(
    initialLocation: '/invite',
    routes: [
      GoRoute(
        path: '/invite',
        builder: (context, state) => Scaffold(
          body: ElevatedButton(
            onPressed: () async {
              harness.lastMessage =
                  await runInviteLandingPrimaryAction(context, shownPreview);
            },
            child: const Text('Primary'),
          ),
        ),
      ),
      GoRoute(
        path: '/home',
        builder: (_, _) => const Scaffold(body: Text('Home reached')),
      ),
    ],
  );

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<AuthRepository>.value(value: _SignedInAuth()),
        ChangeNotifierProvider<OnboardingCoordinator>.value(value: coordinator),
        Provider<HomeRepository>.value(value: harness.home),
        Provider<InvitationsRepository>.value(value: harness.invitations),
        ChangeNotifierProvider<SelectedBabyStore>.value(value: store),
        ChangeNotifierProvider<AppSession>.value(value: session),
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
  await tester.tap(find.text('Primary'));
  await tester.pumpAndSettle();
  return harness;
}

void main() {
  testWidgets('Open on an accepted invite with a cleared token goes to the baby', (
    tester,
  ) async {
    final h = await _pump(
      tester,
      preview: _preview(InvitationStatus.accepted),
      token: null,
    );
    expect(find.text('Home reached'), findsOneWidget);
    expect(h.home.rememberedBabyId, 'luna-baby-id');
    expect(h.invitations.acceptedTokens, isEmpty);
  });

  testWidgets('deep link: Open with the token accepts (already member) and goes '
      'to the baby', (tester) async {
    final h = await _pump(
      tester,
      preview: _preview(InvitationStatus.accepted),
      token: 'invite-token',
    );
    expect(h.invitations.acceptedTokens, ['invite-token']);
    expect(find.text('Home reached'), findsOneWidget);
    expect(h.home.rememberedBabyId, 'luna-baby-id');
  });

  testWidgets('Open with neither token nor cached preview explains, not a no-op', (
    tester,
  ) async {
    final h = await _pump(tester, preview: null, token: null);
    expect(find.text('Home reached'), findsNothing);
    expect(h.lastMessage, 'This invitation link is invalid or was revoked.');
  });

  testWidgets('Accept with no saved token explains, not a no-op', (tester) async {
    final h = await _pump(
      tester,
      preview: _preview(InvitationStatus.pending),
      token: null,
    );
    expect(find.text('Home reached'), findsNothing);
    expect(h.lastMessage, 'This invitation link is invalid or was revoked.');
  });

  testWidgets('a refused accept returns the mapped message', (tester) async {
    final h = await _pump(
      tester,
      preview: _preview(InvitationStatus.accepted),
      token: 'invite-token',
      acceptResult: const InvitationAcceptResult(error: 'revoked'),
    );
    expect(find.text('Home reached'), findsNothing);
    expect(h.lastMessage, isNotNull);
    expect(h.lastMessage, isNotEmpty);
  });
}
