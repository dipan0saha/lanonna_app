import 'package:firebase_auth/firebase_auth.dart';
import 'package:lanonna/l10n/app_localizations.dart';

import 'auth_link_config.dart';
import 'email_verify_link_result.dart';
import '../deep_links/auth_action_app_link.dart';

ActionCodeSettings buildEmailVerificationActionCodeSettings() {
  return ActionCodeSettings(
    url: AuthLinkConfig.emailVerificationContinueUrl.toString(),
    handleCodeInApp: true,
    androidPackageName: AuthLinkConfig.androidPackageName,
    androidInstallApp: true,
    androidMinimumVersion: '1',
    iOSBundleId: AuthLinkConfig.iOSBundleId,
  );
}

/// User copy for a failed "resend verification email" call.
String userFacingAuthError(AppLocalizations l10n, FirebaseAuthException e) {
  switch (e.code) {
    case 'too-many-requests':
      return l10n.authErrorTooManyAttempts;
    case 'network-request-failed':
      return l10n.authErrorNetwork;
    default:
      return l10n.onboardingCouldNotSendVerificationEmail;
  }
}

/// User copy for a verification link Firebase rejected ([firebaseErrorCode]).
String userFacingApplyLinkError(
  AppLocalizations l10n,
  String? firebaseErrorCode,
) {
  switch (firebaseErrorCode) {
    case 'expired-action-code':
    case 'invalid-action-code':
      return l10n.authErrorVerifyLinkExpired;
    default:
      return l10n.authErrorVerifyLinkFailed;
  }
}

Future<void> sendEmailVerificationToUser(User? user) async {
  await user?.sendEmailVerification(buildEmailVerificationActionCodeSettings());
}

Future<EmailVerifyLinkResult> applyEmailVerificationLinkFromUri(
  FirebaseAuth auth,
  Uri uri,
) async {
  final parsed = parseEmailVerifyActionLink(uri);
  if (parsed == null) {
    return const EmailVerifyLinkResult(EmailVerifyLinkOutcome.wrongMode);
  }

  try {
    await auth.checkActionCode(parsed.oobCode);
  } on FirebaseAuthException catch (e) {
    return EmailVerifyLinkResult(
      EmailVerifyLinkOutcome.invalidOrExpired,
      firebaseErrorCode: e.code,
    );
  }

  final userBefore = auth.currentUser;
  if (userBefore != null && userBefore.emailVerified) {
    return const EmailVerifyLinkResult(EmailVerifyLinkOutcome.alreadyVerified);
  }

  try {
    await auth.applyActionCode(parsed.oobCode);
  } on FirebaseAuthException catch (e) {
    return EmailVerifyLinkResult(
      EmailVerifyLinkOutcome.invalidOrExpired,
      firebaseErrorCode: e.code,
    );
  }

  final userAfter = auth.currentUser;
  if (userAfter == null) {
    return const EmailVerifyLinkResult(EmailVerifyLinkOutcome.noSignedInUser);
  }

  await userAfter.reload();
  final refreshed = auth.currentUser;
  if (refreshed?.emailVerified ?? false) {
    return const EmailVerifyLinkResult(EmailVerifyLinkOutcome.success);
  }

  return const EmailVerifyLinkResult(
    EmailVerifyLinkOutcome.success,
    promptTapContinue: true,
  );
}
