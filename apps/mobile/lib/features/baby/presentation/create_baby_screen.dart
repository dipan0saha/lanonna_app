import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_client.dart';
import '../../../core/domain/baby_summary.dart';
import '../../../core/time/app_date_time.dart';
import '../../../core/api/api_error_message.dart';
import '../../../core/input/app_text_input_kind.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/prototype_subpage_scaffold.dart';
import '../../home/data/home_refresh_signal.dart';
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
import '../domain/create_baby_form_hydration.dart';
import '../domain/create_baby_mode.dart';
import '../domain/create_baby_submit.dart';
import '../domain/owner_onboarding_baby_phase.dart';
import '../../onboarding/domain/owner_onboarding_baby_resolver.dart';
import '../../../l10n/app_localizations.dart';

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
  AppLocalizations get l10n => AppLocalizations.of(context)!;
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
      onboardingBabyNameFieldsMode(
        status: _babyStatus,
        gender: _selectedGender,
      );

  String get _dateLabel => _babyStatus == BabyLifecycle.expecting
      ? 'Expected Due Date'
      : 'Date of birth';

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

  bool get _isReviseOnboarding =>
      _isOnboarding &&
      ownerOnboardingBabyPhaseFor(context.read<OnboardingCoordinator>()) ==
          OwnerOnboardingBabyPhase.revise;

  void _applyDraft(CreateBabyDraft draft) {
    _babyStatus = draft.lifecycle == 'born'
        ? BabyLifecycle.born
        : BabyLifecycle.expecting;
    _genderPill = draft.genderPill;
    if (_babyStatus == BabyLifecycle.born && _genderPill == _genderUnsure) {
      _genderPill = _genderBoy;
    }
    if (draft.dateIso != null) {
      final parsed = tryParseApiCalendarDate(draft.dateIso);
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
  }

  Future<void> _hydrateFromServerBabyIfNeeded() async {
    final coordinator = context.read<OnboardingCoordinator>();
    if (ownerOnboardingBabyPhaseFor(coordinator) != OwnerOnboardingBabyPhase.revise) {
      return;
    }
    final homeRepo = context.read<HomeRepository>();
    final session = context.read<AppSession>();
    var babyId = coordinator.createdBabyId;
    if (babyId == null || babyId.isEmpty) {
      babyId = await OwnerOnboardingBabyResolver.resolve(
        coordinator: coordinator,
        readStatus: () => session.status,
        refreshStatus: session.refreshFromApi,
      );
    }
    if (babyId == null || babyId.isEmpty || !mounted) return;

    final babies = await homeRepo.listBabies();
    final baby = babies.where((b) => b.id == babyId).firstOrNull;
    if (baby == null || !mounted) return;

    final draft = coordinator.createBabyDraft;
    final hasDraftNames = draft != null &&
        (draft.boyName.trim().isNotEmpty || draft.girlName.trim().isNotEmpty);
    if (!hasDraftNames) {
      final fromSummary = CreateBabyFormFromSummary.fromBaby(baby);
      _babyStatus = fromSummary.lifecycle;
      _genderPill = fromSummary.genderPill;
      _selectedDate = fromSummary.selectedDate;
      if (_boyNameController.text.trim().isEmpty) {
        _boyNameController.text = fromSummary.boyName;
      }
      if (_girlNameController.text.trim().isEmpty) {
        _girlNameController.text = fromSummary.girlName;
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isOnboarding || _synced) return;
    _synced = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      // Widget tests mount this screen without a router. Once a router is
      // present, skip the step write if an invite link already left this route.
      final router = GoRouter.maybeOf(context);
      if (router != null &&
          GoRouterState.of(context).uri.path !=
              OnboardingRoutes.ownerCreateBaby) {
        return;
      }
      context.read<OnboardingCoordinator>().setStep(OnboardingStep.createBaby);
      final draft = context.read<OnboardingCoordinator>().createBabyDraft;
      if (draft != null) {
        _applyDraft(draft);
      }
      await _hydrateFromServerBabyIfNeeded();
      if (mounted) setState(() {});
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
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
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
      AppSnackBar.showAlert(
        context,
        'Expected due date cannot be in the past.',
      );
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
      final input = CreateBabyFormInput(
        status: _babyStatus,
        gender: _selectedGender,
        selectedDate: _selectedDate,
        boyName: _boyNameController.text,
        girlName: _girlNameController.text,
        selectedImage: _selectedImage,
        sharePhotoToGallery: _sharePhotoToGallery,
      );

      final BabySummary baby;
      if (_isOnboarding) {
        baby = await submitOwnerOnboardingBaby(
          context: context,
          input: input,
          repository: repository,
          homeRepo: homeRepo,
          api: api,
          coordinator: coordinator,
          onNonFatalError: (message) {
            if (mounted) AppSnackBar.showAlert(context, message);
          },
        );
      } else {
        baby = await submitCreateBaby(
          context: context,
          mode: widget.mode,
          input: input,
          repository: repository,
          homeRepo: homeRepo,
          api: api,
          coordinator: coordinator,
          onNonFatalError: (message) {
            if (mounted) AppSnackBar.showAlert(context, message);
          },
        );
      }

      if (!mounted) return;
      final store = context.read<SelectedBabyStore>();
      await store.setSelectedBabyId(baby.id);
      if (mounted) {
        context.read<HomeRefreshSignal>().notifyBabyContextChanged();
      }

      if (_isOnboarding) {
        if (!mounted) return;
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
              label: l10n.labelBoySNameOptional,
              hint: l10n.labelEGLiam,
              kind: AppTextInputKind.personName,
              fieldKey: const Key('onboarding_baby_name'),
              onChanged: (_) => _syncDraft(),
            ),
            const SizedBox(height: 16),
            OnboardingTextField(
              controller: _girlNameController,
              label: l10n.labelGirlSNameOptional,
              hint: l10n.labelEGOlivia,
              kind: AppTextInputKind.personName,
              onChanged: (_) => _syncDraft(),
            ),
          ],
        );
      case OnboardingBabyNameFieldsMode.bornSingleBoy:
        return OnboardingTextField(
          controller: _boyNameController,
          label: l10n.labelBoySNameOptional,
          hint: l10n.labelEGLiam,
          kind: AppTextInputKind.personName,
          fieldKey: const Key('onboarding_baby_name'),
          onChanged: (_) => _syncDraft(),
        );
      case OnboardingBabyNameFieldsMode.bornSingleGirl:
        return OnboardingTextField(
          controller: _girlNameController,
          label: l10n.labelGirlSNameOptional,
          hint: l10n.labelEGOlivia,
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PrototypePhotoUpload(
                imageFile: _selectedImage,
                onTap: _busy ? null : _pickPhoto,
              ),
              OnboardingPhotoCaption(
                hasPhoto: _selectedImage != null,
                onTap: _busy ? null : _pickPhoto,
              ),
            ],
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
                l10n.hintSharePhoto,
                style: text.bodyMedium,
              ),
              subtitle: Text(
                l10n.hintDefaultFollowers,
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
          OnboardingHeadline(
            _isReviseOnboarding
                ? "Update your baby's profile"
                : "Create your baby's profile",
          ),
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
          placeholder: l10n.fieldSelectDate,
          onTap: _busy ? () {} : _pickDate,
        ),
        const SizedBox(height: 18),
        const OnboardingFieldLabel('Gender'),
        const SizedBox(height: 8),
        OnboardingPillSelect(
          layout: OnboardingPillLayout.wrap,
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
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: 13,
            ),
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
    final l10n = AppLocalizations.of(context)!;
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
      title: l10n.actionAddBaby,
      body: ListView(
        padding: AppMetrics.subpageFormScrollPadding,
        children: [_buildFormColumn()],
      ),
    );
  }
}
