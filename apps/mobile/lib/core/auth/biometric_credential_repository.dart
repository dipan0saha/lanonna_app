import '../api/api_client.dart';

class BiometricCredentialRepository {
  BiometricCredentialRepository(this._api);

  final ApiClient _api;

  Future<Map<String, dynamic>> enroll({
    required String deviceId,
    required String publicKeyPem,
    required String algorithm,
  }) {
    return _api.postJson(
      '/v1/me/biometric-credentials',
      body: {
        'device_id': deviceId,
        'public_key_pem': publicKeyPem,
        'algorithm': algorithm,
      },
    );
  }

  Future<void> revoke(String credentialId) {
    return _api.deleteJson('/v1/me/biometric-credentials/$credentialId');
  }

  Future<Map<String, dynamic>> createChallenge(String credentialId) {
    return _api.postJsonPublic(
      '/v1/auth/biometric/challenge',
      body: {'credential_id': credentialId},
    );
  }

  Future<Map<String, dynamic>> signIn({
    required String credentialId,
    required String challengeId,
    required String signature,
  }) {
    return _api.postJsonPublic(
      '/v1/auth/biometric/sign-in',
      body: {
        'credential_id': credentialId,
        'challenge_id': challengeId,
        'signature': signature,
      },
    );
  }
}
