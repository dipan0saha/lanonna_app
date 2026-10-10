class OnboardingStatus {
  const OnboardingStatus({
    required this.emailVerified,
    required this.profileComplete,
    required this.hasOwnerBaby,
    required this.hasBabyMembership,
    required this.ownerOnboardingCompleted,
    required this.needsOwnerOnboarding,
    required this.canAccessMainApp,
  });

  final bool emailVerified;
  final bool profileComplete;
  final bool hasOwnerBaby;
  final bool hasBabyMembership;
  final bool ownerOnboardingCompleted;
  final bool needsOwnerOnboarding;
  final bool canAccessMainApp;

  factory OnboardingStatus.fromJson(Map<String, dynamic> json) {
    final profileComplete = json['profile_complete'] as bool? ?? false;
    final ownerDone = json['owner_onboarding_completed'] as bool? ?? false;
    final hasMembership = json['has_baby_membership'] as bool? ?? false;
    final hasOwnerBaby = json['has_owner_baby'] as bool? ?? false;
    final canAccess = json['can_access_main_app'] as bool?;
    final needsOwnerOnboarding = json['needs_owner_onboarding'] as bool? ??
        (!ownerDone &&
            hasOwnerBaby &&
            canAccess != true);
    return OnboardingStatus(
      emailVerified: json['email_verified'] as bool? ?? false,
      profileComplete: profileComplete,
      hasOwnerBaby: hasOwnerBaby,
      hasBabyMembership: hasMembership,
      ownerOnboardingCompleted: ownerDone,
      needsOwnerOnboarding: needsOwnerOnboarding,
      canAccessMainApp: json['can_access_main_app'] as bool? ??
          (profileComplete &&
              (ownerDone ||
                  (hasMembership && !needsOwnerOnboarding))),
    );
  }
}
