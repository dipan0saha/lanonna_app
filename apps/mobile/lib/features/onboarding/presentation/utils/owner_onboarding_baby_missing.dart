import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../domain/onboarding_routes.dart';
import '../app_session.dart';

/// When [OwnerOnboardingBabyResolver] cannot resolve a baby id during onboarding.
void handleOwnerOnboardingBabyMissing(
  BuildContext context,
  AppSession session, {
  required void Function(String message) setError,
}) {
  if (session.status?.needsOwnerOnboarding == true ||
      session.status?.hasOwnerBaby == true) {
    setError(
      "We couldn't load your baby profile. Check your connection and try again.",
    );
    return;
  }
  context.go(OnboardingRoutes.ownerCreateBaby);
}
