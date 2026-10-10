import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../onboarding/domain/onboarding_routes.dart';
import '../../onboarding/presentation/onboarding_coordinator.dart';
import '../data/invitations_repository.dart';
import 'invite_accept_messages.dart';
import 'invite_landing_helpers.dart';
import 'widgets/invite_landing_state_views.dart';

/// Loads invite preview and routes to follower/co-owner landing screens.
class InviteAcceptBootstrapScreen extends StatefulWidget {
  const InviteAcceptBootstrapScreen({super.key, required this.token});

  final String token;

  @override
  State<InviteAcceptBootstrapScreen> createState() =>
      _InviteAcceptBootstrapScreenState();
}

class _InviteAcceptBootstrapScreenState extends State<InviteAcceptBootstrapScreen> {
  var _loading = true;
  String? _problemMessage;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final token = widget.token.trim();
    if (token.isEmpty) {
      if (mounted) context.go(OnboardingRoutes.ownerCarousel);
      return;
    }
    try {
      final preview = await context.read<InvitationsRepository>().fetchPreview(token);
      if (!mounted) return;
      if (!preview.canContinueInviteFlow) {
        setState(() {
          _loading = false;
          _problemMessage = inviteAcceptUserMessage(
            invitePreviewProblemCode(preview),
          );
        });
        return;
      }
      await context.read<OnboardingCoordinator>().bindInviteFromPreview(token, preview);
      if (!mounted) return;
      final route = preview.isCoOwnerInvite
          ? OnboardingRoutes.coOwnerInvite
          : OnboardingRoutes.followerInvite;
      context.go(route);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _problemMessage = inviteAcceptUserMessage('not_found');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const InviteLandingLoading();
    if (_problemMessage != null) {
      return InviteLandingProblem(
        message: _problemMessage!,
        onContinue: () => leaveInvitationFlow(context),
      );
    }
    return const InviteLandingLoading();
  }
}
