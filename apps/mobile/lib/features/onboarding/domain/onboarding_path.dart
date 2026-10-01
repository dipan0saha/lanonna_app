enum OnboardingPath {
  owner,
  follower,
  coOwner;

  String get storageKey => name;

  String get signupQueryValue => switch (this) {
        OnboardingPath.owner => 'owner',
        OnboardingPath.follower => 'follower',
        OnboardingPath.coOwner => 'coOwner',
      };

  static OnboardingPath? fromStorage(String? value) {
    if (value == null) return null;
    for (final path in OnboardingPath.values) {
      if (path.name == value) return path;
    }
    return null;
  }

  static OnboardingPath fromInvitedRole(String? role) {
    if (role == 'owner') return OnboardingPath.coOwner;
    return OnboardingPath.follower;
  }

  static OnboardingPath? fromSignupQuery(String? value) {
    return switch (value) {
      'follower' => OnboardingPath.follower,
      'coOwner' => OnboardingPath.coOwner,
      'owner' => OnboardingPath.owner,
      _ => null,
    };
  }
}
