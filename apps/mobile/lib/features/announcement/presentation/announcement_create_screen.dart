import 'package:lanonna/core/domain/baby_gender.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_error_message.dart';
import '../../../core/media/photo_selection.dart';
import '../../../core/media/pick_display_photo.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/input/app_text_input_kind.dart';
import '../../../core/validation/form_validators.dart';
import '../../../core/widgets/app_labeled_text_field.dart';
import '../../../core/widgets/app_labeled_text_form_field.dart';
import '../../../core/time/app_date_time.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/theme/la_nonna_theme.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/prototype_subpage_scaffold.dart';
import '../../onboarding/presentation/widgets/onboarding_prototype_widgets.dart';
import '../../onboarding/presentation/widgets/onboarding_typography.dart';
import '../../gallery/data/gallery_repository.dart';
import '../../gallery/domain/gallery_refresh.dart';
import '../../home/data/home_repository.dart';
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

  var _saving = false;
  var _loading = true;
  BabyGender? _gender;
  DateTime? _birthDate;
  TimeOfDay? _birthTime;
  PhotoSelection _photo = const PhotoSelection.none();

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
      final baby = await context.read<HomeRepository>().babyById(widget.babyId);
      if (!mounted) return;
      if (baby == null || baby.role != 'owner') {
        AppSnackBar.showAlert(
          context,
          AppLocalizations.of(context)!.announcementOnlyOwnersCanCreate,
        );
        context.pop();
        return;
      }
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
        _photo = PhotoSelection.fromStored(
          detail.photoId,
          previewUrl: detail.photoDisplayUrl,
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showAlert(context, apiErrorMessage(AppLocalizations.of(context)!, e));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickPhoto() async {
    final file = await pickDisplayPhoto();
    if (file != null && mounted) setState(() => _photo = PhotoSelection.local(file));
  }

  /// Uploads a newly picked photo to the gallery. Marks the selection
  /// uploaded, so retrying a failed save does not upload twice.
  Future<String?> _photoIdForSave() async {
    final file = _photo.localFile;
    if (!_photo.needsUpload || file == null) return _photo.remoteRef;
    final photoId = await context.read<GalleryRepository>().uploadPhoto(
      widget.babyId,
      file,
    );
    if (mounted) {
      setState(() => _photo = _photo.uploaded(photoId));
      notifyGalleryDataChanged(context);
    }
    return photoId;
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
      final photoId = await _photoIdForSave();
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
        AppSnackBar.showAlert(context, apiErrorMessage(AppLocalizations.of(context)!, e));
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
                    selection: _photo,
                    onTap: _saving ? null : _pickPhoto,
                    busy: _saving && _photo.needsUpload,
                    size: AppMetrics.photoPickerAvatarSizeLarge,
                  ),
                  OnboardingPhotoCaption(
                    hasPhoto: _photo.hasPhoto,
                    onTap: _saving ? null : _pickPhoto,
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
              validator: (v) => validateOnboardingFirstName(AppLocalizations.of(context)!, v),
              autovalidateMode: _autovalidateMode,
            ),
            AppLabeledTextField(
              label: l10n.fieldLastName,
              kind: AppTextInputKind.personName,
              controller: _last,
              maxLength: 50,
            ),
            OnboardingFieldLabel(AppLocalizations.of(context)!.babyGender),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: AppToggleChip(
                    label: BabyGender.male.label(l10n),
                    selected: _gender == BabyGender.male,
                    onTap: () => setState(() => _gender = BabyGender.male),
                  ),
                ),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppToggleChip(
                    label: BabyGender.female.label(l10n),
                    selected: _gender == BabyGender.female,
                    selectedAccent: AppChipAccent.peach,
                    onTap: () => setState(() => _gender = BabyGender.female),
                  ),
                ),
              ],
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(AppLocalizations.of(context)!.announcementDateOfBirth),
              subtitle: Text(_birthDateDisplay(context) ?? AppLocalizations.of(context)!.accountTapToChoose),
              trailing: const Icon(Icons.calendar_today_outlined, size: 20),
              onTap: _pickDate,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(AppLocalizations.of(context)!.announcementTimeOfBirth),
              subtitle: Text(_birthTimeLabel(context) ?? AppLocalizations.of(context)!.announcementOptional),
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
              child: Text(_saving ? AppLocalizations.of(context)!.notificationPrefsSaving : AppLocalizations.of(context)!.announcementSaveAnnouncement),
            ),
          ],
        ),
      ),
    );
  }
}
