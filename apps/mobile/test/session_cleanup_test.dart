import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/auth/session_cleanup.dart';
import 'package:lanonna/features/home/data/home_repository.dart';
import 'package:lanonna/features/home/data/selected_baby_store.dart';
import 'package:lanonna/features/onboarding/data/onboarding_repository.dart';
import 'package:lanonna/features/onboarding/data/onboarding_storage.dart';
import 'package:lanonna/features/onboarding/presentation/onboarding_coordinator.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('clearLocalUserData wipes invite, baby selection, and onboarding flags', () async {
    SharedPreferences.setMockInitialValues({
      'selected_baby_id': 'baby-1',
      OnboardingStorageKeys.pendingInviteToken: 'secret-token',
      OnboardingStorageKeys.invitePreviewJson: '{"status":"pending"}',
      OnboardingStorageKeys.completed: true,
      OnboardingStorageKeys.inviteOnboardingCompleted: true,
    });
    final prefs = await SharedPreferences.getInstance();
    final storage = OnboardingStorage(prefs);
    final coordinator = OnboardingCoordinator(
      storage: storage,
      repository: OnboardingRepository(_StubApi()),
    );
    await coordinator.hydrate();
    final store = SelectedBabyStore(prefs);
    final homeRepo = HomeRepository(_StubApi(), currentUserId: () => 'user-a');
    await homeRepo.listBabies();

    final cleanup = SessionCleanup(
      coordinator: coordinator,
      homeRepository: homeRepo,
      selectedBabyStore: store,
    );
    await cleanup.clearLocalUserData();

    expect(store.selectedBabyId, isNull);
    expect(prefs.getString(OnboardingStorageKeys.pendingInviteToken), isNull);
    expect(prefs.getString(OnboardingStorageKeys.invitePreviewJson), isNull);
    expect(storage.isCompleted, isFalse);
    expect(storage.inviteOnboardingCompleted, isFalse);
  });
}

class _StubApi extends ApiClient {
  _StubApi() : super(idTokenProvider: () async => 'token');

  @override
  Future<List<dynamic>> getJsonList(
    String path, {
    Map<String, String>? queryParameters,
  }) async {
    return [
      {'id': 'baby-1', 'name': 'One', 'role': 'owner', 'lifecycle_status': 'expecting'},
    ];
  }
}
