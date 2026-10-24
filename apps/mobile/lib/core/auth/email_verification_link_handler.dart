import 'package:go_router/go_router.dart';
import '../../features/onboarding/domain/onboarding_routes.dart';
import '../../features/onboarding/domain/onboarding_step.dart';
import '../../features/onboarding/presentation/onboarding_coordinator.dart';
import '../shell/app_shell_ui.dart';
import '../widgets/app_snackbar.dart';
import 'auth_email_verification.dart';
import 'auth_repository.dart';
import 'email_verify_link_result.dart';

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
        final message = result.outcome == EmailVerifyLinkOutcome.invalidOrExpired
            ? userFacingApplyLinkError(l10n, result.firebaseErrorCode)
            : l10n.appEmailVerifyLinkFailed;
        AppSnackBar.showAlertWithMessenger(messenger, message);
      });
      return;
  }
}
