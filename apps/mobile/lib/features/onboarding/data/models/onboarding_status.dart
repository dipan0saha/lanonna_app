class OnboardingStatus {
  const OnboardingStatus({
    required this.emailVerified,
    required this.profileComplete,
    required this.hasOwnerBaby,
    required this.hasBabyMembership,
    required this.ownerOnboardingCompleted,
    required this.canAccessMainApp,
  });

  final bool emailVerified;
  final bool profileComplete;
  final bool hasOwnerBaby;
  final bool hasBabyMembership;
  final bool ownerOnboardingCompleted;
  final bool canAccessMainApp;

  factory OnboardingStatus.fromJson(Map<String, dynamic> json) {
    final profileComplete = json['profile_complete'] as bool? ?? false;
    final ownerDone = json['owner_onboarding_completed'] as bool? ?? false;
    final hasMembership = json['has_baby_membership'] as bool? ?? false;
    return OnboardingStatus(
      emailVerified: json['email_verified'] as bool? ?? false,
      profileComplete: profileComplete,
      hasOwnerBaby: json['has_owner_baby'] as bool? ?? false,
      hasBabyMembership: hasMembership,
      ownerOnboardingCompleted: ownerDone,
      canAccessMainApp: json['can_access_main_app'] as bool? ??
          (profileComplete &&
              (ownerDone || (hasMembership && !(json['has_owner_baby'] as bool? ?? false)))),
    );
  }
}
