import 'dart:io';
import 'package:lanonna/l10n/app_localizations.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_error_message.dart';
import '../../../core/api/display_photo_upload.dart';
import '../../../core/domain/baby_summary.dart';
import '../../gallery/domain/gallery_refresh.dart';
import '../../gallery/presentation/upload/run_gallery_photo_upload.dart';
import '../../home/data/home_repository.dart';
import '../../onboarding/data/onboarding_repository.dart';
import 'package:lanonna/core/domain/baby_lifecycle.dart';
import '../../onboarding/presentation/onboarding_coordinator.dart';
import 'baby_profile_write_payload.dart';
import 'create_baby_mode.dart';
import 'owner_onboarding_baby_phase.dart';

export 'baby_profile_write_payload.dart' show CreateBabyFormInput;

Future<String?> resolveRelationshipLabelForCreateBaby({
  required CreateBabyMode mode,
  required OnboardingCoordinator coordinator,
  required HomeRepository homeRepo,
}) async {
  if (mode == CreateBabyMode.onboarding) {
    return coordinator.completeProfileDraft?.relationshipLabel;
  }
  final babies = await homeRepo.listBabies();
  for (final baby in babies) {
    final label = baby.relationshipLabel?.trim();
    if (baby.role == 'owner' && label != null && label.isNotEmpty) {
      return label;
    }
  }
  return coordinator.completeProfileDraft?.relationshipLabel;
}

Future<void> _applyAvatarAndGallery({
  required BuildContext context,
  required String babyProfileId,
  required CreateBabyFormInput input,
  required ApiClient api,
  required HomeRepository homeRepo,
  required bool isCreate,
  void Function(String message)? onNonFatalError,
}) async {
  if (input.selectedImage == null || kIsWeb) return;

  final imageFile = File(input.selectedImage!.path);
  var avatarSaved = false;
  final createdLabel = isCreate ? AppLocalizations.of(context)!.babyBabyCreated : AppLocalizations.of(context)!.babyBabyUpdated;
  try {
    final avatarUrl = await DisplayPhotoUpload(api).uploadBabyAvatar(
      babyProfileId: babyProfileId,
      imageFile: imageFile,
    );
    await homeRepo.updateBaby(babyProfileId, avatarUrl: avatarUrl);
    avatarSaved = true;
  } catch (e) {
    onNonFatalError?.call(
      AppLocalizations.of(context)!.babyProfilePhotoFailed(createdLabel, apiErrorMessage(AppLocalizations.of(context)!, e)),
    );
  }
  if (input.sharePhotoToGallery) {
    try {
      if (!context.mounted) return;
      await runGalleryPhotoUpload(
        context: context,
        babyProfileId: babyProfileId,
        imageFile: imageFile,
        api: api,
      );
      if (context.mounted) {
        notifyGalleryDataChanged(context);
      }
    } catch (e) {
      final prefix = avatarSaved
          ? AppLocalizations.of(context)!.babyProfilePhotoSavedGalleryUpload
          : AppLocalizations.of(context)!.babyGalleryUploadFailed(createdLabel);
      onNonFatalError?.call('$prefix: ${apiErrorMessage(AppLocalizations.of(context)!, e)}');
    }
  }
}

/// Creates baby profile, optional avatar, optional gallery share. Caller handles navigation.
Future<BabySummary> submitCreateBaby({
  required BuildContext context,
  required CreateBabyMode mode,
  required CreateBabyFormInput input,
  required OnboardingRepository repository,
  required HomeRepository homeRepo,
  required ApiClient api,
  required OnboardingCoordinator coordinator,
  void Function(String message)? onNonFatalError,
}) async {
  final payload = buildBabyProfileWritePayload(
    input,
    fallbackName: AppLocalizations.of(context)!.babyNameDefault,
  );

  final relationshipLabel = await resolveRelationshipLabelForCreateBaby(
    mode: mode,
    coordinator: coordinator,
    homeRepo: homeRepo,
  );

  final baby = await repository.createBaby(
    name: payload.name,
    gender: payload.gender,
    lifecycle: payload.lifecycle,
    expectedBirthDate: payload.expectedBirthDate,
    actualBirthDate: payload.actualBirthDate,
    relationshipLabel: relationshipLabel,
    profileNameSuggestions: payload.profileNameSuggestions,
  );

  await _applyAvatarAndGallery(
    context: context,
    babyProfileId: baby.id,
    input: input,
    api: api,
    homeRepo: homeRepo,
    isCreate: true,
    onNonFatalError: onNonFatalError,
  );

  return baby;
}

Future<BabySummary> submitReviseOwnerOnboardingBaby({
  required BuildContext context,
  required String babyId,
  required CreateBabyFormInput input,
  required HomeRepository homeRepo,
  required ApiClient api,
  void Function(String message)? onNonFatalError,
}) async {
  final payload = buildBabyProfileWritePayload(
    input,
    fallbackName: AppLocalizations.of(context)!.babyNameDefault,
  );
  final isBorn = input.status == BabyLifecycle.born;

  final baby = await homeRepo.updateBaby(
    babyId,
    name: payload.name,
    gender: payload.gender,
    lifecycle: payload.lifecycle,
    expectedBirthDate: isBorn ? null : payload.expectedBirthDate,
    actualBirthDate: isBorn ? payload.actualBirthDate : null,
    profileNameSuggestions: payload.profileNameSuggestions,
  );

  await _applyAvatarAndGallery(
    context: context,
    babyProfileId: baby.id,
    input: input,
    api: api,
    homeRepo: homeRepo,
    isCreate: false,
    onNonFatalError: onNonFatalError,
  );

  return baby;
}

/// Owner onboarding create or revise (no duplicate POST when baby id exists).
Future<BabySummary> submitOwnerOnboardingBaby({
  required BuildContext context,
  required CreateBabyFormInput input,
  required OnboardingRepository repository,
  required HomeRepository homeRepo,
  required ApiClient api,
  required OnboardingCoordinator coordinator,
  void Function(String message)? onNonFatalError,
}) async {
  final phase = ownerOnboardingBabyPhaseFor(coordinator);
  if (phase == OwnerOnboardingBabyPhase.revise) {
    final babyId = coordinator.createdBabyId;
    if (babyId == null || babyId.isEmpty) {
      throw StateError('Revise phase requires createdBabyId');
    }
    return submitReviseOwnerOnboardingBaby(
      context: context,
      babyId: babyId,
      input: input,
      homeRepo: homeRepo,
      api: api,
      onNonFatalError: onNonFatalError,
    );
  }
  return submitCreateBaby(
    context: context,
    mode: CreateBabyMode.onboarding,
    input: input,
    repository: repository,
    homeRepo: homeRepo,
    api: api,
    coordinator: coordinator,
    onNonFatalError: onNonFatalError,
  );
}
