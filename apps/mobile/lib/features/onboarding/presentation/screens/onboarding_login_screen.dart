import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/api/api_error_message.dart';
import '../../../../core/auth/auth_error_message.dart';
import '../../../../core/auth/auth_repository.dart';
import '../../../../core/auth/biometric_sign_in_service.dart';
import '../../../../core/validation/form_validators.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/onboarding_form_drafts.dart';
import '../../../invitations/presentation/invite_flow_state.dart';
import '../../domain/onboarding_routes.dart';
import '../../domain/onboarding_step.dart';
import '../onboarding_coordinator.dart';
import '../utils/onboarding_auth_navigation.dart';
import '../utils/onboarding_invite_navigation.dart';
import '../widgets/onboarding_buttons.dart';
import '../widgets/onboarding_logo_mark.dart';
import '../widgets/onboarding_fields.dart';
import '../widgets/forgot_password_dialog.dart';
import '../widgets/onboarding_scaffold.dart';
import '../widgets/onboarding_typography.dart';

class OnboardingLoginScreen extends StatefulWidget {
  const OnboardingLoginScreen({super.key});

  @override
  State<OnboardingLoginScreen> createState() => _OnboardingLoginScreenState();
}

class _OnboardingLoginScreenState extends State<OnboardingLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _error;
  bool _busy = false;
  var _synced = false;
  var _validateOnInteraction = false;
  var _biometricBusy = false;

  AutovalidateMode get _autovalidateMode => _validateOnInteraction
      ? AutovalidateMode.onUserInteraction
      : AutovalidateMode.disabled;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _persistEmail() async {
    await context.read<OnboardingCoordinator>().saveLoginEmailDraft(
      AuthEmailDraft(email: _emailController.text),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_synced) return;
    _synced = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final coordinator = context.read<OnboardingCoordinator>();
      await coordinator.setStep(OnboardingStep.login);
      if (!mounted) return;
      final flow = context.read<InviteFlowState>();
      final resume = flow.takeInviteResume();
      if (resume != null) {
        await coordinator.restoreInviteHandoff(
          token: resume.token,
          path: resume.path,
          preview: resume.preview,
        );
      }
      if (!mounted) return;
      final prefill = flow.takeLoginPrefillEmail();
      if (prefill != null && prefill.isNotEmpty) {
        _emailController.text = prefill;
      } else {
        final draft = coordinator.loginEmailDraft;
        if (draft != null && draft.email.isNotEmpty) {
          _emailController.text = draft.email;
        }
      }
    });
  }

  String _loginSubtext(OnboardingCoordinator coordinator) {
    if (coordinator.isInvitePath) {
      return AppLocalizations.of(context)!.onboardingSignInToAcceptYour;
    }
    return AppLocalizations.of(context)!.onboardingSignInToContinueSetting;
  }

  Future<void> _signInEmail() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) {
      setState(() => _validateOnInteraction = true);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AuthRepository>().signInWithEmail(
        _emailController.text,
        _passwordController.text,
      );
      if (!mounted) return;
      await navigateAfterOnboardingAuth(
        context,
        usedOAuth: false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      setState(() => _error = authErrorMessage(e, l10n, flow: AuthFlow.signIn));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgotPassword() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context)!;
    var email = _emailController.text.trim();
    if (validateEmail(AppLocalizations.of(context)!, email) != null) {
      final chosen = await showForgotPasswordEmailDialog(
        context,
        initialEmail: email,
      );
      if (chosen == null || chosen.isEmpty || !mounted) return;
      email = chosen;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AuthRepository>().sendPasswordResetEmail(email);
      if (!mounted) return;
      AppSnackBar.showInfo(context, l10n.authPasswordResetSent);
    } on FirebaseAuthException catch (e) {
      setState(
        () => _error = authErrorMessage(e, l10n, flow: AuthFlow.passwordReset),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signInGoogle() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AuthRepository>().signInWithGoogle();
      if (!mounted) return;
      await navigateAfterOnboardingAuth(
        context,
        usedOAuth: true,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      setState(() => _error = authErrorMessage(e, l10n, flow: AuthFlow.signIn));
    } catch (e) {
      final msg = apiErrorMessage(AppLocalizations.of(context)!, e);
      if (msg.contains('ApiException: 10') || msg.contains('DEVELOPER_ERROR')) {
        setState(
          () => _error =
              AppLocalizations.of(context)!.onboardingGoogleSignInIsNot,
        );
      } else {
        setState(() => _error = msg);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signInBiometric() async {
    if (_busy || _biometricBusy) return;
    setState(() {
      _biometricBusy = true;
      _error = null;
    });
    final l10n = AppLocalizations.of(context)!;
    try {
      await context.read<BiometricSignInService>().signIn(
        promptMessage: l10n.biometricSignInReason,
      );
      if (!mounted) return;
      await navigateAfterOnboardingAuth(
        context,
        usedOAuth: false,
      );
    } on BiometricSignInFailure catch (e) {
      if (mounted && e.reason != BiometricSignInFailureReason.cancelled) {
        setState(() => _error = e.userMessage(l10n));
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _error = authErrorMessage(e, l10n, flow: AuthFlow.signIn));
      }
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(l10n, e));
    } finally {
      if (mounted) setState(() => _biometricBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final coordinator = context.watch<OnboardingCoordinator>();
    // Re-read each build: a failed sign-in can clear a dead enrollment.
    final biometricEnrollment = context.read<BiometricSignInService>().enrollment;

    return OnboardingScaffold(
      pinBottomCta: false,
      showBack: true,
      onBack: () => goBackFromInviteAuth(context, persist: _persistEmail),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 6),
          const OnboardingLogoMark(),
          const SizedBox(height: 20),
          OnboardingHeadline(AppLocalizations.of(context)!.onboardingWelcomeBack),
          const SizedBox(height: 8),
          OnboardingSupportText(_loginSubtext(coordinator)),
          const SizedBox(height: 24),
          if (biometricEnrollment != null) ...[
            OnboardingBiometricButton(
              onPressed: _busy ? null : _signInBiometric,
              isLoading: _biometricBusy,
              displayName: biometricEnrollment.displayName,
            ),
            const SizedBox(height: 12),
          ],
          OnboardingGoogleButton(
            onPressed: (_busy || _biometricBusy) ? null : _signInGoogle,
            isLoading: _busy,
          ),
          OnboardingDivider(label: l10n.labelSignEmail),
          if (_error != null) ...[
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 12),
          ],
          Form(
            key: _formKey,
            autovalidateMode: _autovalidateMode,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OnboardingTextField(
                  fieldKey: const Key('onboarding_login_email'),
                  semanticsId: 'auth_login_email',
                  controller: _emailController,
                  label: l10n.authPasswordResetEmailLabel,
                  hint: l10n.messageEmailCom,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => validateEmail(AppLocalizations.of(context)!, v),
                  autovalidateMode: _autovalidateMode,
                  onChanged: (_) => _persistEmail(),
                ),
                const SizedBox(height: 16),
                OnboardingPasswordField(
                  fieldKey: const Key('onboarding_login_password'),
                  semanticsId: 'auth_login_password',
                  controller: _passwordController,
                  label: l10n.fieldPassword,
                  hint: l10n.hintEnterPassword,
                  validator: (v) => validatePassword(AppLocalizations.of(context)!, v),
                  autovalidateMode: _autovalidateMode,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    key: const Key('forgot_password_link'),
                    onPressed: _busy ? null : _forgotPassword,
                    child: Text(l10n.authPasswordResetForgotLink),
                  ),
                ),
                const SizedBox(height: 12),
                OnboardingPrimaryButton(
                  buttonKey: const Key('sign_in_button'),
                  semanticsId: 'auth_sign_in',
                  label: l10n.authSignIn,
                  isLoading: _busy,
                  onPressed: _busy ? null : _signInEmail,
                ),
              ],
            ),
          ),
          OnboardingBottomLink(
            message: l10n.onboardingLoginAuthPrompt,
            actionText: l10n.authSignUp,
            onTap: _busy ? () {} : () => context.go(OnboardingRoutes.signup),
          ),
          const SizedBox(height: 26),
        ],
      ),
    );
  }
}
