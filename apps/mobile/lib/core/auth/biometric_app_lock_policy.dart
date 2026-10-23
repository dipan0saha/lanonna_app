import '../../config/app_config.dart';

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

/// Whether resume should show the lock after time spent in the background.
bool biometricAppLockShouldEngageOnResume({
  required Duration timeInBackground,
  Duration gracePeriod = biometricAppLockResumeGracePeriod,
}) {
  return timeInBackground >= gracePeriod;
}
