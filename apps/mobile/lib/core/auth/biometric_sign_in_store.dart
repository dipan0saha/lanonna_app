import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _credentialIdKey = 'biometric_sign_in_credential_id';
const _firebaseUidKey = 'biometric_sign_in_firebase_uid';
const _accountHintKey = 'biometric_sign_in_account_hint';

/// Local enrollment marker (no secrets — credential id + display hint only).
class BiometricSignInStore {
  BiometricSignInStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  @visibleForTesting
  factory BiometricSignInStore.memory(Map<String, String> data) {
    return BiometricSignInStore(storage: _MemorySecureStorage(data));
  }

  final FlutterSecureStorage _storage;

  Future<BiometricSignInEnrollment?> read() async {
    final credentialId = await _storage.read(key: _credentialIdKey);
    if (credentialId == null || credentialId.isEmpty) return null;
    return BiometricSignInEnrollment(
      credentialId: credentialId,
      firebaseUid: await _storage.read(key: _firebaseUidKey),
      accountHint: await _storage.read(key: _accountHintKey),
    );
  }

  Future<void> save({
    required String credentialId,
    required String firebaseUid,
    required String accountHint,
  }) async {
    await _storage.write(key: _credentialIdKey, value: credentialId);
    await _storage.write(key: _firebaseUidKey, value: firebaseUid);
    await _storage.write(key: _accountHintKey, value: accountHint);
  }

  Future<void> clear() async {
    await _storage.delete(key: _credentialIdKey);
    await _storage.delete(key: _firebaseUidKey);
    await _storage.delete(key: _accountHintKey);
  }
}

class BiometricSignInEnrollment {
  const BiometricSignInEnrollment({
    required this.credentialId,
    this.firebaseUid,
    this.accountHint,
  });

  final String credentialId;
  final String? firebaseUid;
  final String? accountHint;
}

class _MemorySecureStorage extends FlutterSecureStorage {
  _MemorySecureStorage(this._data);

  final Map<String, String> _data;

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      _data[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _data.remove(key);
    } else {
      _data[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _data.remove(key);
  }
}
