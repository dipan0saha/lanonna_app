import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_error_message.dart';
import '../../../core/input/app_text_input_kind.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/prototype_subpage_scaffold.dart';
import '../../home/data/home_repository.dart';
import '../../home/data/selected_baby_store.dart';
import '../../onboarding/data/create_baby_draft.dart';
import '../../onboarding/data/onboarding_repository.dart';
import '../../onboarding/domain/baby_gender.dart';
import '../../onboarding/domain/baby_lifecycle.dart';
import '../../onboarding/domain/onboarding_routes.dart';
import '../../onboarding/domain/onboarding_step.dart';
import '../../onboarding/presentation/app_session.dart';
import '../../onboarding/presentation/onboarding_coordinator.dart';
import '../../onboarding/presentation/utils/onboarding_baby_helpers.dart';
import '../../onboarding/presentation/utils/onboarding_back_navigation.dart';
import '../../onboarding/presentation/widgets/onboarding_buttons.dart';
import '../../onboarding/presentation/widgets/onboarding_fields.dart';
import '../../onboarding/presentation/widgets/onboarding_prototype_widgets.dart';
import '../../onboarding/presentation/widgets/onboarding_scaffold.dart';
import '../../onboarding/presentation/widgets/onboarding_typography.dart';
import '../domain/create_baby_mode.dart';
import '../domain/create_baby_submit.dart';

const _genderBoy = 'Boy';
const _genderGirl = 'Girl';
const _genderUnsure = 'Not sure yet';

class CreateBabyScreen extends StatefulWidget {
  const CreateBabyScreen({super.key, required this.mode});

  final CreateBabyMode mode;

  @override
  State<CreateBabyScreen> createState() => _CreateBabyScreenState();
}

class _CreateBabyScreenState extends State<CreateBabyScreen> {
  final _boyNameController = TextEditingController();
  final _girlNameController = TextEditingController();
  final _picker = ImagePicker();

  var _synced = false;
  var _busy = false;
  var _babyStatus = BabyLifecycle.expecting;
  var _genderPill = _genderUnsure;
  DateTime? _selectedDate;
  XFile? _selectedImage;
  var _sharePhotoToGallery = false;
  String? _error;

  bool get _isOnboarding => widget.mode == CreateBabyMode.onboarding;

  BabyGender get _selectedGender => babyGenderFromPill(_genderPill);

  OnboardingBabyNameFieldsMode get _nameFieldsMode =>
      onboardingBabyNameFieldsMode(status: _babyStatus, gender: _selectedGender);

  String get _dateLabel =>
      _babyStatus == BabyLifecycle.expecting ? 'Expected Due Date' : 'Date of birth';

  String get _primaryButtonLabel => _isOnboarding ? 'Continue' : 'Create Baby';

  @override
  void dispose() {
    _boyNameController.dispose();
    _girlNameController.dispose();
    super.dispose();
  }

  Future<void> _syncDraft() async {
    if (!_isOnboarding || !mounted) return;
    final coordinator = context.read<OnboardingCoordinator>();
    await coordinator.saveCreateBabyDraft(
      CreateBabyDraft(
        lifecycle: _babyStatus.apiValue,
        genderPill: _genderPill,
        dateIso: _selectedDate?.toIso8601String(),
        boyName: _boyNameController.text,
        girlName: _girlNameController.text,
        photoPath: _selectedImage?.path,
        sharePhotoToGallery: _sharePhotoToGallery,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isOnboarding || _synced) return;
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
        _sharePhotoToGallery = draft.sharePhotoToGallery;
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
    });
    _syncDraft();
  }

  Future<void> _pickPhoto() async {
    final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    setState(() {
      _selectedImage = file;
      _sharePhotoToGallery = false;
    });
    _syncDraft();
  }

  Future<void> _submit() async {
    if (_busy) return;
    await _syncDraft();
    if (!mounted) return;
    if (_babyStatus == BabyLifecycle.born &&
        _selectedDate != null &&
        onboardingBirthDateIsInFuture(_selectedDate!)) {
      AppSnackBar.showAlert(context, 'Date of birth cannot be in the future.');
      return;
    }
    if (_babyStatus == BabyLifecycle.expecting &&
        _selectedDate != null &&
        onboardingDueDateIsBeforeToday(_selectedDate!)) {
      AppSnackBar.showAlert(context, 'Expected due date cannot be in the past.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      if (!mounted) return;
      final repository = context.read<OnboardingRepository>();
      final homeRepo = context.read<HomeRepository>();
      final api = context.read<ApiClient>();
      final coordinator = context.read<OnboardingCoordinator>();
      final baby = await submitCreateBaby(
        context: context,
        mode: widget.mode,
        input: CreateBabyFormInput(
          status: _babyStatus,
          gender: _selectedGender,
          selectedDate: _selectedDate,
          boyName: _boyNameController.text,
          girlName: _girlNameController.text,
          selectedImage: _selectedImage,
          sharePhotoToGallery: _sharePhotoToGallery,
        ),
        repository: repository,
        homeRepo: homeRepo,
        api: api,
        coordinator: coordinator,
        onNonFatalError: (message) {
          if (mounted) AppSnackBar.showAlert(context, message);
        },
      );

      if (!mounted) return;
      final store = context.read<SelectedBabyStore>();
      await store.setSelectedBabyId(baby.id);

      if (_isOnboarding) {
        final coordinator = context.read<OnboardingCoordinator>();
        final session = context.read<AppSession>();
        await coordinator.setCreatedBabyId(baby.id);
        await coordinator.saveBabyContext(lifecycle: _babyStatus.apiValue);
        await coordinator.setStep(OnboardingStep.firstMoment);
        await session.refreshFromApi();
        if (mounted) context.go(OnboardingRoutes.ownerFirstMoment);
      } else if (mounted) {
        context.go('/home');
      }
    } catch (e) {
      setState(() => _error = apiErrorMessage(e));
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
              kind: AppTextInputKind.personName,
              fieldKey: const Key('onboarding_baby_name'),
              onChanged: (_) => _syncDraft(),
            ),
            const SizedBox(height: 16),
            OnboardingTextField(
              controller: _girlNameController,
              label: "Girl's name (optional)",
              hint: 'e.g. Olivia',
              kind: AppTextInputKind.personName,
              onChanged: (_) => _syncDraft(),
            ),
          ],
        );
      case OnboardingBabyNameFieldsMode.bornSingleBoy:
        return OnboardingTextField(
          controller: _boyNameController,
          label: "Boy's name (optional)",
          hint: 'e.g. Liam',
          kind: AppTextInputKind.personName,
          fieldKey: const Key('onboarding_baby_name'),
          onChanged: (_) => _syncDraft(),
        );
      case OnboardingBabyNameFieldsMode.bornSingleGirl:
        return OnboardingTextField(
          controller: _girlNameController,
          label: "Girl's name (optional)",
          hint: 'e.g. Olivia',
          kind: AppTextInputKind.personName,
          fieldKey: const Key('onboarding_baby_name'),
          onChanged: (_) => _syncDraft(),
        );
    }
  }

  Widget _buildPhotoPicker() {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const OnboardingFieldLabel('Profile photo (optional)'),
        const SizedBox(height: 8),
        Center(
          child: PrototypePhotoUpload(
            imageFile: _selectedImage,
            onTap: _busy ? null : _pickPhoto,
            label: _selectedImage != null ? 'Change profile photo' : 'Add profile photo',
            showLabel: false,
          ),
        ),
        if (_selectedImage != null) ...[
          const SizedBox(height: 4),
          Semantics(
            identifier: 'onboarding_create_baby_share_gallery',
            child: CheckboxListTile(
              value: _sharePhotoToGallery,
              onChanged: _busy
                  ? null
                  : (v) {
                      setState(() => _sharePhotoToGallery = v ?? false);
                      _syncDraft();
                    },
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                'Also share this photo in the gallery',
                style: text.bodyMedium,
              ),
              subtitle: Text(
                'Off by default. Followers only see gallery photos you choose to share.',
                style: text.bodySmall?.copyWith(color: AppColors.muted),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFormColumn() {
    final genderOptions = onboardingShowsUnsureGenderPill(_babyStatus)
        ? [_genderBoy, _genderGirl, _genderUnsure]
        : [_genderBoy, _genderGirl];
    final selectedGenderIndex = genderOptions.indexOf(_genderPill);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_isOnboarding) ...[
          const SizedBox(height: 10),
          const OnboardingHeadline("Create your baby's profile"),
          const SizedBox(height: 8),
          const OnboardingSupportText(
            'You can always add or change these details later.',
          ),
          const SizedBox(height: 20),
        ],
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
        const OnboardingFieldLabel('Gender'),
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
          onSelected: (index) {
            setState(() => _genderPill = genderOptions[index]);
            _syncDraft();
          },
        ),
        const SizedBox(height: 18),
        _buildNameFields(),
        const SizedBox(height: 20),
        _buildPhotoPicker(),
        const SizedBox(height: 20),
        OnboardingPrimaryButton(
          semanticsId: _isOnboarding
              ? 'onboarding_create_baby_continue'
              : 'in_app_create_baby_submit',
          label: _primaryButtonLabel,
          isLoading: _busy,
          onPressed: _busy ? null : _submit,
        ),
        const SizedBox(height: 26),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          if (_isOnboarding)
            const OnboardingHelperText('Tap Continue to try again.')
          else
            const OnboardingHelperText('Tap Create Baby to try again.'),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isOnboarding) {
      return OnboardingScaffold(
        pinBottomCta: false,
        showBack: true,
        onBack: () => goOnboardingBack(
          context,
          step: OnboardingStep.completeProfile,
          route: OnboardingRoutes.completeProfile,
          persist: _syncDraft,
        ),
        body: _buildFormColumn(),
      );
    }

    return PrototypeSubpageScaffold(
      title: 'Add Baby',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [_buildFormColumn()],
      ),
    );
  }
}
