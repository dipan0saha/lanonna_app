import 'dart:async';

import 'package:biometric_signature/biometric_signature.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/api/api_exception.dart';
import 'package:lanonna/core/auth/auth_repository.dart';
import 'package:lanonna/core/auth/biometric_credential_repository.dart';
import 'package:lanonna/core/auth/biometric_sign_in_service.dart';
import 'package:lanonna/core/auth/biometric_sign_in_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeUser implements User {
  _FakeUser(this.uid);

  @override
  final String uid;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAuth implements AuthRepository {
  final controller = StreamController<User?>.broadcast();
  User? user;
  String? customToken;

  @override
  Stream<User?> authStateChanges() => controller.stream;

  @override
  User? get currentUser => user;

  @override
  Future<void> signInWithCustomToken(String token) async => customToken = token;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCredentials extends BiometricCredentialRepository {
  _FakeCredentials() : super(ApiClient(idTokenProvider: () async => null));

  Object? challengeError;
  Object? signInError;
  String? signedPayload;

  @override
  Future<String> enroll({
    required String deviceId,
    required String publicKeyPem,
    required BiometricKeyAlgorithm algorithm,
  }) async => 'cred-new';

  @override
  Future<BiometricChallenge> createChallenge(String credentialId) async {
    if (challengeError != null) throw challengeError!;
    return const BiometricChallenge(id: 'ch-1', nonce: 'nonce-1');
  }

  @override
  Future<String> signIn({
    required String credentialId,
    required String challengeId,
    required String signature,
  }) async {
    if (signInError != null) throw signInError!;
    signedPayload = signature;
    return 'custom-token';
  }
}

class _FakePlugin implements BiometricSignature {
  BiometricError signCode = BiometricError.success;
  var deletedKeys = 0;
  String? signedPayload;

  @override
  Future<KeyCreationResult> createKeys({
    String? keyAlias,
    CreateKeysConfig? config,
    KeyFormat keyFormat = KeyFormat.base64,
    String? promptMessage,
  }) async => KeyCreationResult(publicKey: 'PEM', code: BiometricError.success);

  @override
  Future<SignatureResult> createSignature({
    required String payload,
    String? keyAlias,
    CreateSignatureConfig? config,
    SignatureFormat signatureFormat = SignatureFormat.base64,
    KeyFormat keyFormat = KeyFormat.base64,
    String? promptMessage,
  }) async {
    signedPayload = payload;
    return signCode == BiometricError.success
        ? SignatureResult(signature: 'sig-of-$payload', code: signCode)
        : SignatureResult(code: signCode);
  }

  @override
  Future<bool> deleteKeys({String? keyAlias}) async {
    deletedKeys++;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ApiException _apiError(String code, int status) => ApiException(
  'x',
  statusCode: status,
  detail: {'error': code, 'message': 'x'},
);

void main() {
  late BiometricSignInStore store;
  late _FakeAuth auth;
  late _FakeCredentials credentials;
  late _FakePlugin plugin;
  late BiometricSignInService service;

  Future<void> enrolled() => store.save(
    const BiometricSignInEnrollment(
      credentialId: 'cred',
      firebaseUid: 'uid-a',
      displayName: 'Ana',
    ),
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = BiometricSignInStore(await SharedPreferences.getInstance());
    auth = _FakeAuth();
    credentials = _FakeCredentials();
    plugin = _FakePlugin();
    service = BiometricSignInService(
      credentials: credentials,
      store: store,
      authRepository: auth,
      signaturePlugin: plugin,
    );
  });

  test('enroll stores the credential for the signed-in account', () async {
    auth.user = _FakeUser('uid-a');
    await service.enroll(promptMessage: 'p', displayName: 'Ana');
    final e = service.enrollment!;
    expect(e.credentialId, 'cred-new');
    expect(e.firebaseUid, 'uid-a');
    expect(e.displayName, 'Ana');
  });

  test('sign-in signs the server nonce and uses the custom token', () async {
    await enrolled();
    await service.signIn(promptMessage: 'p');
    expect(plugin.signedPayload, 'nonce-1');
    expect(credentials.signedPayload, 'sig-of-nonce-1');
    expect(auth.customToken, 'custom-token');
    expect(service.enrollment, isNotNull);
  });

  test('cancelled prompt keeps the enrollment', () async {
    await enrolled();
    plugin.signCode = BiometricError.userCanceled;
    await expectLater(
      service.signIn(promptMessage: 'p'),
      throwsA(
        isA<BiometricSignInFailure>().having(
          (f) => f.reason,
          'reason',
          BiometricSignInFailureReason.cancelled,
        ),
      ),
    );
    expect(service.enrollment, isNotNull);
    expect(auth.customToken, isNull);
  });

  test('invalidated key clears the enrollment', () async {
    await enrolled();
    plugin.signCode = BiometricError.keyInvalidated;
    await expectLater(
      service.signIn(promptMessage: 'p'),
      throwsA(isA<BiometricSignInFailure>()),
    );
    expect(service.enrollment, isNull);
    expect(plugin.deletedKeys, 1);
  });

  test('revoked credential clears the enrollment', () async {
    await enrolled();
    credentials.challengeError = _apiError('biometric_credential_invalid', 401);
    await expectLater(
      service.signIn(promptMessage: 'p'),
      throwsA(isA<ApiException>()),
    );
    expect(service.enrollment, isNull);
  });

  test('expired challenge keeps the enrollment', () async {
    await enrolled();
    credentials.signInError = _apiError('biometric_challenge_expired', 410);
    await expectLater(
      service.signIn(promptMessage: 'p'),
      throwsA(isA<ApiException>()),
    );
    expect(service.enrollment, isNotNull);
  });

  test(
    'another account signing in clears the enrollment; the same keeps it',
    () async {
      await enrolled();
      service.bindAuthState();
      auth.controller.add(_FakeUser('uid-a'));
      await pumpEventQueue();
      expect(service.enrollment, isNotNull);
      auth.controller.add(null);
      await pumpEventQueue();
      expect(service.enrollment, isNotNull, reason: 'Log out keeps it');
      auth.controller.add(_FakeUser('uid-b'));
      await pumpEventQueue();
      expect(service.enrollment, isNull);
      service.dispose();
    },
  );
}
