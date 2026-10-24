import 'package:go_router/go_router.dart';
import '../../features/onboarding/domain/onboarding_routes.dart';
import '../../features/onboarding/domain/onboarding_step.dart';
import '../../features/onboarding/presentation/onboarding_coordinator.dart';
import '../deep_links/auth_action_app_link.dart';
import '../shell/app_shell_ui.dart';
import '../widgets/app_snackbar.dart';
import 'auth_email_verification.dart';
import 'auth_repository.dart';
import 'email_verify_link_result.dart';

/// Lets each verification link through once.
///
/// On a cold start Android delivers the same link twice: once from
/// `readColdStartAppLinkUri` and again on `watchAppLinkUris`. The second apply
/// fails because the code was just used, which showed "This verification link
/// has expired or was already used" right after a successful verify.
class EmailVerificationLinkGate {
  final Set<String> _seenCodes = <String>{};

  /// True the first time a link's `oobCode` is seen; false for repeats.
  /// Links without a verify code always pass so the handler can report them.
  bool claim(Uri uri) {
    final link = parseEmailVerifyActionLink(uri);
    if (link == null) return true;
    return _seenCodes.add(link.oobCode);
  }
}

/// Applies a verification App Link and drives navigation plus shell snackbars.
Future<void> handleEmailVerificationLink({
  required AuthRepository authRepository,
  required OnboardingCoordinator coordinator,
  required GoRouter router,
  required Uri uri,
}) async {
  final result = await authRepository.applyEmailVerificationLink(uri);

  switch (result.outcome) {
    case EmailVerifyLinkOutcome.success:
    case EmailVerifyLinkOutcome.alreadyVerified:
      await authRepository.refreshSessionClaims();
      await coordinator.setStep(OnboardingStep.completeProfile);
      router.go(OnboardingRoutes.completeProfile);
      if (result.promptTapContinue) {
        AppShellUi.whenReady((messenger, l10n) {
          AppSnackBar.showInfoWithMessenger(
            messenger,
            l10n.messageVerificationCompleteTapContinueProceed,
          );
        });
      }
      return;
    case EmailVerifyLinkOutcome.noSignedInUser:
      router.go(OnboardingRoutes.login);
      AppShellUi.whenReady((messenger, l10n) {
        AppSnackBar.showAlertWithMessenger(
          messenger,
          l10n.appEmailVerifiedSignIn,
        );
      });
      return;
    case EmailVerifyLinkOutcome.invalidOrExpired:
    case EmailVerifyLinkOutcome.wrongMode:
      AppShellUi.whenReady((messenger, l10n) {
        final message =
            result.outcome == EmailVerifyLinkOutcome.invalidOrExpired
            ? userFacingApplyLinkError(l10n, result.firebaseErrorCode)
            : l10n.appEmailVerifyLinkFailed;
        AppSnackBar.showAlertWithMessenger(messenger, message);
      });
      return;
  }
}
