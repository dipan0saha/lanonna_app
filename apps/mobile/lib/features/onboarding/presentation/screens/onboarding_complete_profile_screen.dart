import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/input/app_text_input_kind.dart';
import '../../../../core/api/display_photo_upload.dart';
import '../../../../core/validation/form_validators.dart';
import '../../data/onboarding_form_drafts.dart';
import '../../data/onboarding_repository.dart';
import '../../domain/onboarding_routes.dart';
import '../../domain/onboarding_step.dart';
import '../app_session.dart';
import '../onboarding_coordinator.dart';
import '../widgets/onboarding_buttons.dart';
import '../widgets/onboarding_fields.dart';
import '../widgets/onboarding_prototype_widgets.dart';
import '../widgets/onboarding_scaffold.dart';
import '../utils/invite_flow_navigation.dart';
import '../utils/onboarding_back_navigation.dart';
import '../widgets/onboarding_typography.dart';

class OnboardingCompleteProfileScreen extends StatefulWidget {
  const OnboardingCompleteProfileScreen({super.key});

  @override
  State<OnboardingCompleteProfileScreen> createState() =>
      _OnboardingCompleteProfileScreenState();
}

class _OnboardingCompleteProfileScreenState extends State<OnboardingCompleteProfileScreen> {
  final _nameController = TextEditingController();
  final _picker = ImagePicker();
  String? _error;
  bool _busy = false;
  bool _acceptedTerms = true;
  XFile? _photoFile;
  String? _networkPhotoUrl;
  String _subtext = 'Add your name and photo so family knows who\'s who.';
  String _photoLabel = 'Add a photo';
  var _hydrated = false;

  @override
  void dispose() {
    _persistDraft();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _persistDraft() async {
    await context.read<OnboardingCoordinator>().saveCompleteProfileDraft(
      CompleteProfileDraft(
        fullName: _nameController.text,
        termsAccepted: _acceptedTerms,
        photoPath: _photoFile?.path,
        networkPhotoUrl: _networkPhotoUrl,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hydrated) return;
    _hydrated = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final coordinator = context.read<OnboardingCoordinator>();
      final draft = coordinator.completeProfileDraft;
      if (draft != null) {
        _nameController.text = draft.fullName;
        _acceptedTerms = draft.termsAccepted;
        if (draft.photoPath != null) {
          _photoFile = XFile(draft.photoPath!);
          _photoLabel = 'Change photo';
        }
        if (draft.networkPhotoUrl != null && draft.networkPhotoUrl!.isNotEmpty) {
          _networkPhotoUrl = draft.networkPhotoUrl;
          if (_photoFile == null) {
            _photoLabel = 'Imported from your account';
          }
        }
        setState(() {});
        if (draft.fullName.isNotEmpty) return;
      }
      final user = FirebaseAuth.instance.currentUser;
      final usedOAuth = coordinator.skipEmailVerify;
      if (usedOAuth && user != null) {
        _nameController.text = user.displayName ?? '';
        final googlePhoto = user.photoURL;
        if (googlePhoto != null && googlePhoto.isNotEmpty) {
          _networkPhotoUrl = googlePhoto;
          _photoLabel = 'Imported from your account';
        }
        _subtext = _networkPhotoUrl != null
            ? "We've pulled your name and photo from Google. Just confirm they look right."
            : "We've pulled your name from Google. Add a photo if you'd like.";
        setState(() {});
      }
    });
  }

  Future<void> _pickPhoto() async {
    final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    setState(() {
      _photoFile = file;
      _photoLabel = 'Change photo';
    });
    await _persistDraft();
  }

  Future<void> _continue() async {
    await _persistDraft();
    if (!_acceptedTerms) {
      setState(() => _error = 'Please accept the terms to continue');
      return;
    }
    final nameError = validateDisplayName(_nameController.text);
    if (nameError != null) {
      setState(() => _error = nameError);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      String? avatarUrl = _networkPhotoUrl;
      if (_photoFile != null && !kIsWeb) {
        avatarUrl = await DisplayPhotoUpload(context.read<ApiClient>()).uploadProfileAvatar(
          imageFile: File(_photoFile!.path),
        );
      }
      await context.read<OnboardingRepository>().updateProfile(
            displayName: AppTextInputPolicy.normalizeForSubmit(
              AppTextInputKind.personName,
              _nameController.text,
            ),
            avatarUrl: avatarUrl,
          );
      await context.read<AppSession>().refreshFromApi();
      if (!mounted) return;
      await navigateAfterCompleteProfile(context);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onBack() async {
    final coordinator = context.read<OnboardingCoordinator>();
    if (coordinator.skipEmailVerify) {
      await goOnboardingBack(
        context,
        step: OnboardingStep.signup,
        route: OnboardingRoutes.signup,
        persist: _persistDraft,
      );
    } else {
      await goOnboardingBack(
        context,
        step: OnboardingStep.emailVerify,
        route: OnboardingRoutes.emailVerify,
        persist: _persistDraft,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      pinBottomCta: false,
      showBack: true,
      onBack: _onBack,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          const OnboardingHeadline('Complete your profile'),
          const SizedBox(height: 8),
          OnboardingSupportText(_subtext),
          const SizedBox(height: 20),
          Center(
            child: PrototypePhotoUpload(
              imageFile: _photoFile,
              imageUrl: _photoFile == null ? _networkPhotoUrl : null,
              onTap: _busy ? null : _pickPhoto,
              label: _photoLabel,
            ),
          ),
          const SizedBox(height: 22),
          OnboardingTextField(
            fieldKey: const Key('onboarding_display_name'),
            controller: _nameController,
            label: 'Full name',
            hint: 'Your name',
            kind: AppTextInputKind.personName,
            onChanged: (_) => _persistDraft(),
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            value: _acceptedTerms,
            onChanged: _busy
                ? null
                : (v) {
                    setState(() => _acceptedTerms = v ?? false);
                    _persistDraft();
                  },
            title: const Text('I agree to the Terms of Service and Privacy Policy'),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 12),
          OnboardingPrimaryButton(
            semanticsId: 'onboarding_complete_profile_continue',
            label: 'Continue',
            isLoading: _busy,
            onPressed: _busy ? null : _continue,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 26),
        ],
      ),
    );
  }
}
