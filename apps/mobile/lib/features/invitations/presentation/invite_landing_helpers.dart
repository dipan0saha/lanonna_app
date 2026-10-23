import 'package:flutter/widgets.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_repository.dart';
import '../../../core/network/connectivity_service.dart';
import '../../onboarding/domain/onboarding_routes.dart';
import '../../onboarding/presentation/app_session.dart';
import '../../onboarding/presentation/onboarding_coordinator.dart';
import '../data/invitations_repository.dart';
import '../data/models/invitation_preview.dart';
import 'invite_accept_messages.dart';
import 'invite_flow_state.dart';

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
    return InvitePreviewLoadResult._(
      fetchErrorMessage: inviteAcceptUserMessage(
        AppLocalizations.of(context)!,
        'not_found',
      ),
    );
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
      fetchErrorMessage: invitePreviewFetchUserMessage(
          AppLocalizations.of(context)!,
          e,
          offline: offline,
        ),
      canRetryFetch: invitePreviewFetchCanRetry(e, offline: offline),
    );
  }
}

/// Ends the invite flow: drops the stored token and preview and every
/// in-memory handoff (mismatch, prefills, switch-account resume), then goes to
/// the signed-out entry or the canonical signed-in destination (#409).
Future<void> leaveInvitationFlow(BuildContext context) async {
  context.read<InviteFlowState>().clear();
  await context.read<OnboardingCoordinator>().clearPendingInvite();
  if (!context.mounted) return;
  final auth = context.read<AuthRepository>();
  if (auth.currentUser == null) {
    context.go(OnboardingRoutes.ownerCarousel);
    return;
  }
  final session = context.read<AppSession>();
  final user = auth.currentUser;
  context.go(
    session.signedInResumeLocation(
      emailVerified: user?.emailVerified ?? false,
    ),
  );
}
