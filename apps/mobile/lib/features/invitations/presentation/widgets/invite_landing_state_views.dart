import 'package:flutter/material.dart';

import '../../../onboarding/presentation/widgets/onboarding_buttons.dart';
import '../../../onboarding/presentation/widgets/onboarding_scaffold.dart';
import '../../../onboarding/presentation/widgets/onboarding_typography.dart';

class InviteLandingLoading extends StatelessWidget {
  const InviteLandingLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const OnboardingScaffold(
      showBack: false,
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class InviteLandingProblem extends StatelessWidget {
  const InviteLandingProblem({
    super.key,
    required this.message,
    required this.onContinue,
  });

  final String message;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      pinBottomCta: false,
      showBack: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          const OnboardingHeadline('Invitation unavailable'),
          const SizedBox(height: 12),
          OnboardingSupportText(message),
          const SizedBox(height: 28),
          OnboardingPrimaryButton(label: 'Continue', onPressed: onContinue),
        ],
      ),
    );
  }
}
