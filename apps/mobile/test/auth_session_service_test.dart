import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/auth/auth_repository.dart';
import 'package:lanonna/core/auth/auth_session_service.dart';
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

class _RecordingAuth extends AuthRepository {
  var signOutCalls = 0;

  @override
  Future<void> signOut() async {
    signOutCalls++;
  }
}

class _RecordingPush extends PushNotificationService {
  _RecordingPush() : super(NotificationsRepository(_StubApi()));

  var unregisterCalls = 0;

  @override
  Future<void> unregisterBeforeSignOut() async {
    unregisterCalls++;
  }
}

class _SlowPush extends PushNotificationService {
  _SlowPush() : super(NotificationsRepository(_StubApi()));

  @override
  Future<void> unregisterBeforeSignOut() async {
    await Future<void>.delayed(const Duration(seconds: 5));
  }
}

class _RecordingCleanup extends SessionCleanup {
  _RecordingCleanup({
    required OnboardingCoordinator coordinator,
    required HomeRepository homeRepository,
    required SelectedBabyStore selectedBabyStore,
    required InviteFlowState inviteFlowState,
  }) : super(
          coordinator: coordinator,
          homeRepository: homeRepository,
          selectedBabyStore: selectedBabyStore,
          inviteFlowState: inviteFlowState,
        );

  var clearCalls = 0;

  @override
  Future<void> clearLocalUserData() async {
    clearCalls++;
  }
}

class _StubApi extends ApiClient {
  _StubApi() : super(idTokenProvider: () async => 'token');
}

Future<SessionCleanup> _baseCleanup() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return SessionCleanup(
    coordinator: OnboardingCoordinator(
      storage: OnboardingStorage(prefs),
      repository: OnboardingRepository(_StubApi()),
    ),
    homeRepository: HomeRepository(_StubApi()),
    selectedBabyStore: SelectedBabyStore(prefs),
    inviteFlowState: InviteFlowState(),
  );
}

void main() {
  test('signOut unregisters push, clears local data, then Firebase sign-out', () async {
    final auth = _RecordingAuth();
    final push = _RecordingPush();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final cleanup = _RecordingCleanup(
      coordinator: OnboardingCoordinator(
        storage: OnboardingStorage(prefs),
        repository: OnboardingRepository(_StubApi()),
      ),
      homeRepository: HomeRepository(_StubApi()),
      selectedBabyStore: SelectedBabyStore(prefs),
      inviteFlowState: InviteFlowState(),
    );
    final session = AuthSessionService(
      authRepository: auth,
      sessionCleanup: cleanup,
      pushNotificationService: push,
    );

    await session.signOut();

    expect(push.unregisterCalls, 1);
    expect(cleanup.clearCalls, 1);
    expect(auth.signOutCalls, 1);
  });

  test('signOut continues when push unregister times out', () async {
    final auth = _RecordingAuth();
    final push = _SlowPush();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final cleanup = _RecordingCleanup(
      coordinator: OnboardingCoordinator(
        storage: OnboardingStorage(prefs),
        repository: OnboardingRepository(_StubApi()),
      ),
      homeRepository: HomeRepository(_StubApi()),
      selectedBabyStore: SelectedBabyStore(prefs),
      inviteFlowState: InviteFlowState(),
    );
    final session = AuthSessionService(
      authRepository: auth,
      sessionCleanup: cleanup,
      pushNotificationService: push,
      pushUnregisterTimeout: const Duration(milliseconds: 50),
    );

    await session.signOut();

    expect(cleanup.clearCalls, 1);
    expect(auth.signOutCalls, 1);
  });

  test('signOut works without a push service', () async {
    final auth = _RecordingAuth();
    final cleanup = await _baseCleanup();
    final session = AuthSessionService(
      authRepository: auth,
      sessionCleanup: cleanup,
    );

    await session.signOut();

    expect(auth.signOutCalls, 1);
  });
}
