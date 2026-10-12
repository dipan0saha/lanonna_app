class OnboardingStatus {
  const OnboardingStatus({
    required this.emailVerified,
    required this.profileComplete,
    required this.hasOwnerBaby,
    required this.hasBabyMembership,
    required this.ownerOnboardingCompleted,
    required this.needsOwnerOnboarding,
    required this.canAccessMainApp,
    this.ownerOnboardingBabyProfileId,
  });

  final bool emailVerified;
  final bool profileComplete;
  final bool hasOwnerBaby;
  final bool hasBabyMembership;
  final bool ownerOnboardingCompleted;
  final bool needsOwnerOnboarding;
  final bool canAccessMainApp;
  final String? ownerOnboardingBabyProfileId;

  Map<String, dynamic> toJson() => {
    'email_verified': emailVerified,
    'profile_complete': profileComplete,
    'has_owner_baby': hasOwnerBaby,
    'has_baby_membership': hasBabyMembership,
    'owner_onboarding_completed': ownerOnboardingCompleted,
    'needs_owner_onboarding': needsOwnerOnboarding,
    'can_access_main_app': canAccessMainApp,
    'owner_onboarding_baby_profile_id': ownerOnboardingBabyProfileId,
  };

  factory OnboardingStatus.fromJson(Map<String, dynamic> json) {
    final profileComplete = json['profile_complete'] as bool? ?? false;
    final ownerDone = json['owner_onboarding_completed'] as bool? ?? false;
    final hasMembership = json['has_baby_membership'] as bool? ?? false;
    final hasOwnerBaby = json['has_owner_baby'] as bool? ?? false;
    final canAccess = json['can_access_main_app'] as bool?;
    final needsOwnerOnboarding =
        json['needs_owner_onboarding'] as bool? ??
        (!ownerDone && hasOwnerBaby && canAccess != true);
    final ownerBabyId = json['owner_onboarding_baby_profile_id']?.toString();
    return OnboardingStatus(
      emailVerified: json['email_verified'] as bool? ?? false,
      profileComplete: profileComplete,
      hasOwnerBaby: hasOwnerBaby,
      hasBabyMembership: hasMembership,
      ownerOnboardingCompleted: ownerDone,
      needsOwnerOnboarding: needsOwnerOnboarding,
      canAccessMainApp:
          json['can_access_main_app'] as bool? ??
          (profileComplete &&
              (ownerDone || (hasMembership && !needsOwnerOnboarding))),
      ownerOnboardingBabyProfileId:
          ownerBabyId != null && ownerBabyId.isNotEmpty ? ownerBabyId : null,
    );
  }
}
