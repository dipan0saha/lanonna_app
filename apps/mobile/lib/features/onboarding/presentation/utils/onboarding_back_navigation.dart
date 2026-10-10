import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../domain/onboarding_step.dart';
import '../onboarding_coordinator.dart';

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
