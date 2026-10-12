import '../../features/home/data/home_repository.dart';
import '../../features/home/data/selected_baby_store.dart';
import '../../features/invitations/presentation/invite_flow_state.dart';
import '../../features/onboarding/presentation/onboarding_coordinator.dart';
import '../media/signed_image_cache.dart';

/// Clears local user-scoped state on sign-out and account deletion.
class SessionCleanup {
  SessionCleanup({
    required OnboardingCoordinator coordinator,
    required HomeRepository homeRepository,
    required SelectedBabyStore selectedBabyStore,
    required InviteFlowState inviteFlowState,
  })  : _coordinator = coordinator,
        _homeRepository = homeRepository,
        _selectedBabyStore = selectedBabyStore,
        _inviteFlowState = inviteFlowState;

  final OnboardingCoordinator _coordinator;
  final HomeRepository _homeRepository;
  final SelectedBabyStore _selectedBabyStore;
  final InviteFlowState _inviteFlowState;

  Future<void> clearLocalUserData() async {
    _inviteFlowState.clear();
    await _coordinator.clearLocalSessionForSignOut();
    _homeRepository.clearCachedBabies();
    await _selectedBabyStore.clearSelectedBabyId();
    await evictSignedImageCaches();
  }
}
