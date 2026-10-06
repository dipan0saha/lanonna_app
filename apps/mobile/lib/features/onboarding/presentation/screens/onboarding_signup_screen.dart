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
import '../widgets/onboarding_logo_mark.dart';
import '../widgets/onboarding_fields.dart';
import '../widgets/onboarding_scaffold.dart';

class OnboardingSignupScreen extends StatefulWidget {
  const OnboardingSignupScreen({super.key});

  @override
  State<OnboardingSignupScreen> createState() => _OnboardingSignupScreenState();
}

class _OnboardingSignupScreenState extends State<OnboardingSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _error;
  bool _busy = false;
  var _synced = false;

  @override
  void dispose() {
    _persistEmail();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _persistEmail() async {
    await context.read<OnboardingCoordinator>().saveSignupEmailDraft(
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
      await coordinator.setStep(OnboardingStep.signup);
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
        final draft = coordinator.signupEmailDraft;
        if (draft != null && draft.email.isNotEmpty) {
          _emailController.text = draft.email;
        }
      }
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AuthRepository>().signUpWithEmail(
            _emailController.text,
            _passwordController.text,
          );
      if (!mounted) return;
      await navigateAfterOnboardingAuth(context, isSignUp: true, usedOAuth: false);
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? e.code);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _google() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AuthRepository>().signInWithGoogle();
      if (!mounted) return;
      await navigateAfterOnboardingAuth(context, isSignUp: true, usedOAuth: true);
    } catch (e) {
      setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      pinBottomCta: false,
      showBack: true,
      onBack: () => goBackFromInviteAuth(context, persist: _persistEmail),
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 6),
            const OnboardingLogoMark(),
            const SizedBox(height: 26),
            OnboardingGoogleButton(onPressed: _busy ? null : _google, isLoading: _busy),
            const OnboardingDivider(),
            OnboardingTextField(
              fieldKey: const Key('onboarding_signup_email'),
              controller: _emailController,
              label: 'Email',
              hint: 'you@email.com',
              keyboardType: TextInputType.emailAddress,
              validator: validateEmail,
              onChanged: (_) => _persistEmail(),
            ),
            const SizedBox(height: 16),
            OnboardingPasswordField(
              fieldKey: const Key('onboarding_signup_password'),
              controller: _passwordController,
              validator: validatePassword,
            ),
            const SizedBox(height: 8),
            const OnboardingHelperText(
              'At least 6 characters, with a number or symbol.',
            ),
            const SizedBox(height: 20),
            OnboardingPrimaryButton(
              buttonKey: const Key('onboarding_signup_submit'),
              label: 'Create Account',
              isLoading: _busy,
              onPressed: _busy ? null : _submit,
            ),
            OnboardingBottomLink(
              prefix: 'Already have an account? ',
              actionLabel: 'Log in',
              onTap: _busy ? () {} : () => context.go(loginRouteForContext(context)),
            ),
            if (_error != null)
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            const SizedBox(height: 26),
          ],
        ),
      ),
    );
  }
}
