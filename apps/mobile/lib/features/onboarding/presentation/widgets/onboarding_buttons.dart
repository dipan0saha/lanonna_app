import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_semantics.dart';
import '../../../../core/widgets/google_logo_mark.dart';
import '../../../../l10n/app_localizations.dart';

class OnboardingPrimaryButton extends StatelessWidget {
  const OnboardingPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.buttonKey,
    this.semanticsId,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Key? buttonKey;
  final String? semanticsId;

  @override
  Widget build(BuildContext context) {
    final button = ElevatedButton(
      key: buttonKey,
      onPressed: isLoading ? null : onPressed,
      child: isLoading
          ? SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            )
          : Text(label),
    );
    return SizedBox(
      width: double.infinity,
      child: semanticsId == null
          ? button
          : AppSemantics.button(semanticsId!, button, label: label),
    );
  }
}

class OnboardingGoogleButton extends StatelessWidget {
  const OnboardingGoogleButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
  });

  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
      color: AppColors.textPrimary,
      fontWeight: FontWeight.w600,
    );

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const GoogleLogoMark(size: 20),
                  const SizedBox(width: 10),
                  Text(AppLocalizations.of(context)!.onboardingContinueWithGoogle, style: labelStyle),
                ],
              ),
      ),
    );
  }
}

/// Biometric sign-in on the login screen, styled like [OnboardingGoogleButton].
class OnboardingBiometricButton extends StatelessWidget {
  const OnboardingBiometricButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
    this.displayName,
  });

  final VoidCallback? onPressed;
  final bool isLoading;

  /// Enrolled account's first name ("Continue as …"); hidden when unknown.
  final String? displayName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final name = displayName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: double.infinity,
          child: AppSemantics.button(
            'auth_sign_in_biometric',
            OutlinedButton(
            key: const Key('biometric_sign_in_button'),
            onPressed: isLoading ? null : onPressed,
            child: isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.fingerprint, size: 22, color: AppColors.textPrimary),
                      const SizedBox(width: 10),
                      Text(
                        l10n.authSignInWithBiometrics,
                        style: textTheme.labelLarge?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          ),
            label: l10n.authSignInWithBiometrics,
          ),
        ),
        if (name != null && name.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            l10n.authSignInWithBiometricsAs(name),
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(color: AppColors.muted),
          ),
        ],
      ],
    );
  }
}
