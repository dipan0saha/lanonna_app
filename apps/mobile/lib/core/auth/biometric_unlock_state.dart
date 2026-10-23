import 'biometric_sign_in_store.dart';

/// Whether **Biometric sign-in & unlock** is fully active on this install for
/// the signed-in account.
///
/// Requires the server flag, a local hardware enrollment, and a matching
/// Firebase uid. See docs/engineering/rca/biometric-toggle-after-other-account-sign-in.md.
bool biometricUnlockActiveOnDevice({
  required bool serverBiometricUnlockEnabled,
  required BiometricSignInEnrollment? localEnrollment,
  required String signedInFirebaseUid,
}) {
  if (!serverBiometricUnlockEnabled) return false;
  final local = localEnrollment;
  if (local == null) return false;
  return local.firebaseUid == signedInFirebaseUid;
}
