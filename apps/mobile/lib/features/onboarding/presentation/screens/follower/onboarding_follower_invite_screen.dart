import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../invitations/data/models/invitation_preview.dart';
import '../../../../invitations/presentation/invite_accept_messages.dart';
import '../../../../invitations/presentation/invite_landing_helpers.dart';
import '../../../../invitations/presentation/widgets/invite_landing_state_views.dart';
import '../../../../invitations/presentation/widgets/invite_landing_widgets.dart';
import '../../../domain/onboarding_path.dart';
import '../../../domain/onboarding_routes.dart';
import '../../../domain/onboarding_step.dart';
import '../../onboarding_coordinator.dart';
import '../../widgets/onboarding_buttons.dart';
import '../../widgets/onboarding_scaffold.dart';

class OnboardingFollowerInviteScreen extends StatefulWidget {
  const OnboardingFollowerInviteScreen({super.key});

  @override
  State<OnboardingFollowerInviteScreen> createState() =>
      _OnboardingFollowerInviteScreenState();
}

class _OnboardingFollowerInviteScreenState extends State<OnboardingFollowerInviteScreen> {
  var _loading = true;
  String? _problemMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepare());
  }

  Future<void> _prepare() async {
    await context.read<OnboardingCoordinator>().setStep(OnboardingStep.followerInvite);
    final preview = await ensureInvitePreviewLoaded(context);
    if (!mounted) return;
    if (preview == null) return;
    if (!preview.canContinueInviteFlow) {
      setState(() {
        _loading = false;
        _problemMessage = inviteAcceptUserMessage(
          invitePreviewProblemCode(preview),
        );
      });
      return;
    }
    setState(() => _loading = false);
  }

  void _acceptInvitation(InvitationPreview preview) {
    final token = context.read<OnboardingCoordinator>().pendingInviteToken;
    if (token == null || token.isEmpty) return;
    final email = preview.inviteeEmail;
    context.go(
      OnboardingRoutes.signupWithInvite(
        path: OnboardingPath.follower.signupQueryValue,
        inviteToken: token,
        email: email,
      ),
    );
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

    final preview = context.watch<OnboardingCoordinator>().cachedInvitePreview;
    if (preview == null || !preview.canContinueInviteFlow) {
      return const InviteLandingLoading();
    }

    return OnboardingScaffold(
      pinBottomCta: false,
      showBack: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InviteLandingHeader(preview: preview, isCoOwner: false),
          InviteBabyCard(preview: preview),
          InviteReassureRow(isCoOwner: false),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: OnboardingPrimaryButton(
              label: 'Accept Invitation',
              onPressed: () => _acceptInvitation(preview),
            ),
          ),
          InviteNotForYouLink(onTap: () => leaveInvitationFlow(context)),
        ],
      ),
    );
  }
}
