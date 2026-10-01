import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/display_photo_upload.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../home/data/selected_baby_store.dart';
import '../../data/create_baby_draft.dart';
import '../../data/onboarding_repository.dart';
import '../../domain/baby_gender.dart';
import '../../domain/baby_lifecycle.dart';
import '../../domain/onboarding_routes.dart';
import '../../domain/onboarding_step.dart';
import '../app_session.dart';
import '../onboarding_coordinator.dart';
import '../utils/onboarding_baby_helpers.dart';
import '../utils/onboarding_back_navigation.dart';
import '../widgets/onboarding_buttons.dart';
import '../widgets/onboarding_fields.dart';
import '../widgets/onboarding_prototype_widgets.dart';
import '../widgets/onboarding_scaffold.dart';
import '../widgets/onboarding_typography.dart';

const _genderBoy = 'Boy';
const _genderGirl = 'Girl';
const _genderUnsure = 'Not sure yet';

class OnboardingCreateBabyScreen extends StatefulWidget {
  const OnboardingCreateBabyScreen({super.key});

  @override
  State<OnboardingCreateBabyScreen> createState() =>
      _OnboardingCreateBabyScreenState();
}

class _OnboardingCreateBabyScreenState extends State<OnboardingCreateBabyScreen> {
  final _boyNameController = TextEditingController();
  final _girlNameController = TextEditingController();
  final _picker = ImagePicker();

  var _synced = false;
  var _busy = false;
  var _babyStatus = BabyLifecycle.expecting;
  var _genderPill = _genderUnsure;
  DateTime? _selectedDate;
  XFile? _selectedImage;
  String? _error;

  BabyGender get _selectedGender => babyGenderFromPill(_genderPill);

  OnboardingBabyNameFieldsMode get _nameFieldsMode =>
      onboardingBabyNameFieldsMode(status: _babyStatus, gender: _selectedGender);

  String get _dateLabel =>
      _babyStatus == BabyLifecycle.expecting ? 'Expected Due Date' : 'Date of birth';

  @override
  void dispose() {
    _syncDraft();
    _boyNameController.dispose();
    _girlNameController.dispose();
    super.dispose();
  }

  Future<void> _syncDraft() async {
    final coordinator = context.read<OnboardingCoordinator>();
    await coordinator.saveCreateBabyDraft(
      CreateBabyDraft(
        lifecycle: _babyStatus.apiValue,
        genderPill: _genderPill,
        dateIso: _selectedDate?.toIso8601String(),
        boyName: _boyNameController.text,
        girlName: _girlNameController.text,
        photoPath: _selectedImage?.path,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_synced) return;
    _synced = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<OnboardingCoordinator>().setStep(OnboardingStep.createBaby);
      final draft = context.read<OnboardingCoordinator>().createBabyDraft;
      if (draft != null) {
        _babyStatus = draft.lifecycle == 'born'
            ? BabyLifecycle.born
            : BabyLifecycle.expecting;
        _genderPill = draft.genderPill;
        if (_babyStatus == BabyLifecycle.born && _genderPill == _genderUnsure) {
          _genderPill = _genderBoy;
        }
        if (draft.dateIso != null) {
          final parsed = DateTime.tryParse(draft.dateIso!);
          _selectedDate = _babyStatus == BabyLifecycle.expecting
              ? onboardingSanitizeExpectingDueDate(parsed)
              : parsed;
        }
        _boyNameController.text = draft.boyName;
        _girlNameController.text = draft.girlName;
        if (draft.photoPath != null) {
          _selectedImage = XFile(draft.photoPath!);
        }
        setState(() {});
      }
    });
  }

  void _setBabyStatus(BabyLifecycle status) {
    if (_babyStatus == status) return;
    setState(() {
      _babyStatus = status;
      if (status == BabyLifecycle.born && _genderPill == _genderUnsure) {
        _genderPill = _genderBoy;
      }
      if (status == BabyLifecycle.born) {
        _selectedDate = onboardingSanitizeBornBirthDate(_selectedDate);
      } else {
        _selectedDate = onboardingSanitizeExpectingDueDate(_selectedDate);
      }
    });
    _syncDraft();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = onboardingDateAtMidnight(now);
    final initial = _babyStatus == BabyLifecycle.born
        ? onboardingBornDatePickerInitial(_selectedDate, now)
        : onboardingExpectingDatePickerInitial(_selectedDate, now);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: _babyStatus == BabyLifecycle.expecting
          ? today
          : DateTime(now.year - 2),
      lastDate: _babyStatus == BabyLifecycle.expecting
          ? DateTime(now.year + 2)
          : now,
    );
    if (picked == null) return;
    setState(() {
      _selectedDate = _babyStatus == BabyLifecycle.born
          ? onboardingSanitizeBornBirthDate(picked)
          : onboardingSanitizeExpectingDueDate(picked);
      _syncDraft();
    });
  }

  Future<void> _pickPhoto() async {
    final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    setState(() {
      _selectedImage = file;
      _syncDraft();
    });
  }

  Future<void> _continue() async {
    if (_busy) return;
    await _syncDraft();
    if (_babyStatus == BabyLifecycle.born &&
        _selectedDate != null &&
        onboardingBirthDateIsInFuture(_selectedDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Date of birth cannot be in the future.')),
      );
      return;
    }
    if (_babyStatus == BabyLifecycle.expecting &&
        _selectedDate != null &&
        onboardingDueDateIsBeforeToday(_selectedDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expected due date cannot be in the past.')),
      );
      return;
    }

    final name = resolveOnboardingBabyName(
      status: _babyStatus,
      gender: _selectedGender,
      boyName: _boyNameController.text,
      girlName: _girlNameController.text,
    );

    final repository = context.read<OnboardingRepository>();
    final store = context.read<SelectedBabyStore>();
    final coordinator = context.read<OnboardingCoordinator>();
    final session = context.read<AppSession>();
    final api = context.read<ApiClient>();

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final expected = _babyStatus == BabyLifecycle.expecting && _selectedDate != null
          ? formatApiDate(_selectedDate!)
          : null;
      final actual = _babyStatus == BabyLifecycle.born && _selectedDate != null
          ? formatApiDate(_selectedDate!)
          : null;

      final baby = await repository.createBaby(
        name: name,
        gender: _selectedGender.apiValue,
        lifecycleStatus: _babyStatus.apiValue,
        expectedBirthDate: expected,
        actualBirthDate: actual,
      );

      if (_selectedImage != null && !kIsWeb) {
        try {
          await DisplayPhotoUpload(api).uploadGalleryPhoto(
            babyProfileId: baby.id,
            imageFile: File(_selectedImage!.path),
          );
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Baby created; photo upload failed: $e')),
            );
          }
        }
      }

      await store.setSelectedBabyId(baby.id);
      await coordinator.setCreatedBabyId(baby.id);
      await coordinator.saveBabyContext(lifecycle: _babyStatus.apiValue);
      await coordinator.setStep(OnboardingStep.firstMoment);
      await session.refreshFromApi();
      if (mounted) context.go(OnboardingRoutes.ownerFirstMoment);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _buildNameFields() {
    switch (_nameFieldsMode) {
      case OnboardingBabyNameFieldsMode.expectingBoth:
        return Column(
          children: [
            OnboardingTextField(
              controller: _boyNameController,
              label: "Boy's name (optional)",
              hint: 'e.g. Liam',
              textCapitalization: TextCapitalization.words,
              fieldKey: const Key('onboarding_baby_name'),
              onChanged: (_) => _syncDraft(),
            ),
            const SizedBox(height: 16),
            OnboardingTextField(
              controller: _girlNameController,
              label: "Girl's name (optional)",
              hint: 'e.g. Olivia',
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => _syncDraft(),
            ),
          ],
        );
      case OnboardingBabyNameFieldsMode.bornSingleBoy:
        return OnboardingTextField(
          controller: _boyNameController,
          label: "Boy's name (optional)",
          hint: 'e.g. Liam',
          textCapitalization: TextCapitalization.words,
          fieldKey: const Key('onboarding_baby_name'),
          onChanged: (_) => _syncDraft(),
        );
      case OnboardingBabyNameFieldsMode.bornSingleGirl:
        return OnboardingTextField(
          controller: _girlNameController,
          label: "Girl's name (optional)",
          hint: 'e.g. Olivia',
          textCapitalization: TextCapitalization.words,
          fieldKey: const Key('onboarding_baby_name'),
          onChanged: (_) => _syncDraft(),
        );
    }
  }

  Widget _buildPhotoPicker() {
    return Center(
      child: PrototypePhotoUpload(
        imageFile: _selectedImage,
        onTap: _busy ? null : _pickPhoto,
        label: _selectedImage != null ? 'Change photo' : 'Add a photo',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final genderOptions = onboardingShowsUnsureGenderPill(_babyStatus)
        ? [_genderBoy, _genderGirl, _genderUnsure]
        : [_genderBoy, _genderGirl];
    final selectedGenderIndex = genderOptions.indexOf(_genderPill);

    return OnboardingScaffold(
      pinBottomCta: false,
      showBack: true,
      onBack: () => goOnboardingBack(
        context,
        step: OnboardingStep.completeProfile,
        route: OnboardingRoutes.completeProfile,
        persist: _syncDraft,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          const OnboardingHeadline("Create your baby's profile"),
          const SizedBox(height: 8),
          const OnboardingSupportText(
            'You can always add or change these details later.',
          ),
          const SizedBox(height: 20),
          OnboardingSegmentedControl(
            leftLabel: 'Expecting',
            rightLabel: 'Already Born',
            isLeftSelected: _babyStatus == BabyLifecycle.expecting,
            onLeftTap: () => _setBabyStatus(BabyLifecycle.expecting),
            onRightTap: () => _setBabyStatus(BabyLifecycle.born),
          ),
          const SizedBox(height: 18),
          PrototypeDateField(
            label: _dateLabel,
            value: _selectedDate,
            placeholder: 'Select a date',
            onTap: _busy ? () {} : _pickDate,
          ),
          const SizedBox(height: 18),
          Text(
            'Gender',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          OnboardingPillSelect(
            options: genderOptions,
            selectedIndex: selectedGenderIndex >= 0 ? selectedGenderIndex : null,
            selectedStyleForIndex: (index) {
              if (genderOptions[index] != _genderGirl) return null;
              return const OnboardingPillSelectedStyle(
                background: AppColors.peachTint,
                border: AppColors.secondaryDark,
                foreground: AppColors.secondaryDark,
              );
            },
            onSelected: (index) => setState(() {
              _genderPill = genderOptions[index];
              _syncDraft();
            }),
          ),
          const SizedBox(height: 18),
          _buildNameFields(),
          const SizedBox(height: 20),
          _buildPhotoPicker(),
          const SizedBox(height: 20),
          OnboardingPrimaryButton(
            label: 'Continue',
            isLoading: _busy,
            onPressed: _busy ? null : _continue,
          ),
          const SizedBox(height: 26),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const OnboardingHelperText('Tap Continue to try again.'),
          ],
        ],
      ),
    );
  }
}
