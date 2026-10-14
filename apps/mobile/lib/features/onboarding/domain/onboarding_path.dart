enum OnboardingPath {
  owner,
  follower,
  coOwner;

  String get storageKey => name;

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
}
