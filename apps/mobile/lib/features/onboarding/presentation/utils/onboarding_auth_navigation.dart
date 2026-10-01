import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../domain/onboarding_routes.dart';
import '../../domain/onboarding_step.dart';
import '../app_session.dart';
import '../onboarding_coordinator.dart';

Future<void> navigateAfterOnboardingAuth(
  BuildContext context, {
  required bool isSignUp,
  required bool usedOAuth,
}) async {
  final coordinator = context.read<OnboardingCoordinator>();
  final session = context.read<AppSession>();

  if (usedOAuth) {
    await coordinator.markOAuthSignIn();
  }

  await session.refreshFromApi();
  if (coordinator.isInvitePath && coordinator.inviteOnboardingCompleted) {
    if (context.mounted) context.go('/home');
    return;
  }
  if (session.ownerOnboardingComplete) {
    if (context.mounted) context.go('/home');
    return;
  }
  final user = FirebaseAuth.instance.currentUser;

  if (user != null && !usedOAuth && isSignUp && !user.emailVerified) {
    await coordinator.setStep(OnboardingStep.emailVerify);
    if (context.mounted) context.go(OnboardingRoutes.emailVerify);
    return;
  }

  await coordinator.setStep(OnboardingStep.completeProfile);
  if (context.mounted) context.go(OnboardingRoutes.completeProfile);
}
