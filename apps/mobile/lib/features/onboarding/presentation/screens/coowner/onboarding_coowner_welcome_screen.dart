import 'package:flutter/material.dart';
import 'package:lanonna/core/domain/baby_display_label.dart';
import 'package:provider/provider.dart';

import '../../../../invitations/presentation/widgets/invite_landing_widgets.dart';
import '../../../domain/onboarding_step.dart';
import '../../onboarding_coordinator.dart';
import '../../utils/invite_flow_navigation.dart';
import '../../widgets/onboarding_buttons.dart';
import '../../widgets/onboarding_scaffold.dart';
import '../../../../../l10n/app_localizations.dart';

class OnboardingCoOwnerWelcomeScreen extends StatelessWidget {
  const OnboardingCoOwnerWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final coordinator = context.watch<OnboardingCoordinator>();
    final preview = coordinator.cachedInvitePreview;
    final babyName = babyNameLabel(AppLocalizations.of(context)!, preview?.babyName);
    final inviter = preview?.inviterDisplayName ?? AppLocalizations.of(context)!.onboardingYourCoParent;

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
              label: l10n.actionGoHome,
              onPressed: () async {
                await coordinator.setStep(OnboardingStep.coOwnerWelcome);
                if (!context.mounted) return;
                await finishInviteOnboardingAndGoHome(context);
              },
            ),
          ),
        ],
      ),
    );
  }
}
