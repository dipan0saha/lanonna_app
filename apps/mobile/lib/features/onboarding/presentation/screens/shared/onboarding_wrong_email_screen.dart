import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../../core/auth/auth_repository.dart';
import '../../../domain/onboarding_routes.dart';
import '../../onboarding_coordinator.dart';
import '../../widgets/onboarding_buttons.dart';
import '../../widgets/onboarding_scaffold.dart';
import '../../widgets/onboarding_typography.dart';

class OnboardingWrongEmailScreen extends StatelessWidget {
  const OnboardingWrongEmailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final params = GoRouterState.of(context).uri.queryParameters;
    final invitee = Uri.decodeComponent(params['invitee'] ?? 'the invited email');
    final signedIn = Uri.decodeComponent(
      params['signed_in'] ?? FirebaseAuth.instance.currentUser?.email ?? '',
    );
    final token = params['invite_token'] ?? context.read<OnboardingCoordinator>().pendingInviteToken;
    final path = context.read<OnboardingCoordinator>().onboardingPath;

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
              await context.read<AuthRepository>().signOut();
              if (token == null || token.isEmpty) {
                if (context.mounted) context.go(OnboardingRoutes.ownerCarousel);
                return;
              }
              final pathValue = path.signupQueryValue;
              if (context.mounted) {
                context.go(
                  OnboardingRoutes.loginWithInvite(
                    path: pathValue,
                    inviteToken: token,
                    email: invitee,
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () async {
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
