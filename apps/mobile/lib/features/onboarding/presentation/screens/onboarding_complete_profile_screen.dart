
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:provider/provider.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_error_message.dart';
import '../../../../core/data/iso_countries.dart';
import '../../../../core/input/app_text_input_kind.dart';
import '../../../../core/api/display_photo_upload.dart';
import '../../../../core/media/photo_selection.dart';
import '../../../../core/media/pick_display_photo.dart';
import '../../../../core/time/app_date_time.dart';
import '../../../../core/validation/form_validators.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/la_nonna_theme.dart';
import '../../../../core/widgets/app_country_dropdown_field.dart';
import '../../../legal/domain/legal_routes.dart';
import '../../../account/data/account_repository.dart';
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
import '../../../../l10n/app_localizations.dart';

class OnboardingCompleteProfileScreen extends StatefulWidget {
  const OnboardingCompleteProfileScreen({super.key});

  @override
  State<OnboardingCompleteProfileScreen> createState() =>
      _OnboardingCompleteProfileScreenState();
}

class _OnboardingCompleteProfileScreenState
    extends State<OnboardingCompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  var _validateOnInteraction = false;
  AutovalidateMode get _autovalidateMode => _validateOnInteraction
      ? AutovalidateMode.onUserInteraction
      : AutovalidateMode.disabled;

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _postalController = TextEditingController();
  String? _error;
  bool _busy = false;
  bool _acceptedTerms = false;
  XFile? _photoFile;
  String? _networkPhotoUrl;
  bool _prefilledFromProvider = false;
  var _hydrated = false;
  List<IsoCountry> _countries = const [];
  String? _countryCode;
  DateTime? _birthDate;
  String? _relationshipLabel;

  bool get _isOwnerPath {
    final coordinator = context.read<OnboardingCoordinator>();
    return coordinator.onboardingPath == OnboardingPath.owner;
  }

  /// The picked file wins over the provider/server photo until upload.
  PhotoSelection get _photo => _photoFile != null
      ? PhotoSelection.local(_photoFile!)
      : PhotoSelection.fromStored(_networkPhotoUrl, previewUrl: _networkPhotoUrl);

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
        birthDateIso:
            _birthDate != null ? toApiCalendarDate(_birthDate!) : null,
        countryCode: _countryCode,
        postalCode: _postalController.text,
        relationshipLabel: _relationshipLabel,
        termsAccepted: _acceptedTerms,
        photoPath: _photoFile?.path,
        networkPhotoUrl: _networkPhotoUrl,
      ),
    );
  }

  Future<void> _hydrateFromServerProfile() async {
    if (_firstNameController.text.trim().isNotEmpty ||
        _lastNameController.text.trim().isNotEmpty) {
      return;
    }
    try {
      final account = await context.read<AccountRepository>().fetchAccount();
      final name = account.displayName ?? '';
      final parts = name.trim().split(RegExp(r'\s+'));
      if (parts.isNotEmpty && parts.first.isNotEmpty) {
        _firstNameController.text = parts.first;
        if (parts.length > 1) {
          _lastNameController.text = parts.sublist(1).join(' ');
        }
      }
      if (_phoneController.text.isEmpty) {
        _phoneController.text = account.phone ?? '';
      }
      if (_postalController.text.isEmpty) {
        _postalController.text = account.postalCode ?? '';
      }
      _countryCode ??= account.countryCode;
      if (_birthDate == null &&
          account.birthDate != null &&
          account.birthDate!.isNotEmpty) {
        _birthDate = tryParseApiCalendarDate(account.birthDate);
      }
      if (_networkPhotoUrl == null && account.avatarUrl != null) {
        _networkPhotoUrl = account.avatarUrl;
      }
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {});
        });
      }
    } catch (_) {
      // Offline or first sign-up; form stays empty.
    }
  }

  Future<void> _loadCountries() async {
    final list = await IsoCountries.load();
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _countries = list);
    });
  }

  void _applyHydratedState(VoidCallback apply) {
    apply();
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hydrated) return;
    _hydrated = true;
    _loadCountries();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final coordinator = context.read<OnboardingCoordinator>();
      final draft = coordinator.completeProfileDraft;
      if (draft != null) {
        _applyHydratedState(() {
          _firstNameController.text = draft.firstName;
          _lastNameController.text = draft.lastName;
          _phoneController.text = draft.phone;
          _postalController.text = draft.postalCode;
          _countryCode = draft.countryCode;
          _relationshipLabel = draft.relationshipLabel;
          _acceptedTerms = draft.termsAccepted;
          if (draft.birthDateIso != null && draft.birthDateIso!.isNotEmpty) {
            _birthDate = tryParseApiCalendarDate(draft.birthDateIso);
          }
          if (draft.photoPath != null) {
            _photoFile = XFile(draft.photoPath!);
          }
          if (draft.networkPhotoUrl != null &&
              draft.networkPhotoUrl!.isNotEmpty) {
            _networkPhotoUrl = draft.networkPhotoUrl;
          }
        });
        if (draft.firstName.isNotEmpty || draft.lastName.isNotEmpty) return;
      }
      await _hydrateFromServerProfile();
      try {
        if (Firebase.apps.isEmpty) return;
        final user = FirebaseAuth.instance.currentUser;
        final usedOAuth = coordinator.skipEmailVerify;
        if (usedOAuth && user != null) {
          _applyHydratedState(() {
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
            }
            _prefilledFromProvider = true;
          });
        }
      } on FirebaseException {
        return;
      }
    });
  }

  Future<void> _pickPhoto() async {
    final file = await pickDisplayPhoto();
    if (file == null) return;
    setState(() => _photoFile = file);
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

  String? _birthDateForApi() {
    if (_birthDate == null) return null;
    return toApiCalendarDate(_birthDate!);
  }

  String? _birthDateDisplay(BuildContext context) {
    if (_birthDate == null) return null;
    return formatApiCalendarDateFromParts(
      _birthDate!,
      localeNameForFormatting(context),
    );
  }

  void _clearApiError() {
    if (_error != null) setState(() => _error = null);
  }

  String? _validateLastName(String? value) {
    final required = validateOnboardingLastName(AppLocalizations.of(context)!, value);
    if (required != null) return required;
    return validateOnboardingProfileDisplayName(AppLocalizations.of(context)!, 
      _firstNameController.text,
      value ?? '',
    );
  }

  Future<void> _continue() async {
    await _persistDraft();
    if (!mounted) return;
    if (_formKey.currentState?.validate() != true) {
      setState(() => _validateOnInteraction = true);
      return;
    }
    final displayName = AppTextInputPolicy.normalizeForSubmit(
      AppTextInputKind.personName,
      '${_firstNameController.text} ${_lastNameController.text}',
    );
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      String? avatarUrl = _networkPhotoUrl;
      final file = _photoFile;
      if (file != null) {
        avatarUrl = await DisplayPhotoUpload(
          context.read<ApiClient>(),
        ).uploadProfileAvatar(imageFile: file);
      }
      if (!mounted) return;
      await context.read<OnboardingRepository>().updateProfile(
        displayName: displayName,
        avatarUrl: avatarUrl,
        phone: _phoneController.text.trim(),
        birthDate: _birthDateForApi(),
        countryCode: _countryCode,
        postalCode: _postalController.text.trim(),
        acceptTerms: true,
      );
      if (!mounted) return;
      await context.read<AppSession>().refreshFromApi();
      if (!mounted) return;
      await navigateAfterCompleteProfile(context);
    } catch (e) {
      setState(() => _error = apiErrorMessage(AppLocalizations.of(context)!, e));
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
    final l10n = AppLocalizations.of(context)!;
    final text = context.textStyles;
    final ownerPath = _isOwnerPath;

    return OnboardingScaffold(
      pinBottomCta: false,
      showBack: true,
      onBack: _onBack,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            OnboardingHeadline(AppLocalizations.of(context)!.onboardingCompleteYourProfile),
            const SizedBox(height: 8),
            OnboardingSupportText(
              _prefilledFromProvider
                  ? l10n.onboardingWePulledInYourDetails
                  : l10n.onboardingCompleteProfileSubtext,
            ),
            const SizedBox(height: 20),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PrototypePhotoUpload(
                    selection: _photo,
                    onTap: _busy ? null : _pickPhoto,
                    busy: _busy && _photo.needsUpload,
                  ),
                  OnboardingPhotoCaption(
                    hasPhoto: _photo.hasPhoto,
                    onTap: _busy ? null : _pickPhoto,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Form(
              key: _formKey,
              autovalidateMode: _autovalidateMode,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OnboardingTextField(
                    fieldKey: const Key('onboarding_first_name'),
                    controller: _firstNameController,
                    label: l10n.fieldFirstName,
                    hint: l10n.fieldFirstName,
                    kind: AppTextInputKind.personName,
                    autovalidateMode: _autovalidateMode,
                    validator: (v) => validateOnboardingFirstName(AppLocalizations.of(context)!, v),
                    onChanged: (_) {
                      _clearApiError();
                      _persistDraft();
                    },
                  ),
                  const SizedBox(height: 12),
                  OnboardingTextField(
                    fieldKey: const Key('onboarding_last_name'),
                    controller: _lastNameController,
                    label: l10n.fieldLastName,
                    hint: l10n.fieldLastName,
                    kind: AppTextInputKind.personName,
                    autovalidateMode: _autovalidateMode,
                    validator: _validateLastName,
                    onChanged: (_) {
                      _clearApiError();
                      _persistDraft();
                    },
                  ),
                  const SizedBox(height: 12),
                  OnboardingTextField(
                    controller: _phoneController,
                    label: l10n.fieldPhoneNumberOptional,
                    hint: '(555) 555-5555',
                    keyboardType: TextInputType.phone,
                    autovalidateMode: _autovalidateMode,
                    validator: (v) => validateOptionalPhone(AppLocalizations.of(context)!, v),
                    onChanged: (_) {
                      _clearApiError();
                      _persistDraft();
                    },
                  ),
                  if (ownerPath) ...[
                    const SizedBox(height: 16),
                    OnboardingRelationshipFormField(
                      value: _relationshipLabel,
                      autovalidateMode: _autovalidateMode,
                      validator: (v) => validateOnboardingRelationshipToBaby(AppLocalizations.of(context)!, v),
                      onSelected: (label) {
                        setState(() => _relationshipLabel = label);
                        _clearApiError();
                        _persistDraft();
                      },
                    ),
                  ],
                  const SizedBox(height: 16),
                  OnboardingFieldLabel(AppLocalizations.of(context)!.accountDateOfBirthOptional),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _busy ? null : _pickBirthDate,
                    borderRadius: BorderRadius.circular(12),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        hintText: l10n.fieldSelectDate,
                        suffixIcon: Icon(
                          Icons.calendar_today_outlined,
                          size: 18,
                        ),
                      ),
                      child: Text(
                        _birthDateDisplay(context) ?? AppLocalizations.of(context)!.fieldSelectDate,
                        style: text.bodyMedium?.copyWith(
                          color: _birthDate == null ? AppColors.muted : null,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  OnboardingFieldLabel(AppLocalizations.of(context)!.fieldCountryOptional),
                  const SizedBox(height: 8),
                  AppCountryDropdownField(
                    countries: _countries,
                    value: _countryCode,
                    enabled: !_busy,
                    onChanged: (code) {
                      setState(() => _countryCode = code);
                      _clearApiError();
                      _persistDraft();
                    },
                  ),
                  const SizedBox(height: 12),
                  OnboardingTextField(
                    controller: _postalController,
                    label: l10n.fieldZipPostalCodeOptional,
                    hint: l10n.labelEG94103,
                    onChanged: (_) {
                      _clearApiError();
                      _persistDraft();
                    },
                  ),
                  const SizedBox(height: 8),
                  OnboardingTermsFormField(
                    value: _acceptedTerms,
                    enabled: !_busy,
                    autovalidateMode: _autovalidateMode,
                    validator: (v) => validateTermsAccepted(AppLocalizations.of(context)!, v),
                    onChanged: (accepted) {
                      setState(() => _acceptedTerms = accepted);
                      _clearApiError();
                      _persistDraft();
                    },
                    onTermsTap: () => context.push(LegalRoutes.terms),
                    onPrivacyTap: () => context.push(LegalRoutes.privacy),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            OnboardingPrimaryButton(
              semanticsId: 'onboarding_complete_profile_continue',
              label: l10n.deleteAccountReauthPasswordAction,
              isLoading: _busy,
              onPressed: _busy ? null : _continue,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 26),
          ],
        ),
      ),
    );
  }
}
