import '../../features/home/data/home_repository.dart';
import '../../features/home/data/selected_baby_store.dart';
import '../../features/onboarding/presentation/onboarding_coordinator.dart';
import '../media/signed_image_cache.dart';

/// Clears local user-scoped state on sign-out and account deletion.
class SessionCleanup {
  SessionCleanup({
    required OnboardingCoordinator coordinator,
    required HomeRepository homeRepository,
    required SelectedBabyStore selectedBabyStore,
  })  : _coordinator = coordinator,
        _homeRepository = homeRepository,
        _selectedBabyStore = selectedBabyStore;

  final OnboardingCoordinator _coordinator;
  final HomeRepository _homeRepository;
  final SelectedBabyStore _selectedBabyStore;

  Future<void> clearLocalUserData() async {
    await _coordinator.clearLocalSessionForSignOut();
    _homeRepository.clearCachedBabies();
    await _selectedBabyStore.clearSelectedBabyId();
    await evictSignedImageCaches();
  }
}
