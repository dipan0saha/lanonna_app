import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../invitations/presentation/widgets/invite_landing_widgets.dart';
import '../../../domain/onboarding_routes.dart';
import '../../../domain/onboarding_step.dart';
import '../../onboarding_coordinator.dart';
import '../../widgets/onboarding_buttons.dart';
import '../../widgets/onboarding_scaffold.dart';
import '../../widgets/onboarding_typography.dart';

class OnboardingConfirmRelationshipScreen extends StatelessWidget {
  const OnboardingConfirmRelationshipScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final coordinator = context.watch<OnboardingCoordinator>();
    final preview = coordinator.cachedInvitePreview;
    final babyName = preview?.babyName ?? 'Baby';
    final inviter = preview?.inviterDisplayName ?? 'The owner';
    final relationship = preview?.relationshipLabel ?? 'Family';

    return OnboardingScaffold(
      pinBottomCta: false,
      showBack: true,
      onBack: () => context.go(OnboardingRoutes.completeProfile),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          OnboardingHeadline(
            'Welcome to $babyName\'s circle',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          OnboardingSupportText(
            '$inviter added you as',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Center(child: RelationshipConfirmChip(label: relationship)),
          const SizedBox(height: 22),
          OnboardingSupportText(
            'This is how you\'ll appear to the rest of the family. '
            '$inviter can update it anytime from their side.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          OnboardingPrimaryButton(
            label: 'Continue',
            onPressed: () async {
              await coordinator.setStep(OnboardingStep.followerCarousel);
              if (context.mounted) context.go(OnboardingRoutes.followerCarousel);
            },
          ),
        ],
      ),
    );
  }
}
