import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/network/connectivity_service.dart';
import '../../onboarding/domain/onboarding_routes.dart';
import '../../onboarding/presentation/onboarding_coordinator.dart';
import '../data/invitations_repository.dart';
import '../data/models/invitation_preview.dart';
import 'invite_accept_messages.dart';

class InvitePreviewLoadResult {
  const InvitePreviewLoadResult._({
    this.preview,
    this.fetchErrorMessage,
    this.canRetryFetch = false,
  });

  final InvitationPreview? preview;
  final String? fetchErrorMessage;
  final bool canRetryFetch;

  bool get navigatedAway =>
      preview == null && fetchErrorMessage == null;
}

/// Ensures coordinator has preview data (e.g. after cold start on invite route).
Future<InvitePreviewLoadResult> ensureInvitePreviewLoaded(BuildContext context) async {
  final coordinator = context.read<OnboardingCoordinator>();
  final cached = coordinator.cachedInvitePreview;
  if (cached != null) {
    return InvitePreviewLoadResult._(preview: cached);
  }

  final token = coordinator.pendingInviteToken?.trim();
  if (token == null || token.isEmpty) {
    if (context.mounted) context.go(OnboardingRoutes.ownerCarousel);
    return const InvitePreviewLoadResult._();
  }

  try {
    final preview = await context.read<InvitationsRepository>().fetchPreview(token);
    if (!context.mounted) {
      return const InvitePreviewLoadResult._();
    }
    if (!preview.canContinueInviteFlow) {
      return InvitePreviewLoadResult._(preview: preview);
    }
    await coordinator.bindInviteFromPreview(token, preview);
    return InvitePreviewLoadResult._(preview: preview);
  } catch (e) {
    if (!context.mounted) {
      return const InvitePreviewLoadResult._();
    }
    final offline = !context.read<ConnectivityService>().isOnline;
    return InvitePreviewLoadResult._(
      fetchErrorMessage: invitePreviewFetchUserMessage(e, offline: offline),
      canRetryFetch: invitePreviewFetchCanRetry(e, offline: offline),
    );
  }
}

Future<void> leaveInvitationFlow(BuildContext context) async {
  await context.read<OnboardingCoordinator>().clearPendingInvite();
  if (context.mounted) context.go(OnboardingRoutes.ownerCarousel);
}
