import 'package:flutter/material.dart';
import 'package:lanonna/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';

/// Biometric sign-in CTA on the login screen (when device is enrolled).
class BiometricSignInButton extends StatelessWidget {
  const BiometricSignInButton({
    super.key,
    required this.onPressed,
    required this.isLoading,
    this.accountHint,
  });

  final VoidCallback? onPressed;
  final bool isLoading;
  final String? accountHint;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hint = accountHint != null && accountHint!.isNotEmpty
        ? l10n.authSignInWithBiometricsHint(accountHint!)
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
          key: const Key('biometric_sign_in_button'),
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.border),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.fingerprint, size: 22),
                    const SizedBox(width: 8),
                    Text(l10n.authSignInWithBiometrics),
                  ],
                ),
        ),
        ),
        if (hint != null) ...[
          const SizedBox(height: 6),
          Text(
            hint,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ],
    );
  }
}
