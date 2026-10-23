import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/auth/auth_repository.dart';
import 'package:lanonna/core/auth/auth_session_service.dart';
import 'package:lanonna/core/auth/biometric_sign_in_service.dart';
import 'package:lanonna/core/auth/biometric_sign_in_store.dart';
import 'package:lanonna/core/auth/session_cleanup.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/features/home/data/home_repository.dart';
import 'package:lanonna/features/home/data/selected_baby_store.dart';
import 'package:lanonna/features/invitations/domain/invitation_status.dart';
import 'package:lanonna/core/domain/baby_lifecycle.dart';
import 'package:lanonna/features/invitations/data/models/invitation_preview.dart';
import 'package:lanonna/features/invitations/presentation/invite_flow_state.dart';
import 'package:lanonna/features/onboarding/data/onboarding_repository.dart';
import 'package:lanonna/features/onboarding/data/onboarding_storage.dart';
import 'package:lanonna/features/onboarding/domain/onboarding_routes.dart';
import 'package:lanonna/features/onboarding/presentation/onboarding_coordinator.dart';
import 'package:lanonna/features/onboarding/presentation/screens/onboarding_login_screen.dart';
import 'package:lanonna/features/onboarding/presentation/screens/shared/onboarding_wrong_email_screen.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeFirebaseAuth extends Fake implements FirebaseAuth {}

class _FakeAuth extends AuthRepository {
  _FakeAuth() : super(firebaseAuth: _FakeFirebaseAuth());

  var signOutCalls = 0;

  /// Signed out (the switch signs out before login).
  @override
  User? get currentUser => null;

  @override
  Future<void> signOut() async {
    signOutCalls++;
  }
}

/// No biometric enrollment on this device.
class _NoBiometric extends Fake implements BiometricSignInService {
  @override
  BiometricSignInEnrollment? get enrollment => null;
}

Future<
  ({OnboardingCoordinator coordinator, InviteFlowState flow, _FakeAuth auth})
>
_pumpWrongEmail(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final coordinator = OnboardingCoordinator(
    storage: OnboardingStorage(prefs),
    repository: OnboardingRepository(
      ApiClient(idTokenProvider: () async => null),
    ),
  );
  await coordinator.hydrate();
  await coordinator.bindInviteFromPreview(
    'handoff-token',
    const InvitationPreview(
      status: InvitationStatus.pending,
      babyName: 'Liam',
      inviterDisplayName: 'Alex',
      inviteeEmail: 'grandma@test.com',
      relationshipLabel: 'Grandma',
      invitedRole: 'follower',
      lifecycle: BabyLifecycle.expecting,
      expectedBirthDate: '2026-06-01',
    ),
  );

  final inviteFlowState = InviteFlowState();
  inviteFlowState.setEmailMismatch(
    inviteeEmail: 'grandma@test.com',
    signedInEmail: 'owner@test.com',
  );

  final auth = _FakeAuth();
  final cleanup = SessionCleanup(
    coordinator: coordinator,
    homeRepository: HomeRepository(
      ApiClient(idTokenProvider: () async => null),
      currentUserId: () => 'user-a',
    ),
    selectedBabyStore: SelectedBabyStore(prefs),
    inviteFlowState: inviteFlowState,
    evictImageCaches: () async {},
  );

  final router = GoRouter(
    initialLocation: OnboardingRoutes.wrongEmail,
    routes: [
      GoRoute(
        path: OnboardingRoutes.wrongEmail,
        builder: (_, _) => const OnboardingWrongEmailScreen(),
      ),
      GoRoute(
        path: OnboardingRoutes.login,
        builder: (_, _) => const OnboardingLoginScreen(),
      ),
      GoRoute(
        path: OnboardingRoutes.ownerCarousel,
        builder: (_, _) => const Text('carousel'),
      ),
    ],
  );

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: coordinator),
        ChangeNotifierProvider.value(value: inviteFlowState),
        Provider<AuthRepository>.value(value: auth),
        Provider<AuthSessionService>.value(
          value: AuthSessionService(
            authRepository: auth,
            sessionCleanup: cleanup,
          ),
        ),
        Provider<BiometricSignInService>.value(value: _NoBiometric()),
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
  return (coordinator: coordinator, flow: inviteFlowState, auth: auth);
}

void main() {
  testWidgets('Switch account prefills login and restores invite path', (
    tester,
  ) async {
    final (:coordinator, :flow, :auth) = await _pumpWrongEmail(tester);
    await tester.tap(find.text('Switch account'));
    await tester.pumpAndSettle();

    expect(auth.signOutCalls, 1);
    expect(
      find.byKey(const Key('onboarding_login_email')),
      findsOneWidget,
    );
    final emailField = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('onboarding_login_email')),
        matching: find.byType(EditableText),
      ),
    );
    expect(emailField.controller.text, 'grandma@test.com');
    expect(
      find.text('Sign in to accept your invitation and continue.'),
      findsOneWidget,
    );
    expect(coordinator.pendingInviteToken, 'handoff-token');
    // Signing in with the right account continues the Accept (#427).
    expect(coordinator.acceptRequestedBeforeSignIn, isTrue);
    expect(coordinator.isInvitePath, isTrue);
    expect(coordinator.cachedInvitePreview?.babyName, 'Liam');
    expect(coordinator.cachedInvitePreview?.relationshipLabel, 'Grandma');
    // The handoff is consumed by login and re-stored through the preview
    // field allowlist: nothing stays in memory, no invitee email on disk.
    expect(flow.takeInviteResume(), isNull);
    expect(coordinator.cachedInvitePreview?.inviteeEmail, isNull);
  });

  testWidgets('Leave invitation ends the flow and clears every handoff', (
    tester,
  ) async {
    final (:coordinator, :flow, :auth) = await _pumpWrongEmail(tester);
    flow.setInviteResume(
      token: 'handoff-token',
      path: coordinator.onboardingPath,
    );

    await tester.tap(find.text('Leave this invitation'));
    await tester.pumpAndSettle();

    expect(find.text('carousel'), findsOneWidget);
    expect(auth.signOutCalls, 0);
    expect(coordinator.pendingInviteToken, isNull);
    expect(coordinator.cachedInvitePreview, isNull);
    expect(coordinator.isInvitePath, isFalse);
    expect(flow.emailMismatch, isNull);
    expect(flow.takeInviteResume(), isNull);
  });
}
