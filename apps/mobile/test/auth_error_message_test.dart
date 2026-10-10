import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/auth/auth_error_message.dart';
import 'package:lanonna/l10n/app_localizations_en.dart';

void main() {
  final l10n = AppLocalizationsEn();

  FirebaseAuthException ex(String code, {String? message}) {
    return FirebaseAuthException(code: code, message: message);
  }

  test('maps invalid credential to friendly sign-in copy', () {
    final msg = authErrorMessage(
      ex('invalid-credential', message: 'The supplied auth credential is incorrect'),
      l10n,
      flow: AuthFlow.signIn,
    );
    expect(msg, l10n.authErrorIncorrectCredentials);
    expect(msg, isNot(contains('malformed')));
  });

  test('never surfaces raw Firebase message for unknown codes', () {
    final msg = authErrorMessage(
      ex('some-new-code', message: 'Raw firebase text'),
      l10n,
      flow: AuthFlow.signIn,
    );
    expect(msg, l10n.authErrorGenericSignIn);
    expect(msg, isNot(contains('Raw firebase')));
  });

  test('maps network and rate limit codes', () {
    expect(
      authErrorMessage(ex('network-request-failed'), l10n, flow: AuthFlow.signIn),
      l10n.authErrorNetwork,
    );
    expect(
      authErrorMessage(ex('too-many-requests'), l10n, flow: AuthFlow.signUp),
      l10n.authErrorTooManyRequests,
    );
  });

  test('password reset hides missing account', () {
    expect(
      authErrorMessage(ex('user-not-found'), l10n, flow: AuthFlow.passwordReset),
      l10n.authErrorPasswordResetIfAccountExists,
    );
  });
}
