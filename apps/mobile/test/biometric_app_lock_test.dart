import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/auth/auth_repository.dart';
import 'package:lanonna/core/auth/biometric_app_lock.dart';
import 'package:lanonna/core/auth/biometric_unlock_service.dart';
import 'package:lanonna/core/auth/session_cleanup.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/features/account/data/account_repository.dart';
import 'package:lanonna/features/home/data/home_repository.dart';
import 'package:lanonna/features/home/data/selected_baby_store.dart';
import 'package:lanonna/features/invitations/presentation/invite_flow_state.dart';
import 'package:lanonna/features/onboarding/data/models/onboarding_status.dart';
import 'package:lanonna/features/onboarding/data/onboarding_repository.dart';
import 'package:lanonna/features/onboarding/data/onboarding_storage.dart';
import 'package:lanonna/features/onboarding/domain/onboarding_routes.dart';
import 'package:lanonna/features/onboarding/presentation/app_session.dart';
import 'package:lanonna/features/onboarding/presentation/onboarding_coordinator.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeFirebaseAuth extends Fake implements FirebaseAuth {}

class _FakeUser extends Fake implements User {}

class _FakeAuth extends AuthRepository {
  _FakeAuth({this.signedIn = true}) : super(firebaseAuth: _FakeFirebaseAuth());

  final bool signedIn;
  bool? signedInOverride;
  var signOuts = 0;

  @override
  User? get currentUser => (signedInOverride ?? signedIn) ? _FakeUser() : null;

  @override
  Future<void> signOut() async {
    signOuts++;
  }
}

class _FakeAccountRepository extends AccountRepository {
  _FakeAccountRepository({AccountPayload? account})
    : super(ApiClient(idTokenProvider: () async => null)) {
    profileUpdates.account = account;
  }

  @override
  Future<void> ensureAccountLoaded() async {}
}

class _FakeBiometricUnlock extends BiometricUnlockService {
  _FakeBiometricUnlock({this.succeed = false, this.pending});

  /// Result of the next prompt; tests flip it to keep the overlay visible.
  bool succeed;

  /// When set, [authenticate] waits for this (a prompt still on screen).
  final Completer<bool>? pending;
  var authenticateCalls = 0;

  @override
  Future<bool> authenticate({required String reason}) async {
    authenticateCalls++;
    final wait = pending;
    if (wait != null) return wait.future;
    return succeed;
  }
}

class _FakeSessionCleanup extends SessionCleanup {
  _FakeSessionCleanup(SharedPreferences prefs)
    : super(
        coordinator: OnboardingCoordinator(
          storage: OnboardingStorage(prefs),
          repository: OnboardingRepository(
            ApiClient(idTokenProvider: () async => null),
          ),
        ),
        homeRepository: HomeRepository(
          ApiClient(idTokenProvider: () async => null),
        ),
        selectedBabyStore: SelectedBabyStore(prefs),
        inviteFlowState: InviteFlowState(),
      );

  var cleared = false;

  @override
  Future<void> clearLocalUserData() async {
    cleared = true;
  }
}

AccountPayload _account({bool biometricUnlockEnabled = true}) {
  return AccountPayload(
    displayName: 'Ana',
    email: 'ana@example.com',
    babies: const [],
    engagement: const UserEngagementStats(
      photosSquished: 0,
      eventsAttended: 0,
      itemsBought: 0,
      comments: 0,
    ),
    biometricUnlockEnabled: biometricUnlockEnabled,
  );
}

OnboardingStatus _mainAppStatus() {
  return const OnboardingStatus(
    emailVerified: true,
    profileComplete: true,
    hasOwnerBaby: true,
    hasBabyMembership: true,
    ownerOnboardingCompleted: true,
    needsOwnerOnboarding: false,
    canAccessMainApp: true,
  );
}

Future<
  ({
    GoRouter router,
    AppSession session,
    _FakeAuth auth,
    _FakeBiometricUnlock biometric,
    _FakeSessionCleanup cleanup,
    _FakeAccountRepository accounts,
  })
>
_pumpLockHarness(
  WidgetTester tester, {
  required String initialLocation,
  bool signedIn = true,
  bool biometricUnlockEnabled = true,
  bool accountLoaded = true,
  OnboardingStatus? status,
  _FakeAuth? auth,
  _FakeBiometricUnlock? biometric,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final api = ApiClient(idTokenProvider: () async => null);
  final coordinator = OnboardingCoordinator(
    storage: OnboardingStorage(prefs),
    repository: OnboardingRepository(api),
  );
  await coordinator.hydrate();
  final session = AppSession(
    repository: OnboardingRepository(api),
    storage: OnboardingStorage(prefs),
    coordinator: coordinator,
  );
  session.debugSetStatus(status ?? _mainAppStatus());

  final fakeAuth = auth ?? _FakeAuth(signedIn: signedIn);
  final fakeBiometric = biometric ?? _FakeBiometricUnlock();
  final cleanup = _FakeSessionCleanup(prefs);
  final accounts = _FakeAccountRepository(
    account: accountLoaded
        ? _account(biometricUnlockEnabled: biometricUnlockEnabled)
        : null,
  );

  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/home',
        builder: (_, _) => const Scaffold(body: Text('home body')),
      ),
      GoRoute(
        path: OnboardingRoutes.login,
        builder: (_, _) => const Scaffold(body: Text('login body')),
      ),
      GoRoute(
        path: OnboardingRoutes.ownerCarousel,
        builder: (_, _) => const Scaffold(body: Text('signed out landing')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppSession>.value(value: session),
        Provider<AuthRepository>.value(value: fakeAuth),
        Provider<AccountRepository>.value(value: accounts),
        Provider<SessionCleanup>.value(value: cleanup),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
        builder: (context, child) => BiometricAppLock(
          router: router,
          biometricService: fakeBiometric,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    ),
  );
  await tester.pump();

  return (
    router: router,
    session: session,
    auth: fakeAuth,
    biometric: fakeBiometric,
    cleanup: cleanup,
    accounts: accounts,
  );
}

void _background(WidgetTester tester) {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
}

void _foreground(WidgetTester tester) {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('engages on cold start when enabled and signed in on main app', (
    tester,
  ) async {
    final harness = await _pumpLockHarness(
      tester,
      initialLocation: '/home',
      biometricUnlockEnabled: true,
    );
    await tester.pump();

    expect(find.text('Locked'), findsOneWidget);
    expect(harness.biometric.authenticateCalls, 1);
    expect(find.text('home body'), findsOneWidget);
  });

  testWidgets('engages on resume when enabled and signed in', (tester) async {
    final harness = await _pumpLockHarness(
      tester,
      initialLocation: '/home',
      biometricUnlockEnabled: true,
      biometric: _FakeBiometricUnlock(succeed: true),
    );
    await tester.pumpAndSettle();
    expect(find.text('Locked'), findsNothing);

    final callsBefore = harness.biometric.authenticateCalls;
    harness.biometric.succeed = false;
    _background(tester);
    _foreground(tester);
    await tester.pump();

    expect(find.text('Locked'), findsOneWidget);
    expect(harness.biometric.authenticateCalls, callsBefore + 1);
  });

  testWidgets('a focus loss alone (inactive, then resumed) does not lock', (
    tester,
  ) async {
    final harness = await _pumpLockHarness(
      tester,
      initialLocation: '/home',
      biometric: _FakeBiometricUnlock(succeed: true),
    );
    await tester.pumpAndSettle();
    final callsBefore = harness.biometric.authenticateCalls;

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(find.text('Locked'), findsNothing);
    expect(harness.biometric.authenticateCalls, callsBefore);
  });

  testWidgets('the unlock prompt leaving the screen does not re-lock', (
    tester,
  ) async {
    final prompt = Completer<bool>();
    final harness = await _pumpLockHarness(
      tester,
      initialLocation: '/home',
      biometric: _FakeBiometricUnlock(pending: prompt),
    );
    await tester.pump();
    expect(find.text('Locked'), findsOneWidget);
    expect(harness.biometric.authenticateCalls, 1);

    // Some devices pause the activity while the system prompt is up.
    _background(tester);
    prompt.complete(true);
    await tester.pump();
    _foreground(tester);
    await tester.pumpAndSettle();

    expect(find.text('Locked'), findsNothing);
    expect(harness.biometric.authenticateCalls, 1);
  });

  testWidgets('turning the setting on does not lock until the next resume', (
    tester,
  ) async {
    final harness = await _pumpLockHarness(
      tester,
      initialLocation: '/home',
      biometricUnlockEnabled: false,
    );
    await tester.pumpAndSettle();

    harness.accounts.profileUpdates.publish(_account());
    await tester.pumpAndSettle();
    expect(find.text('Locked'), findsNothing);
    expect(harness.biometric.authenticateCalls, 0);

    _background(tester);
    _foreground(tester);
    await tester.pump();
    expect(find.text('Locked'), findsOneWidget);
    expect(harness.biometric.authenticateCalls, 1);
  });

  testWidgets('a fresh sign-in after a signed-out launch does not lock', (
    tester,
  ) async {
    final auth = _FakeAuth(signedIn: false);
    final harness = await _pumpLockHarness(
      tester,
      initialLocation: OnboardingRoutes.login,
      auth: auth,
    );
    await tester.pumpAndSettle();

    // Simulate sign-in completing: session refresh and redirect to home.
    auth.signedInOverride = true;
    harness.session.debugSetStatus(_mainAppStatus());
    harness.router.go('/home');
    await tester.pumpAndSettle();

    expect(find.text('home body'), findsOneWidget);
    expect(find.text('Locked'), findsNothing);
    expect(harness.biometric.authenticateCalls, 0);
  });

  testWidgets('cold start waits for the profile, then locks once', (
    tester,
  ) async {
    final harness = await _pumpLockHarness(
      tester,
      initialLocation: '/home',
      accountLoaded: false,
    );
    await tester.pumpAndSettle();
    expect(find.text('Locked'), findsNothing);

    harness.accounts.profileUpdates.publish(_account());
    await tester.pump();
    expect(find.text('Locked'), findsOneWidget);
    expect(harness.biometric.authenticateCalls, 1);

    harness.accounts.profileUpdates.publish(_account());
    await tester.pump();
    expect(harness.biometric.authenticateCalls, 1);
  });

  testWidgets('cold start does not lock while onboarding is incomplete', (
    tester,
  ) async {
    final harness = await _pumpLockHarness(
      tester,
      initialLocation: '/home',
      status: const OnboardingStatus(
        emailVerified: true,
        profileComplete: false,
        hasOwnerBaby: false,
        hasBabyMembership: false,
        ownerOnboardingCompleted: false,
        needsOwnerOnboarding: true,
        canAccessMainApp: false,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Locked'), findsNothing);

    // Finishing onboarding later must not pop a cold-start lock mid-session.
    harness.session.debugSetStatus(_mainAppStatus());
    harness.router.go('/home');
    await tester.pumpAndSettle();
    expect(find.text('Locked'), findsNothing);
    expect(harness.biometric.authenticateCalls, 0);
  });

  testWidgets('does not engage when biometric unlock is disabled', (
    tester,
  ) async {
    final harness = await _pumpLockHarness(
      tester,
      initialLocation: '/home',
      biometricUnlockEnabled: false,
    );
    await tester.pump();
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(find.text('Locked'), findsNothing);
    expect(harness.biometric.authenticateCalls, 0);
  });

  testWidgets('does not engage when signed out', (tester) async {
    final harness = await _pumpLockHarness(
      tester,
      initialLocation: '/home',
      signedIn: false,
    );
    await tester.pump();
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(find.text('Locked'), findsNothing);
    expect(harness.biometric.authenticateCalls, 0);
  });

  testWidgets('does not engage on onboarding paths', (tester) async {
    final harness = await _pumpLockHarness(
      tester,
      initialLocation: OnboardingRoutes.login,
    );
    await tester.pump();
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(find.text('Locked'), findsNothing);
    expect(harness.biometric.authenticateCalls, 0);
  });

  testWidgets('cold start does not keep rescheduling evaluation every frame', (
    tester,
  ) async {
    final harness = await _pumpLockHarness(tester, initialLocation: '/home');
    await tester.pump();
    final callsAfterFirstFrame = harness.biometric.authenticateCalls;

    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(harness.biometric.authenticateCalls, callsAfterFirstFrame);
    expect(callsAfterFirstFrame, 1);
  });

  testWidgets('sign out from lock navigates to owner carousel', (tester) async {
    final harness = await _pumpLockHarness(tester, initialLocation: '/home');
    await tester.pump();
    expect(find.text('Locked'), findsOneWidget);

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(harness.cleanup.cleared, isTrue);
    expect(harness.auth.signOuts, 1);
    expect(find.text('signed out landing'), findsOneWidget);
    expect(find.text('Locked'), findsNothing);
  });
}
