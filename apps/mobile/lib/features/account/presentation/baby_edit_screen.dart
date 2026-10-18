import 'package:lanonna/core/domain/baby_gender.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_error_message.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/input/app_text_input_kind.dart';
import '../../../core/widgets/app_labeled_text_field.dart';
import '../../../core/api/display_photo_upload.dart';
import '../../../core/media/photo_selection.dart';
import '../../../core/media/pick_display_photo.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/theme/la_nonna_theme.dart';
import '../../../core/widgets/prototype_subpage_scaffold.dart';
import '../../home/data/home_repository.dart';
import '../../../core/domain/baby_summary.dart';
import '../../../core/time/app_date_time.dart';
import '../../onboarding/presentation/widgets/onboarding_fields.dart';
import '../../onboarding/presentation/widgets/onboarding_prototype_widgets.dart';
import '../../onboarding/presentation/widgets/onboarding_typography.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_button_styles.dart';
import '../../baby/presentation/delete_baby_profile_flow.dart';

class BabyEditScreen extends StatefulWidget {
  const BabyEditScreen({super.key, required this.babyId});

  final String babyId;

  @override
  State<BabyEditScreen> createState() => _BabyEditScreenState();
}

class _BabyEditScreenState extends State<BabyEditScreen> {
  final _name = TextEditingController();
  BabySummary? _baby;
  var _loading = true;
  var _saving = false;
  BabyGender? _gender;
  DateTime? _date;
  PhotoSelection _avatar = const PhotoSelection.none();

  bool get _isBorn => _baby?.isBorn == true;
  bool get _isOwner => _baby?.role == 'owner';

  /// A born baby with no recorded gender shows no pill selected until the
  /// owner picks one.
  int? get _genderPillIndex {
    final gender = _gender;
    if (gender == null || (_isBorn && gender == BabyGender.unknown)) {
      return _isBorn ? null : BabyGender.unknown.index;
    }
    return gender.index;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final babies = await context.read<HomeRepository>().listBabies();
    final baby = babies.where((b) => b.id == widget.babyId).firstOrNull;
    DateTime? parsed;
    final born = baby?.isBorn == true;
    final raw = born ? baby?.actualBirthDate : baby?.expectedBirthDate;
    if (raw != null) parsed = tryParseApiCalendarDate(raw);
    setState(() {
      _baby = baby;
      _name.text = baby?.name ?? '';
      _gender = baby?.gender;
      _date = parsed;
      _avatar = PhotoSelection.fromStored(
        baby?.avatarUrl,
        previewUrl: baby?.avatarUrl,
      );
      _loading = false;
    });
  }

  Future<void> _pickPhoto() async {
    if (!_isOwner) return;
    final file = await pickDisplayPhoto();
    if (file == null || !mounted) return;
    setState(() => _avatar = PhotoSelection.local(file));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    // The name is optional: clearing the field removes it and the app
    // shows the localized fallback (FR-ONB-004).
    final name = AppTextInputPolicy.normalizeForSubmit(
      AppTextInputKind.personName,
      _name.text,
    );
    setState(() => _saving = true);
    try {
      final dateIso = _date != null ? toApiCalendarDate(_date!) : null;
      final file = _avatar.localFile;
      if (_avatar.needsUpload && file != null) {
        final objectPath = await DisplayPhotoUpload(context.read<ApiClient>())
            .uploadBabyAvatar(
              babyProfileId: widget.babyId,
              imageFile: file,
            );
        if (!mounted) return;
        setState(() => _avatar = _avatar.uploaded(objectPath));
      }
      final avatarUrl = _avatar.remoteRef;
      if (!mounted) return;
      await context.read<HomeRepository>().updateBaby(
        widget.babyId,
        name: name,
        gender: _gender,
        expectedBirthDate: !_isBorn ? dateIso : null,
        actualBirthDate: _isBorn ? dateIso : null,
        avatarUrl: avatarUrl,
      );
      if (mounted) context.pop();
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
      title: l10n.actionEditBaby,
      body: ListView(
        padding: AppMetrics.subpageScrollPadding,
        children: [
          if (_isOwner) ...[
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PrototypePhotoUpload(
                    selection: _avatar,
                    onTap: _saving ? null : _pickPhoto,
                    busy: _saving && _avatar.needsUpload,
                    onSignedUrlError: _load,
                  ),
                  OnboardingPhotoCaption(
                    hasPhoto: _avatar.hasPhoto,
                    onTap: _saving ? null : _pickPhoto,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          AppLabeledTextField(
            label: l10n.labelBabyName,
            kind: AppTextInputKind.personName,
            controller: _name,
          ),
          OnboardingFieldLabel(AppLocalizations.of(context)!.babyGender),
          const SizedBox(height: 8),
          OnboardingPillSelect(
            options: [for (final g in BabyGender.values) g.label(l10n)],
            selectedIndex: _genderPillIndex,
            onSelected: (index) {
              setState(() {
                _gender = BabyGender.values[index];
              });
            },
            selectedStyleForIndex: (index) {
              if (index != 1) return null;
              return const OnboardingPillSelectedStyle(
                background: AppColors.peachTint,
                border: AppColors.secondaryDark,
                foreground: AppColors.secondaryDark,
              );
            },
          ),
          ListTile(
            title: Text(_isBorn ? AppLocalizations.of(context)!.announcementDateOfBirth : AppLocalizations.of(context)!.accountExpectedDueDate),
            subtitle: Text(
              _date != null
                  ? formatApiCalendarDateFromParts(
                      _date!,
                      localeNameForFormatting(context),
                    )
                  : AppLocalizations.of(context)!.accountTapToChoose,
            ),
            trailing: const Icon(Icons.calendar_today_outlined, size: 20),
            onTap: _pickDate,
          ),
          if (_baby != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                AppLocalizations.of(
                  context,
                )!.statusLabel(_baby!.lifecycle.label(l10n)),
                style: context.textStyles.bodySmall?.copyWith(
                  color: AppColors.muted,
                ),
              ),
            ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? AppLocalizations.of(context)!.notificationPrefsSaving : AppLocalizations.of(context)!.calendarSaveChanges),
          ),
          SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            onPressed: () => context.pop(),
            child: Text(AppLocalizations.of(context)!.actionCancel),
          ),
          if (_baby?.canDeleteProfile ?? false) ...[
            const SizedBox(height: AppSpacing.xxl),
            OutlinedButton(
              style: AppButtonStyles.outlinedDestructive,
              onPressed: _saving
                  ? null
                  : () async {
                      await deleteBabyProfileWithConfirmation(
                        context,
                        _baby!,
                      );
                    },
              child: Text(l10n.deleteBabyProfileAction),
            ),
          ],
        ],
      ),
    );
  }
}
