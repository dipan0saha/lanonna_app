class OnboardingStatus {
  const OnboardingStatus({
    required this.emailVerified,
    required this.profileComplete,
    required this.hasOwnerBaby,
    required this.hasBabyMembership,
    required this.ownerOnboardingCompleted,
  });

  final bool emailVerified;
  final bool profileComplete;
  final bool hasOwnerBaby;
  final bool hasBabyMembership;
  final bool ownerOnboardingCompleted;

  factory OnboardingStatus.fromJson(Map<String, dynamic> json) {
    return OnboardingStatus(
      emailVerified: json['email_verified'] as bool? ?? false,
      profileComplete: json['profile_complete'] as bool? ?? false,
      hasOwnerBaby: json['has_owner_baby'] as bool? ?? false,
      hasBabyMembership: json['has_baby_membership'] as bool? ?? false,
      ownerOnboardingCompleted: json['owner_onboarding_completed'] as bool? ?? false,
    );
  }
}
