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
import '../../../core/widgets/app_labeled_text_field.dart';
import '../../../core/api/display_photo_upload.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/prototype_subpage_scaffold.dart';
import '../../onboarding/presentation/widgets/onboarding_prototype_widgets.dart';
import '../data/account_repository.dart';

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
      _birthDate = DateTime.tryParse(account.birthDate!);
    }
    _networkAvatarUrl = account.avatarUrl;
    setState(() {});
  }

  Future<void> _pickPhoto() async {
    final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
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
    final d = _birthDate!;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _save() async {
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
        avatarUrl = await DisplayPhotoUpload(context.read<ApiClient>()).uploadProfileAvatar(
          imageFile: File(_photoFile!.path),
        );
      }
      if (!mounted) return;
      await context.read<AccountRepository>().updateProfile(
            displayName: displayName.isEmpty ? 'Account' : displayName,
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
        child: ListView(
          children: [
            Center(
              child: PrototypePhotoUpload(
                imageFile: _photoFile,
                imageUrl: _photoFile == null ? _networkAvatarUrl : null,
                onTap: _saving ? null : _pickPhoto,
                onSignedUrlError: _load,
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text('Tap to change photo', style: TextStyle(fontSize: 12)),
            ),
            const SizedBox(height: 16),
            AppLabeledTextField(
              label: 'First name',
              kind: AppTextInputKind.personName,
              controller: _firstName,
            ),
            AppLabeledTextField(
              label: 'Last name',
              kind: AppTextInputKind.personName,
              controller: _lastName,
            ),
            AppLabeledTextField(
              label: 'Email',
              kind: AppTextInputKind.none,
              controller: _email,
              enabled: false,
            ),
            AppLabeledTextField(
              label: 'Phone number (optional)',
              controller: _phone,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date of birth (optional)'),
              subtitle: Text(_birthDateApi() ?? 'Select a date'),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: _saving ? null : _pickBirthDate,
            ),
            const SizedBox(height: 8),
            AppCountryDropdownField(
              countries: _countries,
              value: _countryCode,
              enabled: !_saving,
              decoration: const InputDecoration(labelText: 'Country (optional)'),
              onChanged: (v) => setState(() => _countryCode = v),
            ),
            AppLabeledTextField(
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
    );
  }
}
