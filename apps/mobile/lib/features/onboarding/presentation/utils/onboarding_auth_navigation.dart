import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/auth/auth_repository.dart';
import '../app_session.dart';
import '../onboarding_coordinator.dart';

/// After sign-up or sign-in: the same destination as a signed-in cold start
/// ([AppSession.signedInResumeLocation], #417), never a per-screen guess.
Future<void> navigateAfterOnboardingAuth(
  BuildContext context, {
  required bool usedOAuth,
}) async {
  final coordinator = context.read<OnboardingCoordinator>();
  final session = context.read<AppSession>();
  final auth = context.read<AuthRepository>();

  if (usedOAuth) {
    await coordinator.markOAuthSignIn();
  }

  await session.refreshFromApi();
  if (!context.mounted) return;
  context.go(
    session.signedInResumeLocation(
      emailVerified: auth.currentUser?.emailVerified ?? false,
    ),
  );
}
