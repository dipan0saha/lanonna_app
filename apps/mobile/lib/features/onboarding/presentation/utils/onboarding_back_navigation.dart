import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/auth/auth_repository.dart';
import '../../domain/onboarding_step.dart';
import '../app_session.dart';
import '../onboarding_coordinator.dart';

/// Whether a setup screen may offer Back to [route]. Signed in, only a step
/// the routing table ([AppSession.allowsSignedInLocation]) keeps the user on;
/// otherwise the screen hides Back and Sign out is the way off (#418).
/// Rebuilds when the session status changes.
bool onboardingBackAllowed(BuildContext context, String route) {
  final session = context.watch<AppSession>();
  final user = Provider.of<AuthRepository?>(context, listen: false)?.currentUser;
  if (user == null) return true;
  return session.allowsSignedInLocation(
    route,
    emailVerified: user.emailVerified,
  );
}

/// Updates persisted step then navigates — keeps [AppSession.redirectFor] from blocking back.
Future<void> goOnboardingBack(
  BuildContext context, {
  required OnboardingStep step,
  required String route,
  Future<void> Function()? persist,
}) async {
  if (persist != null) await persist();
  if (!context.mounted) return;
  await context.read<OnboardingCoordinator>().setStep(step);
  if (context.mounted) context.go(route);
}
