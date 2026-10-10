import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/network/connectivity_service.dart';
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
  VoidCallback? _retryBootstrap;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _problemMessage = null;
      _retryBootstrap = null;
    });
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
    } catch (e) {
      if (!mounted) return;
      final offline = !context.read<ConnectivityService>().isOnline;
      final canRetry = invitePreviewFetchCanRetry(e, offline: offline);
      setState(() {
        _loading = false;
        _problemMessage = invitePreviewFetchUserMessage(e, offline: offline);
        _retryBootstrap = canRetry ? () => _bootstrap() : null;
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
        onRetry: _retryBootstrap,
      );
    }
    return const InviteLandingLoading();
  }
}
