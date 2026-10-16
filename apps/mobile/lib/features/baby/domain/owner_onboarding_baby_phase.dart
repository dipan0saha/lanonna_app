import '../../onboarding/presentation/onboarding_coordinator.dart';

enum OwnerOnboardingBabyPhase { create, revise }

OwnerOnboardingBabyPhase ownerOnboardingBabyPhaseFor(OnboardingCoordinator coordinator) {
  final id = coordinator.createdBabyId;
  if (id != null && id.isNotEmpty) {
    return OwnerOnboardingBabyPhase.revise;
  }
  return OwnerOnboardingBabyPhase.create;
}
