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
import '../../../../../l10n/app_localizations.dart';

class OnboardingConfirmRelationshipScreen extends StatelessWidget {
  const OnboardingConfirmRelationshipScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final coordinator = context.watch<OnboardingCoordinator>();
    final preview = coordinator.cachedInvitePreview;
    final babyName = preview?.babyName ?? AppLocalizations.of(context)!.babyNameDefault;
    final inviter = preview?.inviterDisplayName ?? AppLocalizations.of(context)!.onboardingTheOwner;
    final relationship = preview?.relationshipLabel ?? AppLocalizations.of(context)!.announcementFamily;

    return OnboardingScaffold(
      pinBottomCta: false,
      showBack: true,
      onBack: () => context.go(OnboardingRoutes.completeProfile),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          OnboardingHeadline(
            AppLocalizations.of(context)!.onboardingWelcomeToSCircle(babyName),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          OnboardingSupportText(
            AppLocalizations.of(context)!.onboardingAddedYouAs(inviter),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Center(child: RelationshipConfirmChip(label: relationship)),
          const SizedBox(height: 22),
          OnboardingSupportText(
            AppLocalizations.of(context)!.onboardingThisIsHowYoullAppear(inviter),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          OnboardingPrimaryButton(
            label: l10n.deleteAccountReauthPasswordAction,
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
