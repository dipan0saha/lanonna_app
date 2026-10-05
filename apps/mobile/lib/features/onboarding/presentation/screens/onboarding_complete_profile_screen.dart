import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_error_message.dart';
import '../../../../core/data/iso_countries.dart';
import '../../../../core/input/app_text_input_kind.dart';
import '../../../../core/api/display_photo_upload.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/la_nonna_theme.dart';
import '../../../../core/validation/form_validators.dart';
import '../../data/onboarding_form_drafts.dart';
import '../../data/onboarding_repository.dart';
import '../../domain/onboarding_path.dart';
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
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _postalController = TextEditingController();
  final _picker = ImagePicker();
  String? _error;
  bool _busy = false;
  bool _acceptedTerms = false;
  XFile? _photoFile;
  String? _networkPhotoUrl;
  String _subtext =
      'Add your name and photo so family knows who\'s who.';
  String _photoLabel = 'Add a photo';
  var _hydrated = false;
  List<IsoCountry> _countries = const [];
  String? _countryCode;
  DateTime? _birthDate;
  String? _relationshipLabel;

  bool get _isOwnerPath {
    final coordinator = context.read<OnboardingCoordinator>();
    return coordinator.onboardingPath == OnboardingPath.owner;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _postalController.dispose();
    super.dispose();
  }

  Future<void> _persistDraft() async {
    if (!mounted) return;
    await context.read<OnboardingCoordinator>().saveCompleteProfileDraft(
          CompleteProfileDraft(
            firstName: _firstNameController.text,
            lastName: _lastNameController.text,
            phone: _phoneController.text,
            birthDateIso: _birthDate?.toIso8601String().split('T').first,
            countryCode: _countryCode,
            postalCode: _postalController.text,
            relationshipLabel: _relationshipLabel,
            termsAccepted: _acceptedTerms,
            photoPath: _photoFile?.path,
            networkPhotoUrl: _networkPhotoUrl,
          ),
        );
  }

  Future<void> _loadCountries() async {
    final list = await IsoCountries.load();
    if (mounted) setState(() => _countries = list);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hydrated) return;
    _hydrated = true;
    _loadCountries();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final coordinator = context.read<OnboardingCoordinator>();
      final draft = coordinator.completeProfileDraft;
      if (draft != null) {
        _firstNameController.text = draft.firstName;
        _lastNameController.text = draft.lastName;
        _phoneController.text = draft.phone;
        _postalController.text = draft.postalCode;
        _countryCode = draft.countryCode;
        _relationshipLabel = draft.relationshipLabel;
        _acceptedTerms = draft.termsAccepted;
        if (draft.birthDateIso != null && draft.birthDateIso!.isNotEmpty) {
          _birthDate = DateTime.tryParse(draft.birthDateIso!);
        }
        if (draft.photoPath != null) {
          _photoFile = XFile(draft.photoPath!);
          _photoLabel = 'Change photo';
        }
        if (draft.networkPhotoUrl != null && draft.networkPhotoUrl!.isNotEmpty) {
          _networkPhotoUrl = draft.networkPhotoUrl;
          if (_photoFile == null) {
            _photoLabel = 'Change photo';
          }
        }
        setState(() {});
        if (draft.firstName.isNotEmpty || draft.lastName.isNotEmpty) return;
      }
      try {
        if (Firebase.apps.isEmpty) return;
        final user = FirebaseAuth.instance.currentUser;
        final usedOAuth = coordinator.skipEmailVerify;
        if (usedOAuth && user != null) {
          final display = user.displayName ?? '';
          final parts = display.trim().split(RegExp(r'\s+'));
          if (parts.isNotEmpty && parts.first.isNotEmpty) {
            _firstNameController.text = parts.first;
            if (parts.length > 1) {
              _lastNameController.text = parts.sublist(1).join(' ');
            }
          }
          final googlePhoto = user.photoURL;
          if (googlePhoto != null && googlePhoto.isNotEmpty) {
            _networkPhotoUrl = googlePhoto;
            _photoLabel = 'Change photo';
          }
          _subtext =
              "We pulled in your details. Add a photo so family knows who's who.";
          setState(() {});
        }
      } on FirebaseException {
        return;
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

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 30),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked == null) return;
    setState(() => _birthDate = picked);
    await _persistDraft();
  }

  String? _birthDateLabel() {
    if (_birthDate == null) return null;
    return '${_birthDate!.year}-${_birthDate!.month.toString().padLeft(2, '0')}-${_birthDate!.day.toString().padLeft(2, '0')}';
  }

  Future<void> _continue() async {
    await _persistDraft();
    if (!_acceptedTerms) {
      setState(() => _error = 'Please accept the terms to continue');
      return;
    }
    if (_isOwnerPath &&
        (_relationshipLabel == null || _relationshipLabel!.isEmpty)) {
      setState(() => _error = 'Select your relationship to baby');
      return;
    }
    final displayName = AppTextInputPolicy.normalizeForSubmit(
      AppTextInputKind.personName,
      '${_firstNameController.text} ${_lastNameController.text}',
    );
    final nameError = validateDisplayName(displayName);
    if (nameError != null) {
      setState(() => _error = nameError);
      return;
    }
    if (_firstNameController.text.trim().isEmpty ||
        _lastNameController.text.trim().isEmpty) {
      setState(() => _error = 'First and last name are required');
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
            displayName: displayName,
            avatarUrl: avatarUrl,
            phone: _phoneController.text.trim(),
            birthDate: _birthDateLabel(),
            countryCode: _countryCode,
            postalCode: _postalController.text.trim(),
            acceptTerms: true,
          );
      await context.read<AppSession>().refreshFromApi();
      if (!mounted) return;
      await navigateAfterCompleteProfile(context);
    } catch (e) {
      setState(() => _error = apiErrorMessage(e));
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
    final text = context.textStyles;
    final ownerPath = _isOwnerPath;
    final relationshipIndex = _relationshipLabel == 'Father'
        ? 1
        : (_relationshipLabel == 'Mother' ? 0 : null);

    return OnboardingScaffold(
      pinBottomCta: false,
      showBack: true,
      onBack: _onBack,
      body: SingleChildScrollView(
        child: Column(
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
                showLabel: false,
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                _photoLabel,
                style: text.labelLarge?.copyWith(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 22),
            OnboardingTextField(
              fieldKey: const Key('onboarding_first_name'),
              controller: _firstNameController,
              label: 'First name',
              hint: 'First name',
              kind: AppTextInputKind.personName,
              onChanged: (_) => _persistDraft(),
            ),
            const SizedBox(height: 12),
            OnboardingTextField(
              fieldKey: const Key('onboarding_last_name'),
              controller: _lastNameController,
              label: 'Last name',
              hint: 'Last name',
              kind: AppTextInputKind.personName,
              onChanged: (_) => _persistDraft(),
            ),
            const SizedBox(height: 12),
            OnboardingTextField(
              controller: _phoneController,
              label: 'Phone number (optional)',
              hint: '(555) 555-5555',
              keyboardType: TextInputType.phone,
              onChanged: (_) => _persistDraft(),
            ),
            if (ownerPath) ...[
              const SizedBox(height: 16),
              OnboardingFieldLabel('Your relationship to baby'),
              const SizedBox(height: 8),
              OnboardingPillSelect(
                options: const ['Mother', 'Father'],
                selectedIndex: relationshipIndex,
                selectedStyleForIndex: (_) => const OnboardingPillSelectedStyle(
                  background: AppColors.sageTint,
                  border: AppColors.primaryDark,
                  foreground: AppColors.primaryDark,
                ),
                onSelected: (index) {
                  setState(() {
                    _relationshipLabel = index == 0 ? 'Mother' : 'Father';
                  });
                  _persistDraft();
                },
              ),
            ],
            const SizedBox(height: 16),
            OnboardingFieldLabel('Date of birth (optional)'),
            const SizedBox(height: 8),
            InkWell(
              onTap: _busy ? null : _pickBirthDate,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: const InputDecoration(
                  hintText: 'Select a date',
                  suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                ),
                child: Text(
                  _birthDateLabel() ?? 'Select a date',
                  style: text.bodyMedium?.copyWith(
                    color: _birthDate == null ? AppColors.muted : null,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            OnboardingFieldLabel('Country (optional)'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _countryCode,
              isExpanded: true,
              decoration: const InputDecoration(hintText: 'Select a country'),
              items: [
                for (final c in _countries)
                  DropdownMenuItem(
                    value: c.code,
                    child: Text(c.name, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: _busy
                  ? null
                  : (code) {
                      setState(() => _countryCode = code);
                      _persistDraft();
                    },
            ),
            const SizedBox(height: 12),
            OnboardingTextField(
              controller: _postalController,
              label: 'Zip / Postal code (optional)',
              hint: 'e.g. 94103',
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
              title: RichText(
                text: TextSpan(
                  style: text.bodySmall?.copyWith(color: AppColors.muted),
                  children: [
                    const TextSpan(text: 'I agree to the '),
                    TextSpan(
                      text: 'Terms of Service',
                      style: text.bodySmall?.copyWith(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w600,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () => context.push('/legal/terms'),
                    ),
                    const TextSpan(text: ' and '),
                    TextSpan(
                      text: 'Privacy Policy',
                      style: text.bodySmall?.copyWith(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w600,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () => context.push('/legal/privacy'),
                    ),
                  ],
                ),
              ),
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
      ),
    );
  }
}
