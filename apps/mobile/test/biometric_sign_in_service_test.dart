import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/auth/auth_repository.dart';
import 'package:lanonna/core/auth/biometric_credential_repository.dart';
import 'package:lanonna/core/auth/biometric_sign_in_service.dart';
import 'package:lanonna/core/auth/biometric_sign_in_store.dart';

BiometricSignInService _serviceForTest(BiometricSignInStore store) {
  return BiometricSignInService(
    credentials: BiometricCredentialRepository(
      ApiClient(idTokenProvider: () async => null),
    ),
    store: store,
    authRepository: AuthRepository(),
  );
}

class _FakeUser implements User {
  _FakeUser(this.uid);
  @override
  final String uid;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('onInteractiveSignInCompleted revokes when uid differs', () async {
    final store = BiometricSignInStore.memory({});
    final service = _serviceForTest(store);
    await store.save(
      credentialId: 'cred',
      firebaseUid: 'uid-a',
      accountHint: 'hint',
    );
    await service.onInteractiveSignInCompleted(_FakeUser('uid-b'));
    expect(await service.localEnrollment(), isNull);
  });

  test('onInteractiveSignInCompleted keeps enrollment for same uid', () async {
    final store = BiometricSignInStore.memory({});
    final service = _serviceForTest(store);
    await store.save(
      credentialId: 'cred',
      firebaseUid: 'uid-a',
      accountHint: 'hint',
    );
    await service.onInteractiveSignInCompleted(_FakeUser('uid-a'));
    expect(await service.localEnrollment(), isNotNull);
  });
}
