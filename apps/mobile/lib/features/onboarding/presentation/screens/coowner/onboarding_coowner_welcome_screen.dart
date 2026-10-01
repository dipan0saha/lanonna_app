import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../invitations/presentation/widgets/invite_landing_widgets.dart';
import '../../../domain/onboarding_step.dart';
import '../../onboarding_coordinator.dart';
import '../../utils/invite_flow_navigation.dart';
import '../../widgets/onboarding_buttons.dart';
import '../../widgets/onboarding_scaffold.dart';

class OnboardingCoOwnerWelcomeScreen extends StatelessWidget {
  const OnboardingCoOwnerWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final coordinator = context.watch<OnboardingCoordinator>();
    final preview = coordinator.cachedInvitePreview;
    final babyName = preview?.babyName ?? 'Baby';
    final inviter = preview?.inviterDisplayName ?? 'your co-parent';

    return OnboardingScaffold(
      pinBottomCta: false,
      showBack: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CoOwnerWelcomeBanner(babyName: babyName, inviterName: inviter),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: OnboardingPrimaryButton(
              label: 'Go to Home',
              onPressed: () async {
                await coordinator.setStep(OnboardingStep.coOwnerWelcome);
                await finishInviteOnboardingAndGoHome(context);
              },
            ),
          ),
        ],
      ),
    );
  }
}
