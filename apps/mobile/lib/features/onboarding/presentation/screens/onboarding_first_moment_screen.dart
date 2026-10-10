import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_error_message.dart';
import '../../../../core/input/app_text_input_kind.dart';
import '../../../gallery/presentation/upload/run_gallery_photo_upload.dart';
import '../../../gallery/domain/gallery_refresh.dart';
import '../../../../core/constants/first_moment_presets.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/create_baby_draft.dart';
import '../../data/onboarding_repository.dart';
import '../../domain/baby_gender.dart';
import '../../domain/baby_lifecycle.dart';
import '../../domain/onboarding_routes.dart';
import '../../domain/onboarding_step.dart';
import '../onboarding_coordinator.dart';
import '../utils/onboarding_back_navigation.dart';
import '../widgets/onboarding_buttons.dart';
import '../widgets/onboarding_prototype_widgets.dart';
import '../widgets/onboarding_scaffold.dart';
import '../widgets/onboarding_typography.dart';

class OnboardingFirstMomentScreen extends StatefulWidget {
  const OnboardingFirstMomentScreen({super.key});

  @override
  State<OnboardingFirstMomentScreen> createState() =>
      _OnboardingFirstMomentScreenState();
}

class _OnboardingFirstMomentScreenState extends State<OnboardingFirstMomentScreen> {
  final _nameInputController = TextEditingController();
  final _picker = ImagePicker();

  var _synced = false;
  var _busy = false;
  var _nameGender = 'male';
  final _nameDrafts = <Map<String, String>>[];
  final _selectedEvents = <String>{};
  final _selectedRegistry = <String>{};
  XFile? _photoFile;
  String? _error;

  BabyLifecycle get _lifecycle {
    final v = context.read<OnboardingCoordinator>().babyLifecycle;
    return v == 'born' ? BabyLifecycle.born : BabyLifecycle.expecting;
  }

  @override
  void dispose() {
    _syncDraft();
    _nameInputController.dispose();
    super.dispose();
  }

  Future<void> _syncDraft() async {
    await context.read<OnboardingCoordinator>().saveFirstMomentDraft(
      FirstMomentDraft(
        selectedEvents: _selectedEvents.toList(),
        selectedRegistry: _selectedRegistry.toList(),
        nameDrafts: List.from(_nameDrafts),
        nameInput: _nameInputController.text,
        nameGender: _nameGender,
        photoPath: _photoFile?.path,
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
      context.read<OnboardingCoordinator>().setStep(OnboardingStep.firstMoment);
      final draft = context.read<OnboardingCoordinator>().firstMomentDraft;
      if (draft != null) {
        _selectedEvents.addAll(draft.selectedEvents);
        _selectedRegistry.addAll(draft.selectedRegistry);
        _nameDrafts.addAll(draft.nameDrafts);
        _nameInputController.text = draft.nameInput;
        _nameGender = draft.nameGender;
        if (draft.photoPath != null) {
          _photoFile = XFile(draft.photoPath!);
        }
        setState(() {});
      }
    });
  }

  void _toggleEvent(String id) {
    setState(() {
      if (_selectedEvents.contains(id)) {
        _selectedEvents.remove(id);
      } else {
        _selectedEvents.add(id);
      }
      _syncDraft();
    });
  }

  void _toggleRegistry(String id) {
    setState(() {
      if (_selectedRegistry.contains(id)) {
        _selectedRegistry.remove(id);
      } else {
        _selectedRegistry.add(id);
      }
      _syncDraft();
    });
  }

  void _addNameIdea() {
    final name = AppTextInputPolicy.normalizeForSubmit(
      AppTextInputKind.personName,
      _nameInputController.text,
    );
    if (name.isEmpty) return;
    setState(() {
      _nameDrafts.add({'name': name, 'gender': _nameGender});
      _nameInputController.clear();
      _syncDraft();
    });
  }

  void _setNameSuggestionGender(BabyGender gender) {
    setState(() {
      _nameGender = gender.apiValue;
      _syncDraft();
    });
  }

  Future<void> _pickPhoto() async {
    final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    setState(() => _photoFile = file);
    await _syncDraft();
  }

  Future<void> _advance({required bool seed}) async {
    await _syncDraft();
    if (!mounted) return;
    final babyId = context.read<OnboardingCoordinator>().createdBabyId;
    if (babyId == null) {
      setState(() => _error = 'Baby profile missing.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = context.read<OnboardingRepository>();
      final api = context.read<ApiClient>();

      if (seed) {
        await repo.seedFirstMoment(
          babyId,
          eventPresetIds: _selectedEvents.toList(),
          registryPresetIds: _selectedRegistry.toList(),
          nameSuggestions: _lifecycle == BabyLifecycle.expecting ? _nameDrafts : const [],
        );
      }

      if (_photoFile != null &&
          _lifecycle == BabyLifecycle.born &&
          !kIsWeb) {
        if (!mounted) return;
        await runGalleryPhotoUpload(
          context: context,
          babyProfileId: babyId,
          imageFile: File(_photoFile!.path),
          api: api,
        );
        if (mounted) notifyGalleryDataChanged(context);
      }

      if (!mounted) return;
      await context.read<OnboardingCoordinator>().setStep(OnboardingStep.batchInvite);
      if (mounted) context.go(OnboardingRoutes.ownerInvite);
    } catch (e) {
      setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _chipRow(List<({String id, String label})> items, Set<String> selected, void Function(String) onToggle) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items
          .map(
            (p) => PrototypePresetChip(
              label: p.label,
              selected: selected.contains(p.id),
              onTap: () => onToggle(p.id),
            ),
          )
          .toList(),
    );
  }

  Widget _nameSuggestionChips() {
    if (_nameDrafts.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _nameDrafts
            .map(
              (d) => Chip(
                label: Text(d['name'] ?? ''),
                onDeleted: () {
                  setState(() {
                    _nameDrafts.remove(d);
                    _syncDraft();
                  });
                },
              ),
            )
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isExpecting = _lifecycle == BabyLifecycle.expecting;
    final events = isExpecting
        ? FirstMomentPresets.expectingEvents
        : FirstMomentPresets.bornEvents;
    final registry = isExpecting
        ? FirstMomentPresets.expectingRegistry
        : FirstMomentPresets.bornRegistry;
    const eventSubtitle = 'AI-suggested by stage and age';
    const registrySubtitle = 'AI-suggested by stage and age';

    return OnboardingScaffold(
      pinBottomCta: false,
      showBack: true,
      onBack: () => goOnboardingBack(
        context,
        step: OnboardingStep.createBaby,
        route: OnboardingRoutes.ownerCreateBaby,
        persist: _syncDraft,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          const OnboardingHeadline(
            'Add your first moment',
            key: Key('onboarding_first_moment_title'),
          ),
          const SizedBox(height: 8),
          const OnboardingSupportText(
            'Totally optional, but it helps family feel like there\'s already something here.',
          ),
          const SizedBox(height: 20),
          if (isExpecting) ...[
            PrototypeMomentCard(
              iconBackground: AppColors.sageTint,
              icon: Icon(Icons.star_outline, size: 17, color: AppColors.primaryDark),
              title: 'Suggest a name',
              subtitle: 'Seeds the vote in Family Fun',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PrototypeMiniGenderToggle(
                    selected: nameSuggestionGenderFromDraft(_nameGender),
                    onSelected: _setNameSuggestionGender,
                  ),
                  const SizedBox(height: 10),
                  PrototypeInlineNameAdd(
                    controller: _nameInputController,
                    onAdd: _addNameIdea,
                  ),
                  _nameSuggestionChips(),
                ],
              ),
            ),
            PrototypeMomentCard(
              iconBackground: AppColors.peachTint,
              icon: Icon(Icons.calendar_today_outlined, size: 17, color: AppColors.secondaryDark),
              title: 'Add a calendar event',
              subtitle: eventSubtitle,
              child: _chipRow(
                events.map((e) => (id: e.id, label: e.label)).toList(),
                _selectedEvents,
                _toggleEvent,
              ),
            ),
            PrototypeMomentCard(
              iconBackground: AppColors.sageTint,
              icon: Icon(Icons.photo_camera_outlined, size: 17, color: AppColors.primaryDark),
              title: 'Add a registry item',
              subtitle: registrySubtitle,
              child: _chipRow(
                registry.map((r) => (id: r.id, label: r.label)).toList(),
                _selectedRegistry,
                _toggleRegistry,
              ),
            ),
          ] else ...[
            PrototypeMomentCard(
              iconBackground: AppColors.peachTint,
              icon: Icon(Icons.photo_camera_outlined, size: 17, color: AppColors.secondaryDark),
              title: 'Upload your first photo',
              subtitle: 'From your camera or library',
              child: Center(
                child: PrototypePhotoUpload(
                  imageFile: _photoFile,
                  onTap: _busy ? null : _pickPhoto,
                  label: _photoFile != null ? 'Change photo' : 'Add a photo',
                ),
              ),
            ),
            PrototypeMomentCard(
              iconBackground: AppColors.sageTint,
              icon: Icon(Icons.photo_camera_outlined, size: 17, color: AppColors.primaryDark),
              title: 'Add a registry item',
              subtitle: registrySubtitle,
              child: _chipRow(
                registry.map((r) => (id: r.id, label: r.label)).toList(),
                _selectedRegistry,
                _toggleRegistry,
              ),
            ),
            PrototypeMomentCard(
              iconBackground: AppColors.peachTint,
              icon: Icon(Icons.calendar_today_outlined, size: 17, color: AppColors.secondaryDark),
              title: 'Add a calendar event',
              subtitle: eventSubtitle,
              child: _chipRow(
                events.map((e) => (id: e.id, label: e.label)).toList(),
                _selectedEvents,
                _toggleEvent,
              ),
            ),
          ],
          const SizedBox(height: 20),
          OnboardingPrimaryButton(
            semanticsId: 'onboarding_first_moment_continue',
            label: 'Continue',
            isLoading: _busy,
            onPressed: _busy ? null : () => _advance(seed: true),
          ),
          const SizedBox(height: 26),
          if (_error != null)
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
      ),
    );
  }
}
