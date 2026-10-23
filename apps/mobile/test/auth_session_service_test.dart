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

class _FakeFirebaseAuth extends Fake implements FirebaseAuth {}

class _User extends Fake implements User {
  _User(this.uid);

  @override
  final String uid;
}

class _StubApi extends ApiClient {
  _StubApi() : super(idTokenProvider: () async => 'token');
}

class _Auth extends AuthRepository {
  _Auth(this.calls) : super(firebaseAuth: _FakeFirebaseAuth());

  final List<String> calls;

  @override
  User? get currentUser => _User('uid-a');

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

Future<AuthSessionService> _service(
  List<String> calls, {
  Duration pushDelay = Duration.zero,
  Duration timeout = const Duration(seconds: 3),
  String enrolledUid = 'uid-a',
  bool withPush = true,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return AuthSessionService(
    authRepository: _Auth(calls),
    sessionCleanup: _Cleanup(calls, prefs),
    biometricSignInService: _Biometric(calls, enrolledUid: enrolledUid),
    pushNotificationService: withPush ? _Push(calls, delay: pushDelay) : null,
    pushUnregisterTimeout: timeout,
  );
}

void main() {
  test('signOut: server unregister, then local cleanup, then Firebase; '
      'biometric enrollment survives', () async {
    final calls = <String>[];
    final session = await _service(calls);

    await session.signOut();

    expect(calls, [
      'unregisterStarted',
      'unregisterDone',
      'clearLocal',
      'firebaseSignOut',
    ]);
  });

  test('a slow unregister is abandoned at the timeout', () async {
    final calls = <String>[];
    final session = await _service(
      calls,
      pushDelay: const Duration(seconds: 5),
      timeout: const Duration(milliseconds: 50),
    );
    final watch = Stopwatch()..start();

    await session.signOut();

    expect(watch.elapsed, lessThan(const Duration(seconds: 1)));
    expect(calls, ['unregisterStarted', 'clearLocal', 'firebaseSignOut']);
  });

  test('signOut works without a push service', () async {
    final calls = <String>[];
    final session = await _service(calls, withPush: false);

    await session.signOut();

    expect(calls, ['clearLocal', 'firebaseSignOut']);
  });

  test('signOutDeletedAccount makes no server call and forgets this '
      "account's enrollment", () async {
    final calls = <String>[];
    final session = await _service(calls);

    await session.signOutDeletedAccount();

    expect(calls, ['clearEnrollment', 'clearLocal', 'firebaseSignOut']);
  });

  test("signOutDeletedAccount keeps another account's enrollment", () async {
    final calls = <String>[];
    final session = await _service(calls, enrolledUid: 'uid-b');

    await session.signOutDeletedAccount();

    expect(calls, ['clearLocal', 'firebaseSignOut']);
  });
}
