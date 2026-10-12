import '../data/models/onboarding_status.dart';
import '../presentation/onboarding_coordinator.dart';

/// Resolves the baby profile id for owner onboarding (first moment, batch invite).
///
/// Prefers local coordinator cache, then server status, with one optional refresh.
class OwnerOnboardingBabyResolver {
  const OwnerOnboardingBabyResolver._();

  static Future<String?> resolve({
    required OnboardingCoordinator coordinator,
    required OnboardingStatus? Function() readStatus,
    Future<void> Function()? refreshStatus,
    bool allowRefresh = true,
  }) async {
    final fromCache = await _persistFromCoordinatorOrStatus(
      coordinator,
      readStatus(),
    );
    if (fromCache != null) {
      return fromCache;
    }

    final needsOwner = readStatus()?.needsOwnerOnboarding ?? false;
    if (!allowRefresh || !needsOwner || refreshStatus == null) {
      return null;
    }

    await refreshStatus();
    return _persistFromCoordinatorOrStatus(coordinator, readStatus());
  }

  static Future<String?> _persistFromCoordinatorOrStatus(
    OnboardingCoordinator coordinator,
    OnboardingStatus? status,
  ) async {
    final local = coordinator.createdBabyId;
    if (local != null && local.isNotEmpty) {
      return local;
    }
    final fromStatus = status?.ownerOnboardingBabyProfileId;
    if (fromStatus != null && fromStatus.isNotEmpty) {
      await coordinator.setCreatedBabyId(fromStatus);
      return fromStatus;
    }
    return null;
  }
}
