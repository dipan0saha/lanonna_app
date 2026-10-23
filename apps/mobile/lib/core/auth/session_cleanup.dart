import '../../features/account/data/account_repository.dart';
import '../../features/account/data/notifications_repository.dart';
import '../../features/calendar/data/calendar_repository.dart';
import '../../features/gallery/data/gallery_repository.dart';
import '../../features/home/data/home_repository.dart';
import '../../features/home/data/selected_baby_store.dart';
import '../../features/invitations/presentation/invite_flow_state.dart';
import '../../features/onboarding/presentation/onboarding_coordinator.dart';
import '../media/signed_image_cache.dart';

/// Clears local user-scoped state on sign-out and account deletion.
///
/// Every in-memory repository cache is dropped here, so the next account
/// never sees the previous one's babies, profile, unread count, photos or
/// events.
class SessionCleanup {
  SessionCleanup({
    required OnboardingCoordinator coordinator,
    required HomeRepository homeRepository,
    required SelectedBabyStore selectedBabyStore,
    required InviteFlowState inviteFlowState,
    AccountRepository? accountRepository,
    NotificationsRepository? notificationsRepository,
    GalleryRepository? galleryRepository,
    CalendarRepository? calendarRepository,
    Future<void> Function() evictImageCaches = evictSignedImageCaches,
  })  : _evictImageCaches = evictImageCaches,
        _coordinator = coordinator,
        _homeRepository = homeRepository,
        _selectedBabyStore = selectedBabyStore,
        _inviteFlowState = inviteFlowState,
        _accountRepository = accountRepository,
        _notificationsRepository = notificationsRepository,
        _galleryRepository = galleryRepository,
        _calendarRepository = calendarRepository;

  final OnboardingCoordinator _coordinator;
  final HomeRepository _homeRepository;
  final SelectedBabyStore _selectedBabyStore;
  final InviteFlowState _inviteFlowState;
  final AccountRepository? _accountRepository;
  final NotificationsRepository? _notificationsRepository;
  final GalleryRepository? _galleryRepository;
  final CalendarRepository? _calendarRepository;

  /// Drops decoded and on-disk signed image caches. Injectable because the
  /// on-disk cache needs platform plugins that widget tests do not have.
  final Future<void> Function() _evictImageCaches;

  Future<void> clearLocalUserData() async {
    _inviteFlowState.clear();
    await _coordinator.clearLocalSessionForSignOut();
    _homeRepository.clearCachedBabies();
    _accountRepository?.clearCachedAccount();
    _notificationsRepository?.clearUnreadCount();
    _galleryRepository?.clearCachedPhotos();
    _calendarRepository?.clearCachedEvents();
    await _selectedBabyStore.clearSelectedBabyId();
    await _evictImageCaches();
  }
}
