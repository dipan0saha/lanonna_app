import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_error_message.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/input/app_text_input_kind.dart';
import '../../../core/validation/form_validators.dart';
import '../../../core/widgets/app_labeled_text_field.dart';
import '../../../core/widgets/app_labeled_text_form_field.dart';
import '../../../core/api/display_photo_upload.dart';
import '../../../core/time/app_date_time.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/theme/la_nonna_theme.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/prototype_subpage_scaffold.dart';
import '../../onboarding/presentation/widgets/onboarding_prototype_widgets.dart';
import '../../onboarding/presentation/widgets/onboarding_typography.dart';
import '../../gallery/domain/gallery_refresh.dart';
import '../data/announcement_repository.dart';
import '../domain/announcement_navigation.dart';
import '../../../l10n/app_localizations.dart';

class AnnouncementCreateScreen extends StatefulWidget {
  const AnnouncementCreateScreen({super.key, required this.babyId});

  final String babyId;

  @override
  State<AnnouncementCreateScreen> createState() =>
      _AnnouncementCreateScreenState();
}

class _AnnouncementCreateScreenState extends State<AnnouncementCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  var _autovalidateMode = AutovalidateMode.disabled;
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _weight = TextEditingController();
  final _length = TextEditingController();
  final _picker = ImagePicker();

  var _saving = false;
  var _loading = true;
  String? _gender; // male | female
  DateTime? _birthDate;
  TimeOfDay? _birthTime;
  XFile? _photo;
  String? _existingPhotoUrl;

  bool get _hasAnnouncementPhoto {
    if (_photo != null) return true;
    final url = _existingPhotoUrl?.trim();
    return url != null && url.isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _weight.dispose();
    _length.dispose();
    super.dispose();
  }

  Future<void> _prefill() async {
    try {
      final detail = await context.read<AnnouncementRepository>().fetch(
        widget.babyId,
      );
      if (detail != null) {
        _first.text = detail.firstName ?? '';
        _last.text = detail.lastName ?? '';
        _weight.text = detail.weightText ?? '';
        _length.text = detail.lengthText ?? '';
        _gender = detail.gender;
        if (detail.birthDate != null) {
          _birthDate = tryParseApiCalendarDate(detail.birthDate);
        }
      if (detail.birthTime != null && detail.birthTime!.contains(':')) {
        final parts = detail.birthTime!.split(':');
        if (parts.length >= 2) {
          _birthTime = TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 12,
            minute: int.tryParse(parts[1]) ?? 0,
          );
        }
      }
        _existingPhotoUrl = detail.photoDisplayUrl;
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showAlert(context, apiErrorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickPhoto() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file != null) setState(() => _photo = file);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _birthTime ?? const TimeOfDay(hour: 12, minute: 0),
    );
    if (picked != null) setState(() => _birthTime = picked);
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

  String? _birthTimeLabel(BuildContext context) {
    final raw = _formatBirthTime();
    if (raw == null) return null;
    final formatted = formatApiClockTime(
      raw,
      Localizations.localeOf(context).toString(),
    );
    return formatted.isEmpty ? raw : formatted;
  }

  String? _formatBirthTime() {
    if (_birthTime == null) return null;
    final t = _birthTime!;
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _save() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) {
      setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
      return;
    }
    final firstName = AppTextInputPolicy.normalizeForSubmit(
      AppTextInputKind.personName,
      _first.text,
    );
    if (firstName.isEmpty) return;
    final lastName = AppTextInputPolicy.normalizeForSubmit(
      AppTextInputKind.personName,
      _last.text,
    );
    final weightText = AppTextInputPolicy.normalizeForSubmit(
      AppTextInputKind.measurement,
      _weight.text,
    );
    final lengthText = AppTextInputPolicy.normalizeForSubmit(
      AppTextInputKind.measurement,
      _length.text,
    );
    setState(() => _saving = true);
    try {
      String? photoId;
      if (_photo != null && !kIsWeb) {
        photoId = await DisplayPhotoUpload(context.read<ApiClient>())
            .uploadGalleryPhoto(
              babyProfileId: widget.babyId,
              imageFile: File(_photo!.path),
            );
        if (mounted) notifyGalleryDataChanged(context);
      }
      if (!mounted) return;
      await context.read<AnnouncementRepository>().save(
        widget.babyId,
        firstName: firstName,
        lastName: lastName.isEmpty ? null : lastName,
        gender: _gender,
        birthDate: _birthDateForApi(),
        birthTime: _formatBirthTime(),
        weightText: weightText.isEmpty ? null : weightText,
        lengthText: lengthText.isEmpty ? null : lengthText,
        photoId: photoId,
      );
      if (mounted) showAnnouncementCardAfterSave(context, widget.babyId);
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
    final l10n = AppLocalizations.of(context)!;
    if (_loading) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return PrototypeSubpageScaffold(
      title: l10n.actionAnnounceArrival,
      body: Form(
        key: _formKey,
        autovalidateMode: _autovalidateMode,
        child: ListView(
          padding: AppMetrics.subpageFormScrollPadding,
          children: [
            Text(
              l10n.actionShareNews,
              style: context.textStyles.bodyMedium?.copyWith(
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PrototypePhotoUpload(
                    imageFile: _photo,
                    imageUrl: _existingPhotoUrl,
                    onTap: _pickPhoto,
                    size: 100,
                  ),
                  OnboardingPhotoCaption(
                    hasPhoto: _hasAnnouncementPhoto,
                    onTap: _pickPhoto,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppLabeledTextFormField(
              key: const Key('announcement_first_name'),
              semanticsId: 'announcement_first_name',
              label: l10n.fieldFirstName,
              kind: AppTextInputKind.personName,
              controller: _first,
              maxLength: 50,
              validator: validateOnboardingFirstName,
              autovalidateMode: _autovalidateMode,
            ),
            AppLabeledTextField(
              label: l10n.fieldLastName,
              kind: AppTextInputKind.personName,
              controller: _last,
              maxLength: 50,
            ),
            const OnboardingFieldLabel('Gender'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: AppToggleChip(
                    label: l10n.funGenderBoy,
                    selected: _gender == 'male',
                    onTap: () => setState(() => _gender = 'male'),
                  ),
                ),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppToggleChip(
                    label: l10n.funGenderGirl,
                    selected: _gender == 'female',
                    selectedAccent: AppChipAccent.peach,
                    onTap: () => setState(() => _gender = 'female'),
                  ),
                ),
              ],
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(AppLocalizations.of(context)!.announcementDateOfBirth),
              subtitle: Text(_birthDateDisplay(context) ?? 'Tap to choose'),
              trailing: const Icon(Icons.calendar_today_outlined, size: 20),
              onTap: _pickDate,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(AppLocalizations.of(context)!.announcementTimeOfBirth),
              subtitle: Text(_birthTimeLabel(context) ?? 'Optional'),
              trailing: const Icon(Icons.schedule_outlined, size: 20),
              onTap: _pickTime,
            ),
            AppLabeledTextField(
              label: l10n.announcementWeightLabel,
              kind: AppTextInputKind.measurement,
              controller: _weight,
              maxLength: 40,
            ),
            AppLabeledTextField(
              label: l10n.announcementLengthLabel,
              kind: AppTextInputKind.measurement,
              controller: _length,
              maxLength: 40,
              spacingAfter: 0,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving…' : 'Save Announcement'),
            ),
          ],
        ),
      ),
    );
  }
}
