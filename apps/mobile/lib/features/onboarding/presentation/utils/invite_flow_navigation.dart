import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../home/data/selected_baby_store.dart';
import '../../../invitations/presentation/invite_accept_messages.dart';
import '../../../invitations/data/invitations_repository.dart';
import '../../domain/onboarding_path.dart';
import '../../domain/onboarding_routes.dart';
import '../../domain/onboarding_step.dart';
import '../app_session.dart';
import '../onboarding_coordinator.dart';

Future<void> navigateAfterCompleteProfile(BuildContext context) async {
  final coordinator = context.read<OnboardingCoordinator>();
  final token = coordinator.pendingInviteToken;

  if (coordinator.isInvitePath && token != null && token.isNotEmpty) {
    final result = await context.read<InvitationsRepository>().accept(token);
    if (!context.mounted) return;

    if (result.error == 'email_mismatch') {
      final invitee = Uri.encodeComponent(result.inviteeEmail ?? '');
      final signedIn = Uri.encodeComponent(result.signedInEmail ?? '');
      context.go(
        '${OnboardingRoutes.wrongEmail}?invitee=$invitee&signed_in=$signedIn&invite_token=${Uri.encodeComponent(token)}',
      );
      return;
    }
    if (result.error != null) {
      throw Exception(inviteAcceptUserMessage(result.error!));
    }

    final babyId = result.babyProfileId ?? coordinator.invitedBabyId;
    if (babyId != null) {
      await coordinator.setInvitedBabyId(babyId);
      if (!context.mounted) return;
      await context.read<SelectedBabyStore>().setSelectedBabyId(babyId);
    }

    if (coordinator.onboardingPath == OnboardingPath.coOwner) {
      await coordinator.setStep(OnboardingStep.coOwnerWelcome);
      if (context.mounted) context.go(OnboardingRoutes.coOwnerWelcome);
      return;
    }

    await coordinator.setStep(OnboardingStep.confirmRelationship);
    if (context.mounted) context.go(OnboardingRoutes.confirmRelationship);
    return;
  }

  await coordinator.setStep(OnboardingStep.createBaby);
  if (context.mounted) context.go(OnboardingRoutes.ownerCreateBaby);
}

Future<void> finishInviteOnboardingAndGoHome(BuildContext context) async {
  final coordinator = context.read<OnboardingCoordinator>();
  await coordinator.completeInviteOnboarding();
  if (!context.mounted) return;
  await context.read<AppSession>().refreshFromApi();
  if (context.mounted) context.go('/home');
}

/// Signed-in accept from invite landing screens (H-07): honor API result, not only throws.
Future<void> acceptSignedInInviteAndContinue(
  BuildContext context,
  String token,
) async {
  final coordinator = context.read<OnboardingCoordinator>();
  final result = await context.read<InvitationsRepository>().accept(token);
  if (!context.mounted) return;

  if (result.error == 'email_mismatch') {
    final invitee = Uri.encodeComponent(result.inviteeEmail ?? '');
    final signedIn = Uri.encodeComponent(result.signedInEmail ?? '');
    context.go(
      '${OnboardingRoutes.wrongEmail}?invitee=$invitee&signed_in=$signedIn&invite_token=${Uri.encodeComponent(token)}',
    );
    return;
  }
  if (result.error != null) {
    throw Exception(inviteAcceptUserMessage(result.error!));
  }

  final babyId = result.babyProfileId ?? coordinator.invitedBabyId;
  if (babyId != null) {
    await coordinator.setInvitedBabyId(babyId);
    if (!context.mounted) return;
    await context.read<SelectedBabyStore>().setSelectedBabyId(babyId);
  }

  if (!context.mounted) return;
  await finishInviteOnboardingAndGoHome(context);
}
