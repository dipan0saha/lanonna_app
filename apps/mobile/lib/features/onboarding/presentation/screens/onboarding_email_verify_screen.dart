import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../../../core/auth/auth_email_verification.dart';
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
    final l10n = AppLocalizations.of(context)!;
    final authRepo = context.read<AuthRepository>();
    await authRepo.reloadUser();
    final user = authRepo.currentUser;
    if (user?.emailVerified ?? false) {
      _pollTimer?.cancel();
      await authRepo.refreshSessionClaims();
      if (!mounted) return;
      final coordinator = context.read<OnboardingCoordinator>();
      await coordinator.setStep(OnboardingStep.completeProfile);
      if (mounted) context.go(OnboardingRoutes.completeProfile);
      return;
    }
    if (!silent && mounted) {
      setState(() => _message = l10n.emailVerifyContinuePending);
    }
  }

  Future<void> _resend() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await context.read<AuthRepository>().sendEmailVerification();
      setState(() => _message = l10n.emailVerifySent);
    } on FirebaseAuthException catch (e) {
      setState(() => _message = userFacingAuthError(e));
    } catch (_) {
      setState(() => _message = 'Could not send verification email. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
          OnboardingHeadline(l10n.emailVerifyHeadline, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OnboardingSupportText(
            l10n.emailVerifyBody(email),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          OnboardingSupportText(
            l10n.emailVerifyOAuthNote,
            textAlign: TextAlign.center,
          ),
          if (isLikelyUndeliverable) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'This looks like a dev-only address - it may not receive mail. '
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
              child: Text(
                l10n.emailVerifyResend,
                style: const TextStyle(
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
