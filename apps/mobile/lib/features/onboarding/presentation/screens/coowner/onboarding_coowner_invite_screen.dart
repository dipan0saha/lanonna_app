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

class OnboardingCoOwnerInviteScreen extends StatefulWidget {
  const OnboardingCoOwnerInviteScreen({super.key});

  @override
  State<OnboardingCoOwnerInviteScreen> createState() =>
      _OnboardingCoOwnerInviteScreenState();
}

class _OnboardingCoOwnerInviteScreenState extends State<OnboardingCoOwnerInviteScreen> {
  var _loading = true;
  String? _problemMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepare());
  }

  Future<void> _prepare() async {
    await context.read<OnboardingCoordinator>().setStep(OnboardingStep.coOwnerInvite);
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

  void _accept(InvitationPreview preview) {
    final token = context.read<OnboardingCoordinator>().pendingInviteToken;
    if (token == null) return;
    context.go(
      OnboardingRoutes.signupWithInvite(
        path: OnboardingPath.coOwner.signupQueryValue,
        inviteToken: token,
        email: preview.inviteeEmail,
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
          InviteLandingHeader(preview: preview, isCoOwner: true),
          InviteBabyCard(preview: preview),
          InviteReassureRow(isCoOwner: true),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: OnboardingPrimaryButton(
              label: 'Accept & Join as Owner',
              onPressed: () => _accept(preview),
            ),
          ),
          InviteNotForYouLink(onTap: () => leaveInvitationFlow(context)),
        ],
      ),
    );
  }
}
