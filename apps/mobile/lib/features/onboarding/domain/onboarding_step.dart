enum OnboardingStep {
  carousel,
  signup,
  login,
  emailVerify,
  completeProfile,
  createBaby,
  firstMoment,
  batchInvite,
  followerInvite,
  coOwnerInvite,
  confirmRelationship,
  followerCarousel,
  coOwnerWelcome,
}

extension OnboardingStepStorage on OnboardingStep {
  String get storageKey => name;

  static OnboardingStep? fromStorage(String? value) {
    if (value == null) return null;
    for (final step in OnboardingStep.values) {
      if (step.name == value) return step;
    }
    return null;
  }
}
