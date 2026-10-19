import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// This install's biometric sign-in enrollment.
///
/// Holds no secret: the private key never leaves the Keystore / Secure
/// Enclave, and the credential id is useless without it. Kept across Log out
/// so the login screen can offer biometric sign-in.
class BiometricSignInStore {
  BiometricSignInStore(this._prefs);

  final SharedPreferences _prefs;

  static const _credentialIdKey = 'biometric_sign_in_credential_id';
  static const _firebaseUidKey = 'biometric_sign_in_firebase_uid';
  static const _displayNameKey = 'biometric_sign_in_display_name';
  static const _deviceIdKey = 'biometric_sign_in_device_id';

  BiometricSignInEnrollment? read() {
    final credentialId = _prefs.getString(_credentialIdKey);
    final firebaseUid = _prefs.getString(_firebaseUidKey);
    if (credentialId == null || firebaseUid == null) return null;
    return BiometricSignInEnrollment(
      credentialId: credentialId,
      firebaseUid: firebaseUid,
      displayName: _prefs.getString(_displayNameKey),
    );
  }

  Future<void> save(BiometricSignInEnrollment enrollment) async {
    await _prefs.setString(_credentialIdKey, enrollment.credentialId);
    await _prefs.setString(_firebaseUidKey, enrollment.firebaseUid);
    final name = enrollment.displayName;
    if (name == null || name.isEmpty) {
      await _prefs.remove(_displayNameKey);
    } else {
      await _prefs.setString(_displayNameKey, name);
    }
  }

  Future<void> clear() async {
    await _prefs.remove(_credentialIdKey);
    await _prefs.remove(_firebaseUidKey);
    await _prefs.remove(_displayNameKey);
  }

  /// Random per-install id, so re-enrolling replaces this install's key on the
  /// server instead of adding another.
  Future<String> deviceId() async {
    final existing = _prefs.getString(_deviceIdKey);
    if (existing != null) return existing;
    final random = Random.secure();
    final id = List.generate(
      16,
      (_) => random.nextInt(256),
    ).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    await _prefs.setString(_deviceIdKey, id);
    return id;
  }
}

class BiometricSignInEnrollment {
  const BiometricSignInEnrollment({
    required this.credentialId,
    required this.firebaseUid,
    this.displayName,
  });

  final String credentialId;
  final String firebaseUid;

  /// First name shown on the login screen ("Continue as …"); never the email.
  final String? displayName;
}
