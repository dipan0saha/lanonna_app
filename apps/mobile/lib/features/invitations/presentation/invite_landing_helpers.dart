import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../onboarding/domain/onboarding_routes.dart';
import '../../onboarding/presentation/onboarding_coordinator.dart';
import '../data/invitations_repository.dart';
import '../data/models/invitation_preview.dart';

/// Ensures coordinator has preview data (e.g. after cold start on invite route).
Future<InvitationPreview?> ensureInvitePreviewLoaded(BuildContext context) async {
  final coordinator = context.read<OnboardingCoordinator>();
  final cached = coordinator.cachedInvitePreview;
  if (cached != null) return cached;

  final token = coordinator.pendingInviteToken?.trim();
  if (token == null || token.isEmpty) {
    if (context.mounted) context.go(OnboardingRoutes.ownerCarousel);
    return null;
  }

  try {
    final preview = await context.read<InvitationsRepository>().fetchPreview(token);
    if (!context.mounted) return null;
    if (!preview.isPending) return preview;
    await coordinator.bindInviteFromPreview(token, preview);
    return preview;
  } catch (_) {
    if (context.mounted) context.go(OnboardingRoutes.ownerCarousel);
    return null;
  }
}

Future<void> leaveInvitationFlow(BuildContext context) async {
  await context.read<OnboardingCoordinator>().clearPendingInvite();
  if (context.mounted) context.go(OnboardingRoutes.ownerCarousel);
}
