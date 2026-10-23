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
import '../app_session.dart';
import '../onboarding_coordinator.dart';
import '../widgets/onboarding_sign_out_button.dart';
import '../widgets/onboarding_buttons.dart';
import '../widgets/onboarding_prototype_widgets.dart';
import '../widgets/onboarding_scaffold.dart';
import '../utils/onboarding_back_navigation.dart';
import '../widgets/onboarding_typography.dart';

class OnboardingEmailVerifyScreen extends StatefulWidget {
  const OnboardingEmailVerifyScreen({super.key});

  @override
  State<OnboardingEmailVerifyScreen> createState() =>
      _OnboardingEmailVerifyScreenState();
}

class _OnboardingEmailVerifyScreenState
    extends State<OnboardingEmailVerifyScreen> {
  Timer? _pollTimer;
  String? _message;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkVerified(silent: true));
    _pollTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _checkVerified(silent: true),
    );
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
      final session = context.read<AppSession>();
      await session.refreshFromApi();
      if (!mounted) return;
      context.go(session.signedInResumeLocation(emailVerified: true));
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
      setState(() => _message = userFacingAuthError(l10n, e));
    } catch (_) {
      setState(
        () => _message = AppLocalizations.of(context)!.onboardingCouldNotSendVerificationEmail,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final email = FirebaseAuth.instance.currentUser?.email ?? AppLocalizations.of(context)!.onboardingYourEmail;
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
              child: Icon(
                Icons.mail_outline,
                size: 38,
                color: AppColors.primaryDark,
              ),
            ),
          ),
          const SizedBox(height: 22),
          OnboardingHeadline(
            l10n.emailVerifyHeadline,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          OnboardingSupportText(
            l10n.emailVerifyBody(email),
            textAlign: TextAlign.center,
          ),
          if (isLikelyUndeliverable) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  AppLocalizations.of(context)!.emailVerifyDevAddressHint,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          ],
          const SizedBox(height: 28),
          OnboardingPrimaryButton(
            label: l10n.deleteAccountReauthPasswordAction,
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
          const OnboardingSignOutButton(),
          const SizedBox(height: 26),
        ],
      ),
    );
  }
}
