import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_error_message.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/data/iso_countries.dart';
import '../../../core/input/app_text_input_kind.dart';
import '../../../core/widgets/app_country_dropdown_field.dart';
import '../../../core/validation/form_validators.dart';
import '../../../core/widgets/app_labeled_text_form_field.dart';
import '../../../core/api/display_photo_upload.dart';
import '../../../core/time/app_date_time.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/prototype_subpage_scaffold.dart';
import '../../onboarding/presentation/widgets/onboarding_prototype_widgets.dart';
import '../data/account_repository.dart';
import '../../../l10n/app_localizations.dart';

class AccountEditScreen extends StatefulWidget {
  const AccountEditScreen({super.key});

  @override
  State<AccountEditScreen> createState() => _AccountEditScreenState();
}

class _AccountEditScreenState extends State<AccountEditScreen> {
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _postal = TextEditingController();
  final _picker = ImagePicker();
  String? _networkAvatarUrl;
  XFile? _photoFile;
  DateTime? _birthDate;
  String? _countryCode;
  List<IsoCountry> _countries = const [];
  var _saving = false;
  var _validateOnInteraction = false;
  final _formKey = GlobalKey<FormState>();

  AutovalidateMode get _autovalidateMode => _validateOnInteraction
      ? AutovalidateMode.onUserInteraction
      : AutovalidateMode.disabled;

  bool get _hasAvatarPhoto {
    if (_photoFile != null) return true;
    final url = _networkAvatarUrl?.trim();
    return url != null && url.isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    _loadCountries();
    _load();
  }

  Future<void> _loadCountries() async {
    final list = await IsoCountries.load();
    if (mounted) setState(() => _countries = list);
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _phone.dispose();
    _postal.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final account = await context.read<AccountRepository>().fetchAccount();
    if (!mounted) return;
    final name = account.displayName ?? '';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      _firstName.text = parts.first;
      _lastName.text = parts.sublist(1).join(' ');
    } else {
      _firstName.text = name;
    }
    _email.text = account.email ?? '';
    _phone.text = account.phone ?? '';
    _postal.text = account.postalCode ?? '';
    _countryCode = account.countryCode;
    if (account.birthDate != null && account.birthDate!.isNotEmpty) {
      _birthDate = tryParseApiCalendarDate(account.birthDate);
    }
    _networkAvatarUrl = account.avatarUrl;
    setState(() {});
  }

  String? _validateLastName(String? value) {
    final required = validateOnboardingLastName(value);
    if (required != null) return required;
    return validateOnboardingProfileDisplayName(_firstName.text, value ?? '');
  }

  Future<void> _pickPhoto() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file == null) return;
    setState(() => _photoFile = file);
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
  }

  String? _birthDateApi() {
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

  Future<void> _save() async {
    if (_formKey.currentState?.validate() != true) {
      setState(() => _validateOnInteraction = true);
      return;
    }
    setState(() => _saving = true);
    try {
      final first = AppTextInputPolicy.normalizeForSubmit(
        AppTextInputKind.personName,
        _firstName.text,
      );
      final last = AppTextInputPolicy.normalizeForSubmit(
        AppTextInputKind.personName,
        _lastName.text,
      );
      final displayName = '$first $last'.trim();
      String? avatarUrl = _networkAvatarUrl;
      if (_photoFile != null && !kIsWeb) {
        avatarUrl = await DisplayPhotoUpload(
          context.read<ApiClient>(),
        ).uploadProfileAvatar(imageFile: File(_photoFile!.path));
      }
      if (!mounted) return;
      await context.read<AccountRepository>().updateProfile(
        displayName: displayName,
        avatarUrl: avatarUrl,
        phone: _phone.text.trim(),
        birthDate: _birthDateApi(),
        countryCode: _countryCode,
        postalCode: _postal.text.trim(),
        sendExplicitNulls: true,
      );
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        AppSnackBar.showAlert(context, apiErrorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PrototypeSubpageScaffold(
      title: 'Edit Profile',
      body: Padding(
        padding: AppMetrics.subpageScrollPadding,
        child: Form(
          key: _formKey,
          autovalidateMode: _autovalidateMode,
          child: ListView(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PrototypePhotoUpload(
                      imageFile: _photoFile,
                      imageUrl: _photoFile == null ? _networkAvatarUrl : null,
                      onTap: _saving ? null : _pickPhoto,
                      onSignedUrlError: _load,
                    ),
                    OnboardingPhotoCaption(
                      hasPhoto: _hasAvatarPhoto,
                      onTap: _saving ? null : _pickPhoto,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AppLabeledTextFormField(
                label: 'First name',
                kind: AppTextInputKind.personName,
                controller: _firstName,
                autovalidateMode: _autovalidateMode,
                validator: validateOnboardingFirstName,
              ),
              AppLabeledTextFormField(
                label: 'Last name',
                kind: AppTextInputKind.personName,
                controller: _lastName,
                autovalidateMode: _autovalidateMode,
                validator: _validateLastName,
              ),
              AppLabeledTextFormField(
                label: 'Email',
                kind: AppTextInputKind.none,
                controller: _email,
                enabled: false,
              ),
              AppLabeledTextFormField(
                label: 'Phone number (optional)',
                controller: _phone,
                keyboardType: TextInputType.phone,
                autovalidateMode: _autovalidateMode,
                validator: validateOptionalPhone,
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(AppLocalizations.of(context)!.accountDateOfBirthOptional),
                subtitle: Text(_birthDateDisplay(context) ?? 'Select a date'),
                trailing: const Icon(Icons.calendar_today_outlined),
                onTap: _saving ? null : _pickBirthDate,
              ),
              const SizedBox(height: 8),
              AppCountryDropdownField(
                countries: _countries,
                value: _countryCode,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: 'Country (optional)',
                ),
                onChanged: (v) => setState(() => _countryCode = v),
              ),
              AppLabeledTextFormField(
                label: 'Zip / Postal code (optional)',
                controller: _postal,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Saving…' : 'Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
