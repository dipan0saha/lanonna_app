import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

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
  final user = FirebaseAuth.instance.currentUser;
  final emailVerified =
      coordinator.skipEmailVerify || (user?.emailVerified ?? false);
  if (!context.mounted) return;
  context.go(session.signedInResumeLocation(emailVerified: emailVerified));
}
