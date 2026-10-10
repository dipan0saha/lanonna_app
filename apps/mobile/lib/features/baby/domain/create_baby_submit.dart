import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_error_message.dart';
import '../../../core/api/display_photo_upload.dart';
import '../../../core/domain/baby_summary.dart';
import '../../gallery/domain/gallery_refresh.dart';
import '../../gallery/presentation/upload/run_gallery_photo_upload.dart';
import '../../home/data/home_repository.dart';
import '../../onboarding/data/onboarding_repository.dart';
import '../../onboarding/domain/baby_gender.dart';
import '../../onboarding/domain/baby_lifecycle.dart';
import '../../onboarding/presentation/onboarding_coordinator.dart';
import '../../onboarding/presentation/utils/onboarding_baby_helpers.dart';
import 'create_baby_mode.dart';

class CreateBabyFormInput {
  const CreateBabyFormInput({
    required this.status,
    required this.gender,
    required this.selectedDate,
    required this.boyName,
    required this.girlName,
    this.selectedImage,
    this.sharePhotoToGallery = false,
  });

  final BabyLifecycle status;
  final BabyGender gender;
  final DateTime? selectedDate;
  final String boyName;
  final String girlName;
  final XFile? selectedImage;
  final bool sharePhotoToGallery;
}

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
  final name = resolveOnboardingBabyName(
    status: input.status,
    gender: input.gender,
    boyName: input.boyName,
    girlName: input.girlName,
  );

  final expected = input.status == BabyLifecycle.expecting && input.selectedDate != null
      ? formatApiDate(input.selectedDate!)
      : null;
  final actual = input.status == BabyLifecycle.born && input.selectedDate != null
      ? formatApiDate(input.selectedDate!)
      : null;

  final profileNameSuggestions = expectingProfileNameSuggestionsForFun(
    status: input.status,
    gender: input.gender,
    boyName: input.boyName,
    girlName: input.girlName,
  );

  final relationshipLabel = await resolveRelationshipLabelForCreateBaby(
    mode: mode,
    coordinator: coordinator,
    homeRepo: homeRepo,
  );

  final baby = await repository.createBaby(
    name: name,
    gender: input.gender.apiValue,
    lifecycleStatus: input.status.apiValue,
    expectedBirthDate: expected,
    actualBirthDate: actual,
    relationshipLabel: relationshipLabel,
    profileNameSuggestions: profileNameSuggestions,
  );

  if (input.selectedImage != null && !kIsWeb) {
    final imageFile = File(input.selectedImage!.path);
    var avatarSaved = false;
    try {
      final avatarUrl = await DisplayPhotoUpload(api).uploadBabyAvatar(
        babyProfileId: baby.id,
        imageFile: imageFile,
      );
      await homeRepo.updateBaby(baby.id, avatarUrl: avatarUrl);
      avatarSaved = true;
    } catch (e) {
      onNonFatalError?.call(
        'Baby created; profile photo failed: ${apiErrorMessage(e)}',
      );
    }
    if (input.sharePhotoToGallery) {
      try {
        if (!context.mounted) return baby;
        await runGalleryPhotoUpload(
          context: context,
          babyProfileId: baby.id,
          imageFile: imageFile,
          api: api,
        );
        if (context.mounted) {
          notifyGalleryDataChanged(context);
        }
      } catch (e) {
        final prefix = avatarSaved
            ? 'Profile photo saved; gallery upload failed'
            : 'Baby created; gallery upload failed';
        onNonFatalError?.call('$prefix: ${apiErrorMessage(e)}');
      }
    }
  }

  return baby;
}
