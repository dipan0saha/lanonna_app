import '../api/api_client.dart';

/// Key algorithm the app enrolls (`BiometricKeyAlgorithm` on the API).
enum BiometricKeyAlgorithm {
  ecdsaP256Sha256('ecdsa_p256_sha256');

  const BiometricKeyAlgorithm(this.apiValue);

  final String apiValue;
}

/// Biometric sign-in API: enrollment (signed in) and the App Check-gated
/// challenge / sign-in pair used after Log out.
class BiometricCredentialRepository {
  BiometricCredentialRepository(this._api);

  final ApiClient _api;

  /// Registers this install's public key; returns the credential id.
  Future<String> enroll({
    required String deviceId,
    required String publicKeyPem,
    required BiometricKeyAlgorithm algorithm,
  }) async {
    final json = await _api.postJson(
      '/v1/me/biometric-credentials',
      body: {
        'device_id': deviceId,
        'public_key_pem': publicKeyPem,
        'algorithm': algorithm.apiValue,
      },
    );
    return json['id'] as String;
  }

  Future<BiometricChallenge> createChallenge(String credentialId) async {
    final json = await _api.postJsonPublic(
      '/v1/auth/biometric/challenge',
      body: {'credential_id': credentialId},
    );
    return BiometricChallenge(
      id: json['challenge_id'] as String,
      nonce: json['nonce'] as String,
    );
  }

  /// Exchanges a signed challenge for a Firebase custom token.
  Future<String> signIn({
    required String credentialId,
    required String challengeId,
    required String signature,
  }) async {
    final json = await _api.postJsonPublic(
      '/v1/auth/biometric/sign-in',
      body: {
        'credential_id': credentialId,
        'challenge_id': challengeId,
        'signature': signature,
      },
    );
    return json['custom_token'] as String;
  }
}

class BiometricChallenge {
  const BiometricChallenge({required this.id, required this.nonce});

  final String id;
  final String nonce;
}
