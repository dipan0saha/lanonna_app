import 'package:flutter/material.dart';

import '../../../../core/widgets/app_semantics.dart';

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

class OnboardingOutlineButton extends StatelessWidget {
  const OnboardingOutlineButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.leading,
    this.isLoading = false,
    this.buttonKey,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? leading;
  final bool isLoading;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        key: buttonKey,
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
                  if (leading != null) ...[leading!, const SizedBox(width: 10)],
                  Text(label),
                ],
              ),
      ),
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
    return OnboardingOutlineButton(
      label: 'Continue with Google',
      onPressed: onPressed,
      isLoading: isLoading,
      leading: const Text(
        'G',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Color(0xFF4285F4),
        ),
      ),
    );
  }
}
