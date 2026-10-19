import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

const _deviceIdKey = 'biometric_device_installation_id';

/// Stable per-install identifier sent with biometric credential enrollment.
class BiometricDeviceId {
  BiometricDeviceId({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _uuid = Uuid();

  Future<String> getOrCreate() async {
    final existing = await _storage.read(key: _deviceIdKey);
    if (existing != null && existing.length >= 8) {
      return existing;
    }
    final id = _uuid.v4();
    await _storage.write(key: _deviceIdKey, value: id);
    return id;
  }
}
