import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../../core/auth/auth_repository.dart';
import '../../../../invitations/data/models/invitation_preview.dart';
import '../../../../invitations/presentation/invite_accept_messages.dart';
import '../../../../invitations/presentation/invite_landing_helpers.dart';
import '../../../../invitations/presentation/widgets/invite_landing_state_views.dart';
import '../../../../invitations/presentation/widgets/invite_landing_widgets.dart';
import '../../../domain/onboarding_path.dart';
import '../../../domain/onboarding_routes.dart';
import '../../../domain/onboarding_step.dart';
import '../../onboarding_coordinator.dart';
import '../../utils/invite_flow_navigation.dart';
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
  VoidCallback? _retryPrepare;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepare());
  }

  Future<void> _prepare() async {
    setState(() {
      _loading = true;
      _problemMessage = null;
      _retryPrepare = null;
    });
    await context.read<OnboardingCoordinator>().setStep(OnboardingStep.coOwnerInvite);
    if (!mounted) return;
    final result = await ensureInvitePreviewLoaded(context);
    if (!mounted) return;
    if (result.fetchErrorMessage != null) {
      setState(() {
        _loading = false;
        _problemMessage = result.fetchErrorMessage;
        _retryPrepare = result.canRetryFetch ? () => _prepare() : null;
      });
      return;
    }
    if (result.navigatedAway) return;
    final preview = result.preview;
    if (preview == null) {
      setState(() => _loading = false);
      return;
    }
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

  Future<void> _accept(InvitationPreview preview) async {
    final coordinator = context.read<OnboardingCoordinator>();
    final token = coordinator.pendingInviteToken;
    if (token == null) return;
    final auth = context.read<AuthRepository>();
    if (auth.currentUser != null) {
      try {
        await acceptSignedInInviteAndContinue(context, token);
      } catch (e) {
        if (mounted) {
          setState(() {
            _problemMessage = e is Exception
                ? e.toString().replaceFirst('Exception: ', '')
                : 'Could not accept this invitation. Try again.';
          });
        }
      }
      return;
    }
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
        onRetry: _retryPrepare,
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
