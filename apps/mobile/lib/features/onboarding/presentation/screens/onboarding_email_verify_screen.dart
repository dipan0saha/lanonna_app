import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/auth/auth_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/onboarding_routes.dart';
import '../../domain/onboarding_step.dart';
import '../onboarding_coordinator.dart';
import '../widgets/onboarding_buttons.dart';
import '../widgets/onboarding_prototype_widgets.dart';
import '../widgets/onboarding_scaffold.dart';
import '../utils/onboarding_back_navigation.dart';
import '../widgets/onboarding_typography.dart';

class OnboardingEmailVerifyScreen extends StatefulWidget {
  const OnboardingEmailVerifyScreen({super.key});

  @override
  State<OnboardingEmailVerifyScreen> createState() => _OnboardingEmailVerifyScreenState();
}

class _OnboardingEmailVerifyScreenState extends State<OnboardingEmailVerifyScreen> {
  Timer? _pollTimer;
  String? _message;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _checkVerified(silent: true));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkVerified({bool silent = false}) async {
    if (!mounted) return;
    final authRepo = context.read<AuthRepository>();
    await authRepo.reloadUser();
    final user = authRepo.currentUser;
    if (user?.emailVerified ?? false) {
      _pollTimer?.cancel();
      await authRepo.refreshSessionClaims();
      final coordinator = context.read<OnboardingCoordinator>();
      await coordinator.setStep(OnboardingStep.completeProfile);
      if (mounted) context.go(OnboardingRoutes.completeProfile);
      return;
    }
    if (!silent && mounted) {
      setState(() => _message = 'Not verified yet — open the link in your inbox, then tap Continue.');
    }
  }

  Future<void> _resend() async {
    try {
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      setState(() => _message = 'Verification email sent.');
    } catch (e) {
      setState(() => _message = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? 'your email';
    final isLikelyUndeliverable =
        email.endsWith('@test.com') || email.contains('.smoke@');
    return OnboardingScaffold(
      pinBottomCta: false,
      showBack: true,
      onBack: () => goOnboardingBack(
        context,
        step: OnboardingStep.signup,
        route: OnboardingRoutes.signup,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 30),
          Center(
            child: OnboardingIconBlob(
              size: 96,
              backgroundColor: AppColors.sageTint,
              child: Icon(Icons.mail_outline, size: 38, color: AppColors.primaryDark),
            ),
          ),
          const SizedBox(height: 22),
          const OnboardingHeadline('Check your email', textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OnboardingSupportText(
            'We sent a verification link to $email. Click it to activate your account. '
            'This screen only applies to email/password sign-ups; Google accounts skip straight past it.',
            textAlign: TextAlign.center,
          ),
          if (isLikelyUndeliverable) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'This looks like a dev-only address — it may not receive mail. '
                  'Mark the account verified in Firebase Console, or use a real email.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          ],
          const SizedBox(height: 28),
          OnboardingPrimaryButton(
            label: 'Continue',
            onPressed: () => _checkVerified(),
          ),
          const SizedBox(height: 12),
          Center(
            child: GestureDetector(
              onTap: _resend,
              child: const Text(
                'Resend email',
                style: TextStyle(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          if (_message != null) ...[
            const SizedBox(height: 16),
            Text(_message!, textAlign: TextAlign.center),
          ],
          const SizedBox(height: 26),
        ],
      ),
    );
  }
}
