import 'dart:async';

import 'package:biometric_signature/biometric_signature.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lanonna/l10n/app_localizations.dart';

import '../api/api_error_code.dart';
import '../api/api_exception.dart';
import '../api/localized_failure.dart';
import 'auth_repository.dart';
import 'biometric_credential_repository.dart';
import 'biometric_sign_in_store.dart';
import 'biometric_unlock_state.dart';

/// Biometric sign-in after Log out (design:
/// docs/engineering/rca/biometric-signin-after-logout.md).
///
/// Enrolling creates a hardware-backed P-256 key that only a biometric unlocks
/// and registers its public key. Signing in signs a single-use server nonce
/// with that key; the API answers with a Firebase custom token. Log out keeps
/// the enrollment; turning the setting off, deleting the account, or any other
/// account signing in on this device removes it.
class BiometricSignInService {
  BiometricSignInService({
    required BiometricCredentialRepository credentials,
    required BiometricSignInStore store,
    required AuthRepository authRepository,
    BiometricSignature? signaturePlugin,
  }) : _credentials = credentials,
       _store = store,
       _authRepository = authRepository,
       _signature = signaturePlugin ?? BiometricSignature();

  static const keyAlias = 'lanonna.biometric.sign_in';

  final BiometricCredentialRepository _credentials;
  final BiometricSignInStore _store;
  final AuthRepository _authRepository;
  final BiometricSignature _signature;
  StreamSubscription<User?>? _authSubscription;

  /// This install's enrollment, or `null` when biometric sign-in is not set up.
  BiometricSignInEnrollment? get enrollment => _store.read();

  /// Full on-device activation for the signed-in account (server flag + local
  /// key for this uid). Single source of truth for Settings and app lock.
  bool isUnlockActiveForSignedInUser({
    required bool serverBiometricUnlockEnabled,
  }) {
    final uid = _authRepository.currentUser?.uid;
    if (uid == null) return false;
    return biometricUnlockActiveOnDevice(
      serverBiometricUnlockEnabled: serverBiometricUnlockEnabled,
      localEnrollment: enrollment,
      signedInFirebaseUid: uid,
    );
  }

  /// Drops the enrollment as soon as a different account is signed in here, by
  /// any route (email, Google, sign-up, invite), so the login screen never
  /// offers to sign in as the previous account.
  void bindAuthState() {
    _authSubscription ??= _authRepository.authStateChanges().listen((user) {
      final current = enrollment;
      if (user != null && current != null && current.firebaseUid != user.uid) {
        unawaited(clearLocalEnrollment());
      }
    });
  }

  /// Creates the device key (shows the biometric prompt) and registers it for
  /// the signed-in account.
  Future<void> enroll({
    required String promptMessage,
    String? displayName,
  }) async {
    final user = _authRepository.currentUser;
    if (user == null) {
      throw const BiometricSignInFailure(BiometricSignInFailureReason.failed);
    }
    final keys = await _signature.createKeys(
      keyAlias: keyAlias,
      keyFormat: KeyFormat.pem,
      promptMessage: promptMessage,
      config: CreateKeysConfig(
        signatureType: SignatureType.ecdsa,
        enforceBiometric: true,
        setInvalidatedByBiometricEnrollment: true,
        useDeviceCredentials: false,
        enableDecryption: false,
      ),
    );
    final publicKey = keys.publicKey;
    if (keys.code != BiometricError.success || publicKey == null) {
      throw BiometricSignInFailure.fromPlugin(keys.code);
    }
    try {
      final credentialId = await _credentials.enroll(
        deviceId: await _store.deviceId(),
        publicKeyPem: publicKey,
        algorithm: BiometricKeyAlgorithm.ecdsaP256Sha256,
      );
      await _store.save(
        BiometricSignInEnrollment(
          credentialId: credentialId,
          firebaseUid: user.uid,
          displayName: displayName,
        ),
      );
    } catch (_) {
      await _signature.deleteKeys(keyAlias: keyAlias);
      rethrow;
    }
  }

  /// Forgets this install's enrollment and deletes the device key. The server
  /// side is revoked by `PATCH /v1/profile` (setting off) or account deletion.
  Future<void> clearLocalEnrollment() async {
    await _store.clear();
    await _signature.deleteKeys(keyAlias: keyAlias);
  }

  /// Signs in the enrolled account. Throws [BiometricSignInFailure] for device
  /// outcomes and [ApiException] for API failures; an enrollment that can never
  /// work again (key invalidated, credential revoked) is cleared first.
  Future<void> signIn({required String promptMessage}) async {
    final current = enrollment;
    if (current == null) {
      throw const BiometricSignInFailure(
        BiometricSignInFailureReason.keyInvalidated,
      );
    }
    try {
      final challenge = await _credentials.createChallenge(
        current.credentialId,
      );
      final signed = await _signature.createSignature(
        payload: challenge.nonce,
        keyAlias: keyAlias,
        signatureFormat: SignatureFormat.base64,
        promptMessage: promptMessage,
        config: CreateSignatureConfig(allowDeviceCredentials: false),
      );
      final signature = signed.signature;
      if (signed.code != BiometricError.success || signature == null) {
        throw BiometricSignInFailure.fromPlugin(signed.code);
      }
      final token = await _credentials.signIn(
        credentialId: current.credentialId,
        challengeId: challenge.id,
        signature: signature,
      );
      await _authRepository.signInWithCustomToken(token);
    } on BiometricSignInFailure catch (e) {
      if (e.reason == BiometricSignInFailureReason.keyInvalidated) {
        await clearLocalEnrollment();
      }
      rethrow;
    } on ApiException catch (e) {
      if (e.code == ApiErrorCode.biometricCredentialInvalid) {
        await clearLocalEnrollment();
      }
      rethrow;
    }
  }

  void dispose() {
    _authSubscription?.cancel();
  }
}

enum BiometricSignInFailureReason {
  /// The user dismissed the prompt (or the system did).
  cancelled,

  /// No usable biometrics on this device.
  unavailable,

  /// The key is gone or invalidated (e.g. a fingerprint was added).
  keyInvalidated,

  /// Too many failed attempts.
  lockedOut,
  failed,
}

class BiometricSignInFailure implements LocalizedFailure {
  const BiometricSignInFailure(this.reason);

  factory BiometricSignInFailure.fromPlugin(BiometricError? code) =>
      BiometricSignInFailure(switch (code) {
        BiometricError.userCanceled ||
        BiometricError.systemCanceled => BiometricSignInFailureReason.cancelled,
        BiometricError.notAvailable ||
        BiometricError.notEnrolled ||
        BiometricError.notSupported ||
        BiometricError.passcodeNotSet =>
          BiometricSignInFailureReason.unavailable,
        BiometricError.keyNotFound || BiometricError.keyInvalidated =>
          BiometricSignInFailureReason.keyInvalidated,
        BiometricError.lockedOut || BiometricError.lockedOutPermanent =>
          BiometricSignInFailureReason.lockedOut,
        _ => BiometricSignInFailureReason.failed,
      });

  final BiometricSignInFailureReason reason;

  @override
  String userMessage(AppLocalizations l10n) => switch (reason) {
    BiometricSignInFailureReason.cancelled =>
      l10n.settingsBiometricVerificationFailed,
    BiometricSignInFailureReason.unavailable =>
      l10n.settingsBiometricUnavailable,
    BiometricSignInFailureReason.keyInvalidated =>
      l10n.biometricSignInKeyInvalidated,
    BiometricSignInFailureReason.lockedOut => l10n.biometricLockedOut,
    BiometricSignInFailureReason.failed => l10n.biometricSignInFailed,
  };
}
