import 'package:firebase_auth/firebase_auth.dart';

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

String userFacingAuthError(FirebaseAuthException e) {
  switch (e.code) {
    case 'too-many-requests':
      return 'Too many attempts. Wait a few minutes, then try Resend email again.';
    case 'network-request-failed':
      return 'Network error. Check your connection and try again.';
    default:
      return 'Could not send verification email. Please try again.';
  }
}

String userFacingApplyLinkError(FirebaseAuthException e) {
  switch (e.code) {
    case 'expired-action-code':
    case 'invalid-action-code':
      return 'This verification link has expired or was already used. Tap Resend email for a new link.';
    default:
      return 'Could not verify your email from this link. Try Resend email or open the newest message in your inbox.';
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
      message: userFacingApplyLinkError(e),
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
      message: userFacingApplyLinkError(e),
    );
  }

  final userAfter = auth.currentUser;
  if (userAfter == null) {
    return const EmailVerifyLinkResult(
      EmailVerifyLinkOutcome.noSignedInUser,
      message: 'Email verified. Sign in with the same address to continue.',
    );
  }

  await userAfter.reload();
  final refreshed = auth.currentUser;
  if (refreshed?.emailVerified ?? false) {
    return const EmailVerifyLinkResult(EmailVerifyLinkOutcome.success);
  }

  return const EmailVerifyLinkResult(
    EmailVerifyLinkOutcome.success,
    message: 'Verification complete. Tap Continue to proceed.',
  );
}
