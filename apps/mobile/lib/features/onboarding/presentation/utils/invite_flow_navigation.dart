import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../home/data/home_repository.dart';
import '../../../home/data/selected_baby_store.dart';
import '../../../invitations/presentation/invite_accept_messages.dart';
import '../../../invitations/presentation/invite_flow_state.dart';
import '../../../invitations/data/invitations_repository.dart';
import '../../domain/onboarding_path.dart';
import '../../domain/onboarding_routes.dart';
import '../../domain/onboarding_step.dart';
import '../app_session.dart';
import '../onboarding_coordinator.dart';

/// Baby to select after a successful accept.
///
/// Prefer the accept response, then the coordinator's invited id, then the
/// cached invite preview. An empty string is treated as missing.
String? joinedBabyIdFromAccept({
  String? acceptedBabyId,
  String? invitedBabyId,
  String? previewBabyId,
}) {
  for (final id in [acceptedBabyId, invitedBabyId, previewBabyId]) {
    if (id != null && id.isNotEmpty) return id;
  }
  return null;
}

Future<void> _selectJoinedBaby(BuildContext context, String babyId) async {
  await context.read<HomeRepository>().rememberJoinedBaby(
    context.read<SelectedBabyStore>(),
    babyId,
  );
}

Future<void> navigateAfterCompleteProfile(BuildContext context) async {
  final coordinator = context.read<OnboardingCoordinator>();
  final token = coordinator.pendingInviteToken;

  if (coordinator.isInvitePath && token != null && token.isNotEmpty) {
    final result = await context.read<InvitationsRepository>().accept(token);
    if (!context.mounted) return;

    if (result.error == 'email_mismatch') {
      context.read<InviteFlowState>().setEmailMismatch(
        inviteeEmail: result.inviteeEmail ?? '',
        signedInEmail: result.signedInEmail ?? '',
      );
      context.go(OnboardingRoutes.wrongEmail);
      return;
    }
    if (result.error != null) {
      throw Exception(inviteAcceptUserMessage(result.error!));
    }

    final babyId = joinedBabyIdFromAccept(
      acceptedBabyId: result.babyProfileId,
      invitedBabyId: coordinator.invitedBabyId,
      previewBabyId: coordinator.cachedInvitePreview?.babyProfileId,
    );
    if (babyId != null) {
      await coordinator.setInvitedBabyId(babyId);
      if (!context.mounted) return;
      await _selectJoinedBaby(context, babyId);
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
    context.read<InviteFlowState>().setEmailMismatch(
      inviteeEmail: result.inviteeEmail ?? '',
      signedInEmail: result.signedInEmail ?? '',
    );
    context.go(OnboardingRoutes.wrongEmail);
    return;
  }
  if (result.error != null) {
    throw Exception(inviteAcceptUserMessage(result.error!));
  }

  final babyId = joinedBabyIdFromAccept(
    acceptedBabyId: result.babyProfileId,
    invitedBabyId: coordinator.invitedBabyId,
    previewBabyId: coordinator.cachedInvitePreview?.babyProfileId,
  );
  if (babyId != null) {
    await coordinator.setInvitedBabyId(babyId);
    if (!context.mounted) return;
    await _selectJoinedBaby(context, babyId);
  }

  if (!context.mounted) return;
  await finishInviteOnboardingAndGoHome(context);
}
