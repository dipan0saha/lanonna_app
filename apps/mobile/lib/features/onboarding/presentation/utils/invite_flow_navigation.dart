import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/api/api_error_message.dart';
import '../../../../core/auth/auth_repository.dart';
import '../../../home/data/home_repository.dart';
import '../../../home/data/selected_baby_store.dart';
import '../../../invitations/presentation/invite_accept_messages.dart';
import '../../../invitations/presentation/invite_flow_state.dart';
import '../../../invitations/data/invitations_repository.dart';
import '../../../invitations/data/models/invitation_preview.dart';
import 'package:lanonna/l10n/app_localizations.dart';

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

/// Whether the signed-in user already belongs to the baby on this invite.
Future<bool> viewerBelongsToInviteBaby(
  BuildContext context,
  InvitationPreview preview,
) async {
  final babyId = preview.babyProfileId;
  if (babyId == null || babyId.isEmpty) return false;
  final baby = await context.read<HomeRepository>().babyById(babyId);
  return baby != null;
}

Future<void> navigateAfterCompleteProfile(BuildContext context) async {
  final coordinator = context.read<OnboardingCoordinator>();
  final token = coordinator.pendingInviteToken;

  if (coordinator.isInvitePath && token != null && token.isNotEmpty) {
    // New account: the Accept tapped before sign-up runs here, not on the landing.
    coordinator.takeAcceptRequestedBeforeSignIn();
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
      throw InviteAcceptException(result.error!);
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

/// Selects the joined baby from accept/preview ids and finishes invite onboarding.
Future<void> continueToJoinedBabyHome(
  BuildContext context, {
  String? acceptedBabyId,
}) async {
  final coordinator = context.read<OnboardingCoordinator>();
  final babyId = joinedBabyIdFromAccept(
    acceptedBabyId: acceptedBabyId,
    invitedBabyId: coordinator.invitedBabyId,
    previewBabyId: coordinator.cachedInvitePreview?.babyProfileId,
  );
  if (babyId == null) throw const InviteAcceptException('not_found');
  await coordinator.setInvitedBabyId(babyId);
  if (!context.mounted) return;
  await _selectJoinedBaby(context, babyId);
  if (!context.mounted) return;
  await finishInviteOnboardingAndGoHome(context);
}

/// Preview status `accepted` means this invite was already used.
///
/// Signed-out visitors go to login. Signed-in visitors who already belong to
/// the baby go Home with no accept call. Everyone else sees `already_used`.
Future<void> openAcceptedInvitePreview(BuildContext context) async {
  final auth = context.read<AuthRepository>();
  if (auth.currentUser == null) {
    context.go(OnboardingRoutes.login);
    return;
  }
  final coordinator = context.read<OnboardingCoordinator>();
  final preview = coordinator.cachedInvitePreview;
  if (preview == null || !preview.isAccepted) {
    throw const InviteAcceptException('not_found');
  }
  final isMember = await viewerBelongsToInviteBaby(context, preview);
  if (!context.mounted) return;
  if (isMember) {
    await continueToJoinedBabyHome(context);
    return;
  }
  throw const InviteAcceptException('already_used');
}

/// Primary CTA of both invite landing screens (follower and co-owner): Open
/// for an accepted invite, Accept for a pending one.
///
/// Never a silent no-op: every path navigates, or returns the user message
/// for the landing problem state (`null` when it navigated).
Future<String?> runInviteLandingPrimaryAction(
  BuildContext context,
  InvitationPreview preview,
) async {
  final l10n = AppLocalizations.of(context)!;
  try {
    if (preview.isAccepted) {
      await openAcceptedInvitePreview(context);
    } else {
      await _acceptPendingInvite(context, preview);
    }
    return null;
  } catch (e) {
    return apiErrorMessage(l10n, e);
  }
}

/// Whether the landing should continue an Accept the user tapped before they
/// signed in (#427). Sign-in brings them back here through
/// [AppSession.signedInResumeLocation], then the landing runs
/// [runInviteLandingPrimaryAction] once, exactly as if they had tapped again.
/// Consumes the request.
bool takeInviteAcceptRequestedBeforeSignIn(BuildContext context) {
  final coordinator = context.read<OnboardingCoordinator>();
  if (!coordinator.acceptRequestedBeforeSignIn) return false;
  if (context.read<AuthRepository>().currentUser == null) return false;
  return coordinator.takeAcceptRequestedBeforeSignIn();
}

Future<void> _acceptPendingInvite(
  BuildContext context,
  InvitationPreview preview,
) async {
  final coordinator = context.read<OnboardingCoordinator>();
  final token = coordinator.pendingInviteToken;
  if (token == null || token.isEmpty) {
    throw const InviteAcceptException('not_found');
  }
  if (context.read<AuthRepository>().currentUser == null) {
    coordinator.requestAcceptAfterSignIn(token);
    context.read<InviteFlowState>().setSignupPrefillEmail(preview.inviteeEmail);
    context.go(OnboardingRoutes.signup);
    return;
  }
  await acceptSignedInInviteAndContinue(context, token);
}

/// Signed-in accept from invite landing screens (H-07): honor API result, not only throws.
Future<void> acceptSignedInInviteAndContinue(
  BuildContext context,
  String token,
) async {
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
    throw InviteAcceptException(result.error!);
  }

  await continueToJoinedBabyHome(
    context,
    acceptedBabyId: result.babyProfileId,
  );
}
