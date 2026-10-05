import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/api/api_error_message.dart';
import '../../../../core/auth/auth_repository.dart';
import '../../../../core/validation/form_validators.dart';
import '../../data/onboarding_form_drafts.dart';
import '../../domain/onboarding_path.dart';
import '../../domain/onboarding_step.dart';
import '../onboarding_coordinator.dart';
import '../utils/onboarding_auth_navigation.dart';
import '../utils/onboarding_invite_navigation.dart';
import '../widgets/onboarding_buttons.dart';
import '../widgets/onboarding_carousel.dart';
import '../widgets/onboarding_fields.dart';
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
      final params = GoRouterState.of(context).uri.queryParameters;
      final inviteToken = params['invite_token'];
      if (inviteToken != null && inviteToken.isNotEmpty) {
        await coordinator.setPendingInviteToken(inviteToken);
      }
      final path = OnboardingPath.fromSignupQuery(params['path']);
      if (path != null && path != OnboardingPath.owner) {
        await coordinator.saveOnboardingPath(path);
      }
      final invitedEmail = params['email'];
      if (invitedEmail != null && invitedEmail.isNotEmpty) {
        _emailController.text = Uri.decodeComponent(invitedEmail);
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
      return 'Sign in to accept your invitation and continue.';
    }
    return 'Sign in to continue setting up your family space.';
  }

  Future<void> _signInEmail() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
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
      await navigateAfterOnboardingAuth(context, isSignUp: false, usedOAuth: false);
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? e.code);
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
      await navigateAfterOnboardingAuth(context, isSignUp: false, usedOAuth: true);
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? e.code);
    } catch (e) {
      final msg = apiErrorMessage(e);
      if (msg.contains('ApiException: 10') || msg.contains('DEVELOPER_ERROR')) {
        setState(() => _error =
            'Google Sign-In is not configured for this Android build yet. '
            'Use email/password, or enable Google in Firebase for lanonna-dev.');
      } else {
        setState(() => _error = msg);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final coordinator = context.watch<OnboardingCoordinator>();

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
          const OnboardingHeadline('Welcome back'),
          const SizedBox(height: 8),
          OnboardingSupportText(_loginSubtext(coordinator)),
          const SizedBox(height: 24),
          OnboardingGoogleButton(
            onPressed: _busy ? null : _signInGoogle,
            isLoading: _busy,
          ),
          const OnboardingDivider(label: 'or sign in with email'),
          if (_error != null) ...[
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            const SizedBox(height: 12),
          ],
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OnboardingTextField(
                  fieldKey: const Key('onboarding_login_email'),
                  semanticsId: 'auth_login_email',
                  controller: _emailController,
                  label: 'Email',
                  hint: 'you@email.com',
                  keyboardType: TextInputType.emailAddress,
                  validator: validateEmail,
                  onChanged: (_) => _persistEmail(),
                ),
                const SizedBox(height: 16),
                OnboardingPasswordField(
                  fieldKey: const Key('onboarding_login_password'),
                  semanticsId: 'auth_login_password',
                  controller: _passwordController,
                  label: 'Password',
                  hint: 'Enter your password',
                  validator: validatePassword,
                ),
                const SizedBox(height: 20),
                OnboardingPrimaryButton(
                  buttonKey: const Key('sign_in_button'),
                  semanticsId: 'auth_sign_in',
                  label: 'Sign in',
                  isLoading: _busy,
                  onPressed: _busy ? null : _signInEmail,
                ),
              ],
            ),
          ),
          OnboardingBottomLink(
            prefix: "Don't have an account? ",
            actionLabel: 'Sign up',
            onTap: _busy ? () {} : () => context.go(signupRouteForContext(context)),
          ),
          const SizedBox(height: 26),
        ],
      ),
    );
  }
}
