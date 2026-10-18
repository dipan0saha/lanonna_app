import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/auth/session_cleanup.dart';
import 'package:lanonna/features/account/data/account_repository.dart';
import 'package:lanonna/features/account/data/notifications_repository.dart';
import 'package:lanonna/features/calendar/data/calendar_repository.dart';
import 'package:lanonna/features/gallery/data/gallery_repository.dart';
import 'package:lanonna/features/home/data/home_repository.dart';
import 'package:lanonna/features/home/data/selected_baby_store.dart';
import 'package:lanonna/features/invitations/presentation/invite_flow_state.dart';
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

    final inviteFlowState = InviteFlowState();
    inviteFlowState.setEmailMismatch(inviteeEmail: 'a', signedInEmail: 'b');

    final cleanup = SessionCleanup(
      coordinator: coordinator,
      homeRepository: homeRepo,
      selectedBabyStore: store,
      inviteFlowState: inviteFlowState,
    );
    await cleanup.clearLocalUserData();

    expect(store.selectedBabyId, isNull);
    expect(prefs.getString(OnboardingStorageKeys.pendingInviteToken), isNull);
    expect(prefs.getString(OnboardingStorageKeys.invitePreviewJson), isNull);
    expect(storage.isCompleted, isFalse);
    expect(storage.inviteOnboardingCompleted, isFalse);
    expect(inviteFlowState.emailMismatch, isNull);
  });

  test('clearLocalUserData drops every in-memory user cache', () async {
    SharedPreferences.setMockInitialValues({'selected_baby_id': 'baby-1'});
    final prefs = await SharedPreferences.getInstance();
    final api = _StubApi();
    final coordinator = OnboardingCoordinator(
      storage: OnboardingStorage(prefs),
      repository: OnboardingRepository(api),
    );
    final homeRepo = HomeRepository(api, currentUserId: () => 'user-a');
    final accountRepo = AccountRepository(api);
    final notificationsRepo = NotificationsRepository(api);
    final galleryRepo = GalleryRepository(api);
    await homeRepo.listBabies();
    await homeRepo.fetchHomeSummary('baby-1');
    await accountRepo.ensureAccountLoaded();
    await notificationsRepo.refreshUnreadCount();
    await galleryRepo.listPhotosPage('baby-1');
    await galleryRepo.prefetchPhoto('baby-1', 'photo-1');
    expect(accountRepo.cachedAccount, isNotNull);
    expect(notificationsRepo.unread.count, 4);
    final babyCallsBefore = api.babyListCalls;

    await SessionCleanup(
      coordinator: coordinator,
      homeRepository: homeRepo,
      selectedBabyStore: SelectedBabyStore(prefs),
      inviteFlowState: InviteFlowState(),
      accountRepository: accountRepo,
      notificationsRepository: notificationsRepo,
      galleryRepository: galleryRepo,
      calendarRepository: CalendarRepository(api),
    ).clearLocalUserData();

    expect(homeRepo.cachedHomeSummary('baby-1'), isNull);
    expect(accountRepo.cachedAccount, isNull);
    expect(notificationsRepo.unread.count, 0);
    expect(galleryRepo.photoWindow('baby-1', 'default'), isNull);
    expect(galleryRepo.cachedPhoto('baby-1', 'photo-1'), isNull);
    await homeRepo.listBabies();
    expect(api.babyListCalls, babyCallsBefore + 1,
        reason: 'the next account fetches its own baby list');
  });
}

class _StubApi extends ApiClient {
  _StubApi() : super(idTokenProvider: () async => 'token');

  var babyListCalls = 0;

  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    bool notifyMembershipEnded = true,
  }) async {
    if (path == '/v1/me/account') {
      return {'profile': {'display_name': 'A'}, 'babies': []};
    }
    if (path == '/v1/me/notifications/unread-count') return {'count': 4};
    if (path.endsWith('/home-summary')) return {};
    if (path.contains('/photos/')) {
      return {
        'id': path.split('/').last,
        'created_at': '2026-10-01T12:00:00Z',
      };
    }
    if (path.contains('/photos?')) {
      return {
        'items': [
          {'id': 'photo-1', 'created_at': '2026-10-01T12:00:00Z'},
        ],
        'has_more': false,
      };
    }
    if (path.startsWith('/v1/babies?')) babyListCalls++;
    if (path.startsWith('/v1/babies')) {
      return {
        'items': [
          {
            'id': 'baby-1',
            'name': 'One',
            'role': 'owner',
            'lifecycle_status': 'expecting',
          },
        ],
        'has_more': false,
      };
    }
    return super.getJson(path);
  }
}
