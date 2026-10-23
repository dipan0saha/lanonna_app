import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/auth/biometric_sign_in_store.dart';
import 'package:lanonna/core/auth/biometric_unlock_state.dart';

void main() {
  const enrollmentA = BiometricSignInEnrollment(
    credentialId: 'cred',
    firebaseUid: 'uid-a',
    displayName: 'Ana',
  );

  test('inactive when server flag is off', () {
    expect(
      biometricUnlockActiveOnDevice(
        serverBiometricUnlockEnabled: false,
        localEnrollment: enrollmentA,
        signedInFirebaseUid: 'uid-a',
      ),
      isFalse,
    );
  });

  test('inactive when local enrollment is missing', () {
    expect(
      biometricUnlockActiveOnDevice(
        serverBiometricUnlockEnabled: true,
        localEnrollment: null,
        signedInFirebaseUid: 'uid-a',
      ),
      isFalse,
    );
  });

  test('inactive when local enrollment belongs to another account', () {
    expect(
      biometricUnlockActiveOnDevice(
        serverBiometricUnlockEnabled: true,
        localEnrollment: enrollmentA,
        signedInFirebaseUid: 'uid-b',
      ),
      isFalse,
    );
  });

  test('active when server flag and matching local enrollment', () {
    expect(
      biometricUnlockActiveOnDevice(
        serverBiometricUnlockEnabled: true,
        localEnrollment: enrollmentA,
        signedInFirebaseUid: 'uid-a',
      ),
      isTrue,
    );
  });

  test('issue #375: server on after other account cleared local slot', () {
    expect(
      biometricUnlockActiveOnDevice(
        serverBiometricUnlockEnabled: true,
        localEnrollment: null,
        signedInFirebaseUid: 'uid-a',
      ),
      isFalse,
    );
  });
}
