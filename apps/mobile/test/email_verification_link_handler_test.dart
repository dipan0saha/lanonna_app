import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/auth/auth_repository.dart';
import 'package:lanonna/core/auth/email_verification_link_handler.dart';
import 'package:lanonna/core/auth/email_verify_link_result.dart';
import 'package:lanonna/core/router/app_router.dart';
import 'package:lanonna/core/shell/app_shell_ui.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/features/onboarding/data/onboarding_repository.dart';
import 'package:lanonna/features/onboarding/data/onboarding_storage.dart';
import 'package:lanonna/features/onboarding/domain/onboarding_routes.dart';
import 'package:lanonna/features/onboarding/presentation/onboarding_coordinator.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeFirebaseAuth extends Fake implements FirebaseAuth {}

class _StubAuth extends AuthRepository {
  _StubAuth(this._result) : super(firebaseAuth: _FakeFirebaseAuth());

  final EmailVerifyLinkResult _result;
  var refreshClaimsCalls = 0;

  @override
  Future<EmailVerifyLinkResult> applyEmailVerificationLink(Uri uri) async =>
      _result;

  @override
  Future<void> refreshSessionClaims() async {
    refreshClaimsCalls++;
  }
}

final _verifyUri = Uri.parse(
  'https://lanonna-dev.firebaseapp.com/__/auth/action?mode=verifyEmail&oobCode=test',
);

Future<(OnboardingCoordinator coordinator, GoRouter router)> _pumpHandlerHarness(
  WidgetTester tester, {
  required _StubAuth auth,
  required String initialLocation,
}) async {
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
    navigatorKey: appRootNavigatorKey,
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: OnboardingRoutes.ownerCarousel,
        builder: (_, _) => const Scaffold(body: Text('carousel')),
      ),
      GoRoute(
        path: OnboardingRoutes.login,
        builder: (_, _) => const Scaffold(body: Text('login')),
      ),
      GoRoute(
        path: OnboardingRoutes.completeProfile,
        builder: (_, _) => const Scaffold(body: Text('complete profile')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<AuthRepository>.value(value: auth),
        ChangeNotifierProvider<OnboardingCoordinator>.value(value: coordinator),
      ],
      child: MaterialApp.router(
        scaffoldMessengerKey: rootScaffoldMessengerKey,
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (coordinator, router);
}

void main() {
  testWidgets('success with tap-continue shows snackbar and opens complete profile',
      (tester) async {
    final auth = _StubAuth(
      const EmailVerifyLinkResult(
        EmailVerifyLinkOutcome.success,
        promptTapContinue: true,
      ),
    );
    final (coordinator, router) = await _pumpHandlerHarness(
      tester,
      auth: auth,
      initialLocation: OnboardingRoutes.ownerCarousel,
    );
    await handleEmailVerificationLink(
      authRepository: auth,
      coordinator: coordinator,
      router: router,
      uri: _verifyUri,
    );
    await tester.pumpAndSettle();

    expect(find.text('complete profile'), findsOneWidget);
    expect(auth.refreshClaimsCalls, 1);
    expect(
      find.text('Verification complete. Tap Continue to proceed.'),
      findsOneWidget,
    );
  });

  testWidgets('no signed-in user navigates to login and shows sign-in message',
      (tester) async {
    final auth = _StubAuth(
      const EmailVerifyLinkResult(EmailVerifyLinkOutcome.noSignedInUser),
    );
    final (coordinator, router) = await _pumpHandlerHarness(
      tester,
      auth: auth,
      initialLocation: OnboardingRoutes.ownerCarousel,
    );
    await handleEmailVerificationLink(
      authRepository: auth,
      coordinator: coordinator,
      router: router,
      uri: _verifyUri,
    );
    await tester.pumpAndSettle();

    expect(find.text('login'), findsOneWidget);
    expect(
      find.text('Email verified. Sign in with the same address to continue.'),
      findsOneWidget,
    );
  });

  testWidgets('invalid link shows expired message', (tester) async {
    final auth = _StubAuth(
      const EmailVerifyLinkResult(
        EmailVerifyLinkOutcome.invalidOrExpired,
        firebaseErrorCode: 'invalid-action-code',
      ),
    );
    final (coordinator, router) = await _pumpHandlerHarness(
      tester,
      auth: auth,
      initialLocation: OnboardingRoutes.ownerCarousel,
    );
    await handleEmailVerificationLink(
      authRepository: auth,
      coordinator: coordinator,
      router: router,
      uri: _verifyUri,
    );
    await tester.pumpAndSettle();

    expect(find.text('carousel'), findsOneWidget);
    expect(
      find.textContaining('expired or was already used'),
      findsOneWidget,
    );
  });

  testWidgets('expired link shows expired message', (tester) async {
    final auth = _StubAuth(
      const EmailVerifyLinkResult(
        EmailVerifyLinkOutcome.invalidOrExpired,
        firebaseErrorCode: 'expired-action-code',
      ),
    );
    final (coordinator, router) = await _pumpHandlerHarness(
      tester,
      auth: auth,
      initialLocation: OnboardingRoutes.ownerCarousel,
    );
    await handleEmailVerificationLink(
      authRepository: auth,
      coordinator: coordinator,
      router: router,
      uri: _verifyUri,
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('expired or was already used'),
      findsOneWidget,
    );
  });

  group('AppShellUi.whenReady', () {
    Widget shell() => MaterialApp(
          scaffoldMessengerKey: rootScaffoldMessengerKey,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: Text('home')),
        );

    testWidgets('waits for a shell that mounts on the next frame',
        (tester) async {
      var shown = 0;
      AppShellUi.whenReady((messenger, l10n) => shown++);
      expect(shown, 0);

      await tester.pumpWidget(shell());
      await tester.pump();

      expect(shown, 1);
    });

    testWidgets('gives up after maxWaitFrames when no shell mounts',
        (tester) async {
      var shown = 0;
      AppShellUi.whenReady((messenger, l10n) => shown++);
      for (var i = 0; i <= AppShellUi.maxWaitFrames + 1; i++) {
        await tester.pump();
      }
      expect(tester.binding.hasScheduledFrame, isFalse);

      await tester.pumpWidget(shell());
      await tester.pump();
      expect(shown, 0);
    });
  });
}
