import 'package:flutter/material.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../../../invitations/data/models/invitation_preview.dart';
import '../../../../invitations/presentation/invite_accept_messages.dart';
import '../../../../invitations/presentation/invite_landing_helpers.dart';
import '../../../../invitations/presentation/widgets/invite_landing_state_views.dart';
import '../../../../invitations/presentation/widgets/invite_landing_widgets.dart';
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

class _OnboardingCoOwnerInviteScreenState
    extends State<OnboardingCoOwnerInviteScreen> {
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
    await context.read<OnboardingCoordinator>().setStep(
      OnboardingStep.coOwnerInvite,
    );
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
            AppLocalizations.of(context)!,
            invitePreviewProblemCode(preview),
        );
      });
      return;
    }
    if (await takeInviteAcceptRequestedBeforeSignIn(context)) {
      await _onPrimary(preview);
      if (mounted) setState(() => _loading = false);
      return;
    }
    setState(() => _loading = false);
  }

  Future<void> _onPrimary(InvitationPreview preview) async {
    final message = await runInviteLandingPrimaryAction(context, preview);
    if (message != null && mounted) {
      setState(() => _problemMessage = message);
    }
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
      return InviteLandingProblem(
        message: AppLocalizations.of(context)!.inviteErrorNotFound,
        onContinue: () => leaveInvitationFlow(context),
      );
    }

    return OnboardingScaffold(
      pinBottomCta: false,
      showBack: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InviteLandingHeader(preview: preview, isCoOwner: true),
          InviteBabyCard(preview: preview),
          if (!preview.isAccepted) const InviteReassureRow(isCoOwner: true),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: OnboardingPrimaryButton(
              label: preview.isAccepted ? AppLocalizations.of(context)!.onboardingOpen : AppLocalizations.of(context)!.onboardingAcceptJoinAsOwner,
              onPressed: () => _onPrimary(preview),
            ),
          ),
          InviteNotForYouLink(onTap: () => leaveInvitationFlow(context)),
        ],
      ),
    );
  }
}
