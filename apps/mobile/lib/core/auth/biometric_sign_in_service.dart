import 'package:biometric_signature/biometric_signature.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'auth_repository.dart';
import 'biometric_credential_repository.dart';
import 'biometric_device_id.dart';
import 'biometric_sign_in_store.dart';

/// Hardware-backed enroll + challenge-response sign-in.
class BiometricSignInService {
  BiometricSignInService({
    required BiometricCredentialRepository credentials,
    required BiometricSignInStore store,
    required AuthRepository authRepository,
    BiometricDeviceId? deviceId,
    BiometricSignature? signaturePlugin,
  })  : _credentials = credentials,
        _store = store,
        _authRepository = authRepository,
        _deviceId = deviceId ?? BiometricDeviceId(),
        _signature = signaturePlugin ?? BiometricSignature();

  static const keyAlias = 'lanonna.biometric.sign_in';
  static const algorithm = 'ECDSA_SHA256';

  final BiometricCredentialRepository _credentials;
  final BiometricSignInStore _store;
  final AuthRepository _authRepository;
  final BiometricDeviceId _deviceId;
  final BiometricSignature _signature;

  Future<BiometricSignInEnrollment?> localEnrollment() => _store.read();

  Future<bool> hasLocalEnrollment() async {
    final enrollment = await _store.read();
    return enrollment != null;
  }

  Future<void> enrollAfterBiometricUnlockEnabled({
    required String firebaseUid,
    required String accountHint,
    required String promptMessage,
  }) async {
    await _signature.deleteKeys(keyAlias: keyAlias);
    final keys = await _signature.createKeys(
      keyAlias: keyAlias,
      keyFormat: KeyFormat.pem,
      promptMessage: promptMessage,
      config: CreateKeysConfig(
        signatureType: SignatureType.ecdsa,
        enableDecryption: false,
        setInvalidatedByBiometricEnrollment: true,
        enforceBiometric: true,
      ),
    );
    if (keys.publicKey == null || keys.publicKey!.isEmpty) {
      throw BiometricSignInException('Could not create biometric signing key.');
    }
    final deviceId = await _deviceId.getOrCreate();
    final json = await _credentials.enroll(
      deviceId: deviceId,
      publicKeyPem: keys.publicKey!,
      algorithm: algorithm,
    );
    final credentialId = json['id'] as String?;
    if (credentialId == null || credentialId.isEmpty) {
      throw BiometricSignInException('Biometric enrollment failed.');
    }
    await _store.save(
      credentialId: credentialId,
      firebaseUid: firebaseUid,
      accountHint: accountHint,
    );
  }

  Future<void> revokeEnrollment({bool deleteKeys = true}) async {
    final enrollment = await _store.read();
    if (enrollment != null) {
      try {
        await _credentials.revoke(enrollment.credentialId);
      } catch (_) {
        // Best-effort when session is already gone.
      }
    }
    await _store.clear();
    if (deleteKeys) {
      await _signature.deleteKeys(keyAlias: keyAlias);
    }
  }

  /// Clears enrollment when a different Firebase user signs in interactively.
  Future<void> onInteractiveSignInCompleted(User user) async {
    final enrollment = await _store.read();
    if (enrollment == null) return;
    if (enrollment.firebaseUid != null &&
        enrollment.firebaseUid != user.uid) {
      await revokeEnrollment(deleteKeys: true);
    }
  }

  Future<void> signInWithBiometrics({required String promptMessage}) async {
    final enrollment = await _store.read();
    if (enrollment == null) {
      throw BiometricSignInException('No biometric enrollment on this device.');
    }
    final challenge = await _credentials.createChallenge(enrollment.credentialId);
    final nonce = challenge['nonce'] as String?;
    final challengeId = challenge['challenge_id'] as String?;
    if (nonce == null || challengeId == null) {
      throw BiometricSignInException('Could not start biometric sign-in.');
    }
    final signed = await _signature.createSignature(
      payload: nonce,
      keyAlias: keyAlias,
      signatureFormat: SignatureFormat.base64,
      promptMessage: promptMessage,
    );
    final signature = signed.signature;
    if (signature == null || signature.isEmpty) {
      throw BiometricSignInException('Biometric signature was not created.');
    }
    final tokenJson = await _credentials.signIn(
      credentialId: enrollment.credentialId,
      challengeId: challengeId,
      signature: signature,
    );
    final customToken = tokenJson['custom_token'] as String?;
    if (customToken == null || customToken.isEmpty) {
      throw BiometricSignInException('Sign-in token missing.');
    }
    await _authRepository.signInWithCustomToken(customToken);
    await _store.save(
      credentialId: enrollment.credentialId,
      firebaseUid: tokenJson['firebase_uid'] as String? ?? enrollment.firebaseUid ?? '',
      accountHint: enrollment.accountHint ?? '',
    );
  }
}

class BiometricSignInException implements Exception {
  BiometricSignInException(this.message);
  final String message;

  @override
  String toString() => message;
}
