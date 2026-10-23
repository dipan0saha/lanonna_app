import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/config/app_config.dart';
import 'package:lanonna/core/auth/biometric_app_lock_policy.dart';

void main() {
  test('engages only when signed in, past onboarding, flag on', () {
    expect(
      biometricAppLockShouldEngage(
        isSignedIn: true,
        canAccessMainApp: true,
        isOnboardingPath: false,
        biometricUnlockEnabled: true,
      ),
      isTrue,
    );
    expect(
      biometricAppLockShouldEngage(
        isSignedIn: false,
        canAccessMainApp: true,
        isOnboardingPath: false,
        biometricUnlockEnabled: true,
      ),
      isFalse,
    );
    expect(
      biometricAppLockShouldEngage(
        isSignedIn: true,
        canAccessMainApp: false,
        isOnboardingPath: false,
        biometricUnlockEnabled: true,
      ),
      isFalse,
    );
    expect(
      biometricAppLockShouldEngage(
        isSignedIn: true,
        canAccessMainApp: true,
        isOnboardingPath: true,
        biometricUnlockEnabled: true,
      ),
      isFalse,
    );
    expect(
      biometricAppLockShouldEngage(
        isSignedIn: true,
        canAccessMainApp: true,
        isOnboardingPath: false,
        biometricUnlockEnabled: false,
      ),
      isFalse,
    );
  });

  test('resume engages only after the grace period', () {
    const grace = biometricAppLockResumeGracePeriod;
    expect(
      biometricAppLockShouldEngageOnResume(
        timeInBackground: grace - const Duration(seconds: 1),
      ),
      isFalse,
    );
    expect(
      biometricAppLockShouldEngageOnResume(timeInBackground: grace),
      isTrue,
    );
    expect(
      biometricAppLockShouldEngageOnResume(
        timeInBackground: grace + const Duration(seconds: 5),
      ),
      isTrue,
    );
  });
}
