import 'package:firebase_auth/firebase_auth.dart';

import '../../l10n/app_localizations.dart';

/// Which Firebase Auth screen surfaced the error (copy may differ slightly).
enum AuthFlow {
  signIn,
  signUp,
  passwordReset,
}

String authErrorMessage(
  FirebaseAuthException e,
  AppLocalizations l10n, {
  required AuthFlow flow,
}) {
  if (flow == AuthFlow.passwordReset && e.code == 'user-not-found') {
    return l10n.authErrorPasswordResetIfAccountExists;
  }
  switch (e.code) {
    case 'invalid-credential':
    case 'wrong-password':
    case 'user-not-found':
    case 'invalid-login-credentials':
      return l10n.authErrorIncorrectCredentials;
    case 'invalid-email':
      return l10n.authErrorInvalidEmail;
    case 'user-disabled':
      return l10n.authErrorUserDisabled;
    case 'email-already-in-use':
      return l10n.authErrorEmailAlreadyInUse;
    case 'weak-password':
      return l10n.authErrorWeakPassword;
    case 'too-many-requests':
      return l10n.authErrorTooManyRequests;
    case 'network-request-failed':
      return l10n.authErrorNetwork;
    case 'operation-not-allowed':
      return l10n.authErrorOperationNotAllowed;
    case 'account-exists-with-different-credential':
    case 'credential-already-in-use':
      return l10n.authErrorAccountExistsDifferentCredential;
    default:
      return flow == AuthFlow.signUp
          ? l10n.authErrorGenericSignUp
          : l10n.authErrorGenericSignIn;
  }
}
