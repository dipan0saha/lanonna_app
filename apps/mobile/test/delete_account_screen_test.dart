import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/auth/auth_repository.dart';
import 'package:lanonna/core/auth/biometric_sign_in_service.dart';
import 'package:lanonna/core/auth/biometric_sign_in_store.dart';
import 'package:lanonna/core/auth/auth_session_service.dart';
import 'package:lanonna/core/auth/session_cleanup.dart';
import 'package:lanonna/features/account/data/account_repository.dart';
import 'package:lanonna/features/account/presentation/delete_account_screen.dart';
import 'package:lanonna/features/home/data/home_repository.dart';
import 'package:lanonna/features/home/data/selected_baby_store.dart';
import 'package:lanonna/features/invitations/presentation/invite_flow_state.dart';
import 'package:lanonna/features/onboarding/data/onboarding_repository.dart';
import 'package:lanonna/features/onboarding/data/onboarding_storage.dart';
import 'package:lanonna/features/onboarding/domain/onboarding_routes.dart';
import 'package:lanonna/features/onboarding/presentation/onboarding_coordinator.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:lanonna/l10n/app_localizations_en.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeFirebaseAuth extends Fake implements FirebaseAuth {}

class _User extends Fake implements User {
  @override
  String get uid => 'uid-deleted';
}

class _Biometric extends Fake implements BiometricSignInService {
  var cleared = 0;

  @override
  BiometricSignInEnrollment? get enrollment => const BiometricSignInEnrollment(
    credentialId: 'cred-1',
    firebaseUid: 'uid-deleted',
  );

  @override
  Future<void> clearLocalEnrollment() async => cleared++;
}

class _Auth extends AuthRepository {
  _Auth({this.password = false, this.google = false})
    : super(firebaseAuth: _FakeFirebaseAuth());

  final bool password;
  final bool google;
  var signOuts = 0;
  String? reauthPassword;
  var googleReauths = 0;

  @override
  User? get currentUser => _User();

  @override
  bool get usesPasswordProvider => password;

  @override
  bool get usesGoogleProvider => google;

  @override
  Future<void> reauthenticateWithPassword(String value) async {
    reauthPassword = value;
  }

  @override
  Future<void> reauthenticateWithGoogle() async {
    googleReauths++;
  }

  @override
  Future<void> signOut() async {
    signOuts++;
  }
}

class _Accounts extends AccountRepository {
  _Accounts(this.preview)
    : super(ApiClient(idTokenProvider: () async => 't'));

  final DeleteAccountPreview preview;
  var deletes = 0;

  @override
  Future<DeleteAccountPreview> fetchDeleteAccountPreview() async {
    return preview;
  }

  @override
  Future<void> deleteAccount() async {
    deletes++;
  }
}

class _Cleanup extends SessionCleanup {
  _Cleanup(SharedPreferences prefs)
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

AuthSessionService _sessionService(
  _Auth auth,
  _Cleanup cleanup,
  _Biometric biometric,
) {
  return AuthSessionService(
    authRepository: auth,
    sessionCleanup: cleanup,
    biometricSignInService: biometric,
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required _Accounts accounts,
  required _Auth auth,
  required _Cleanup cleanup,
  _Biometric? biometric,
}) async {
  final bio = biometric ?? _Biometric();
  final router = GoRouter(
    initialLocation: '/account/delete',
    routes: [
      GoRoute(
        path: '/account/delete',
        builder: (_, _) => const DeleteAccountScreen(),
      ),
      GoRoute(
        path: OnboardingRoutes.ownerCarousel,
        builder: (_, _) => const Scaffold(body: Text('signed out')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<AccountRepository>.value(value: accounts),
        Provider<AuthRepository>.value(value: auth),
        Provider<SessionCleanup>.value(value: cleanup),
        Provider<AuthSessionService>.value(
          value: _sessionService(auth, cleanup, bio),
        ),
              ],
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('delete account copy matches FR-SET-005', () {
    final l10n = AppLocalizationsEn();
    expect(
      l10n.deleteAccountBody,
      contains('solely owned by your account will also be deleted'),
    );
    expect(l10n.deleteAccountBody, contains('co-owner will not be deleted'));
    expect(l10n.deleteAccountBody, contains('photos you uploaded'));
    expect(l10n.deleteAccountButton, 'Delete my account');
    expect(l10n.deleteAccountConfirmTitle, 'Delete your account permanently?');
  });

  testWidgets('cancel leaves the account in place', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final accounts = _Accounts(
      const DeleteAccountPreview(
        soleOwnedBabies: [
          SoleOwnedBaby(id: 'b1', name: 'Liam'),
          SoleOwnedBaby(id: 'b2', name: ' '),
        ],
      ),
    );
    final auth = _Auth();
    await _pump(
      tester,
      accounts: accounts,
      auth: auth,
      cleanup: _Cleanup(prefs),
    );

    await tester.tap(find.text('Delete my account'));
    await tester.pumpAndSettle();

    expect(find.text('Delete your account permanently?'), findsOneWidget);
    expect(find.textContaining('• Liam'), findsOneWidget);
    expect(find.textContaining('• Baby'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(accounts.deletes, 0);
    expect(auth.signOuts, 0);
    expect(find.text('signed out'), findsNothing);
  });

  testWidgets('confirm deletes once and signs out', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final accounts = _Accounts(
      const DeleteAccountPreview(),
    );
    final auth = _Auth();
    final cleanup = _Cleanup(prefs);
    final biometric = _Biometric();
    await _pump(
      tester,
      accounts: accounts,
      auth: auth,
      cleanup: cleanup,
      biometric: biometric,
    );

    await tester.tap(find.text('Delete my account'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Delete account'));
    await tester.pumpAndSettle();

    expect(accounts.deletes, 1);
    expect(cleanup.cleared, isTrue);
    expect(biometric.cleared, 1);
    expect(auth.signOuts, 1);
    expect(find.text('signed out'), findsOneWidget);
  });

  testWidgets('password accounts reauthenticate before delete', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final accounts = _Accounts(
      const DeleteAccountPreview(),
    );
    final auth = _Auth(password: true);
    await _pump(
      tester,
      accounts: accounts,
      auth: auth,
      cleanup: _Cleanup(prefs),
    );

    await tester.tap(find.text('Delete my account'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Delete account'));
    await tester.pumpAndSettle();

    expect(find.text('Confirm your password'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(accounts.deletes, 0);

    await tester.tap(find.text('Delete my account'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Delete account'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'secret-pass');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(auth.reauthPassword, 'secret-pass');
    expect(accounts.deletes, 1);
    expect(auth.signOuts, 1);
  });

  testWidgets('google accounts reauthenticate before delete', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final accounts = _Accounts(
      const DeleteAccountPreview(),
    );
    final auth = _Auth(google: true);
    await _pump(
      tester,
      accounts: accounts,
      auth: auth,
      cleanup: _Cleanup(prefs),
    );

    await tester.tap(find.text('Delete my account'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Delete account'));
    await tester.pumpAndSettle();

    expect(auth.googleReauths, 1);
    expect(accounts.deletes, 1);
    expect(auth.signOuts, 1);
  });
}
