import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/auth/auth_repository.dart';
import 'package:lanonna/core/auth/auth_session_service.dart';
import 'package:lanonna/core/auth/biometric_sign_in_service.dart';
import 'package:lanonna/core/auth/biometric_sign_in_store.dart';
import 'package:lanonna/core/auth/session_cleanup.dart';
import 'package:lanonna/core/notifications/push_notification_service.dart';
import 'package:lanonna/features/account/data/notifications_repository.dart';
import 'package:lanonna/features/home/data/home_repository.dart';
import 'package:lanonna/features/home/data/selected_baby_store.dart';
import 'package:lanonna/features/invitations/presentation/invite_flow_state.dart';
import 'package:lanonna/features/onboarding/data/onboarding_repository.dart';
import 'package:lanonna/features/onboarding/data/onboarding_storage.dart';
import 'package:lanonna/features/onboarding/presentation/onboarding_coordinator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeFirebaseAuth extends Fake implements FirebaseAuth {
  _FakeFirebaseAuth(this.controller);

  final StreamController<User?> controller;

  @override
  Stream<User?> authStateChanges() => controller.stream;
}

class _User extends Fake implements User {
  _User(this.uid);

  @override
  final String uid;
}

class _StubApi extends ApiClient {
  _StubApi() : super(idTokenProvider: () async => 'token');
}

class _Auth extends AuthRepository {
  _Auth(this.calls, {User? user, required StreamController<User?> authController})
    : _user = user ?? _User('uid-a'),
      super(firebaseAuth: _FakeFirebaseAuth(authController));

  final List<String> calls;
  User? _user;

  @override
  User? get currentUser => _user;

  void debugSetUser(User? user) => _user = user;

  @override
  Future<void> signOut() async => calls.add('firebaseSignOut');
}

class _Push extends PushNotificationService {
  _Push(this.calls, {this.delay = Duration.zero})
    : super(NotificationsRepository(_StubApi()));

  final List<String> calls;
  final Duration delay;

  @override
  Future<void> unregisterFromServer() async {
    calls.add('unregisterStarted');
    await Future<void>.delayed(delay);
    calls.add('unregisterDone');
  }
}

class _Cleanup extends SessionCleanup {
  _Cleanup(this.calls, SharedPreferences prefs)
    : super(
        coordinator: OnboardingCoordinator(
          storage: OnboardingStorage(prefs),
          repository: OnboardingRepository(_StubApi()),
        ),
        homeRepository: HomeRepository(_StubApi()),
        selectedBabyStore: SelectedBabyStore(prefs),
        inviteFlowState: InviteFlowState(),
      );

  final List<String> calls;

  @override
  Future<void> clearLocalUserData() async => calls.add('clearLocal');
}

class _Biometric extends Fake implements BiometricSignInService {
  _Biometric(this.calls, {required this.enrolledUid});

  final List<String> calls;
  final String enrolledUid;

  @override
  BiometricSignInEnrollment? get enrollment => BiometricSignInEnrollment(
    credentialId: 'cred-1',
    firebaseUid: enrolledUid,
  );

  @override
  Future<void> clearLocalEnrollment() async => calls.add('clearEnrollment');
}

Future<({
  AuthSessionService session,
  _Auth auth,
  StreamController<User?> authEvents,
  _Cleanup cleanup,
})> _service(
  List<String> calls, {
  Duration pushDelay = Duration.zero,
  Duration timeout = const Duration(seconds: 3),
  String enrolledUid = 'uid-a',
  bool withPush = true,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final authEvents = StreamController<User?>();
  final auth = _Auth(calls, authController: authEvents);
  final cleanup = _Cleanup(calls, prefs);
  final session = AuthSessionService(
    authRepository: auth,
    sessionCleanup: cleanup,
    biometricSignInService: _Biometric(calls, enrolledUid: enrolledUid),
    pushNotificationService: withPush ? _Push(calls, delay: pushDelay) : null,
    pushUnregisterTimeout: timeout,
  );
  return (session: session, auth: auth, authEvents: authEvents, cleanup: cleanup);
}

void main() {
  test('signOut: server unregister, then local cleanup, then Firebase; '
      'biometric enrollment survives', () async {
    final calls = <String>[];
    final f = await _service(calls);

    await f.session.signOut();

    expect(calls, [
      'unregisterStarted',
      'unregisterDone',
      'clearLocal',
      'firebaseSignOut',
    ]);
  });

  test('a slow unregister is abandoned at the timeout', () async {
    final calls = <String>[];
    final f = await _service(
      calls,
      pushDelay: const Duration(seconds: 5),
      timeout: const Duration(milliseconds: 50),
    );
    final watch = Stopwatch()..start();

    await f.session.signOut();

    expect(watch.elapsed, lessThan(const Duration(seconds: 1)));
    expect(calls, ['unregisterStarted', 'clearLocal', 'firebaseSignOut']);
  });

  test('signOut works without a push service', () async {
    final calls = <String>[];
    final f = await _service(calls, withPush: false);

    await f.session.signOut();

    expect(calls, ['clearLocal', 'firebaseSignOut']);
  });

  test('signOutDeletedAccount makes no server call and forgets this '
      "account's enrollment", () async {
    final calls = <String>[];
    final f = await _service(calls);

    await f.session.signOutDeletedAccount();

    expect(calls, ['clearEnrollment', 'clearLocal', 'firebaseSignOut']);
  });

  test("signOutDeletedAccount keeps another account's enrollment", () async {
    final calls = <String>[];
    final f = await _service(calls, enrolledUid: 'uid-b');

    await f.session.signOutDeletedAccount();

    expect(calls, ['clearLocal', 'firebaseSignOut']);
  });

  test('switching Firebase user clears local session without signOut', () async {
    final calls = <String>[];
    final f = await _service(calls);
    var switched = false;
    f.session.bindUserScopedSession(
      authStateChanges: f.authEvents.stream,
      onSignedIn: () async => calls.add('signedIn'),
      onUserSwitched: () async {
        switched = true;
        calls.add('switched');
        await f.cleanup.clearLocalUserData();
      },
    );
    f.auth.debugSetUser(_User('uid-a'));
    f.authEvents.add(_User('uid-a'));
    await Future<void>.delayed(Duration.zero);
    expect(calls, isEmpty);

    f.auth.debugSetUser(_User('uid-b'));
    f.authEvents.add(_User('uid-b'));
    await Future<void>.delayed(Duration.zero);
    expect(switched, isTrue);
    expect(calls, contains('switched'));
    expect(calls, contains('clearLocal'));

    f.session.disposeUserScopedSession();
    await f.authEvents.close();
  });
}
