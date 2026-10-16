import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/features/baby/domain/owner_onboarding_baby_phase.dart';
import 'package:lanonna/features/onboarding/data/onboarding_repository.dart';
import 'package:lanonna/features/onboarding/data/onboarding_storage.dart';
import 'package:lanonna/features/onboarding/presentation/onboarding_coordinator.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('revise when createdBabyId is set', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = OnboardingStorage(prefs);
    final coordinator = OnboardingCoordinator(
      storage: storage,
      repository: OnboardingRepository(ApiClient(idTokenProvider: () async => null)),
    );
    await coordinator.hydrate();
    expect(ownerOnboardingBabyPhaseFor(coordinator), OwnerOnboardingBabyPhase.create);

    await coordinator.setCreatedBabyId('baby-1');
    expect(ownerOnboardingBabyPhaseFor(coordinator), OwnerOnboardingBabyPhase.revise);
  });
}
