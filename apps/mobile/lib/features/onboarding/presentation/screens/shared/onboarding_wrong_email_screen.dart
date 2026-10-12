import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../../core/auth/auth_repository.dart';
import '../../../../../core/auth/session_cleanup.dart';
import '../../../../invitations/presentation/invite_flow_state.dart';
import '../../../domain/onboarding_routes.dart';
import '../../onboarding_coordinator.dart';
import '../../widgets/onboarding_buttons.dart';
import '../../widgets/onboarding_scaffold.dart';
import '../../widgets/onboarding_typography.dart';

class OnboardingWrongEmailScreen extends StatefulWidget {
  const OnboardingWrongEmailScreen({super.key});

  @override
  State<OnboardingWrongEmailScreen> createState() =>
      _OnboardingWrongEmailScreenState();
}

class _OnboardingWrongEmailScreenState extends State<OnboardingWrongEmailScreen> {
  var _redirected = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_redirected) return;
    final mismatch = context.read<InviteFlowState>().emailMismatch;
    if (mismatch == null) {
      _redirected = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(OnboardingRoutes.ownerCarousel);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mismatch = context.watch<InviteFlowState>().emailMismatch;
    if (mismatch == null) {
      return const SizedBox.shrink();
    }

    final invitee = mismatch.inviteeEmail.isNotEmpty
        ? mismatch.inviteeEmail
        : 'the invited email';
    final signedIn = mismatch.signedInEmail;
    final coordinator = context.read<OnboardingCoordinator>();
    final token = coordinator.pendingInviteToken;

    return OnboardingScaffold(
      pinBottomCta: false,
      showBack: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          const OnboardingHeadline('Wrong account'),
          const SizedBox(height: 8),
          OnboardingSupportText(
            'This invitation was sent to $invitee, but you\'re signed in as $signedIn. '
            'Sign in with the invited email to continue.',
          ),
          const SizedBox(height: 28),
          OnboardingPrimaryButton(
            label: 'Switch account',
            onPressed: () async {
              final flow = context.read<InviteFlowState>();
              flow.setLoginPrefillEmail(mismatch.inviteeEmail);
              if (token != null && token.isNotEmpty) {
                flow.setInviteResume(token: token, path: coordinator.onboardingPath);
              }
              await context.read<SessionCleanup>().clearLocalUserData();
              if (!context.mounted) return;
              await context.read<AuthRepository>().signOut();
              if (token == null || token.isEmpty) {
                if (context.mounted) context.go(OnboardingRoutes.ownerCarousel);
                return;
              }
              if (context.mounted) context.go(OnboardingRoutes.login);
            },
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () async {
                context.read<InviteFlowState>().clearEmailMismatch();
                await context.read<OnboardingCoordinator>().clearPendingInvite();
                if (context.mounted) context.go(OnboardingRoutes.ownerCarousel);
              },
              child: const Text('Leave this invitation'),
            ),
          ),
        ],
      ),
    );
  }
}
