/// When the full-screen biometric lock should engage.
bool biometricAppLockShouldEngage({
  required bool isSignedIn,
  required bool canAccessMainApp,
  required bool isOnboardingPath,
  required bool biometricUnlockEnabled,
}) {
  return isSignedIn &&
      canAccessMainApp &&
      !isOnboardingPath &&
      biometricUnlockEnabled;
}
