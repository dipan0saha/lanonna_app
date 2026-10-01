import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../domain/onboarding_path.dart';
import '../../domain/onboarding_routes.dart';
import '../../domain/onboarding_step.dart';
import '../onboarding_coordinator.dart';
import 'onboarding_back_navigation.dart';

String inviteLandingRouteFor(OnboardingPath path) {
  return switch (path) {
    OnboardingPath.coOwner => OnboardingRoutes.coOwnerInvite,
    OnboardingPath.follower => OnboardingRoutes.followerInvite,
    OnboardingPath.owner => OnboardingRoutes.ownerCarousel,
  };
}

OnboardingStep inviteLandingStepFor(OnboardingPath path) {
  return switch (path) {
    OnboardingPath.coOwner => OnboardingStep.coOwnerInvite,
    OnboardingPath.follower => OnboardingStep.followerInvite,
    OnboardingPath.owner => OnboardingStep.carousel,
  };
}

Future<void> goBackFromInviteAuth(
  BuildContext context, {
  Future<void> Function()? persist,
}) async {
  final coordinator = context.read<OnboardingCoordinator>();
  final path = coordinator.onboardingPath;
  if (!coordinator.isInvitePath) {
    await goOnboardingBack(
      context,
      step: OnboardingStep.carousel,
      route: OnboardingRoutes.ownerCarousel,
      persist: persist,
    );
    return;
  }
  await goOnboardingBack(
    context,
    step: inviteLandingStepFor(path),
    route: inviteLandingRouteFor(path),
    persist: persist,
  );
}

String loginRouteForContext(BuildContext context) {
  final coordinator = context.read<OnboardingCoordinator>();
  final token = coordinator.pendingInviteToken;
  if (coordinator.isInvitePath && token != null && token.isNotEmpty) {
    return OnboardingRoutes.loginWithInvite(
      path: coordinator.onboardingPath.signupQueryValue,
      inviteToken: token,
    );
  }
  return OnboardingRoutes.login;
}

String signupRouteForContext(BuildContext context) {
  final coordinator = context.read<OnboardingCoordinator>();
  final token = coordinator.pendingInviteToken;
  if (coordinator.isInvitePath && token != null && token.isNotEmpty) {
    return OnboardingRoutes.signupWithInvite(
      path: coordinator.onboardingPath.signupQueryValue,
      inviteToken: token,
    );
  }
  return OnboardingRoutes.signup;
}
