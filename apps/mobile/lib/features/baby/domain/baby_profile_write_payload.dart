import 'package:image_picker/image_picker.dart';

import '../../../core/time/app_date_time.dart';
import 'package:lanonna/core/domain/baby_gender.dart';
import 'package:lanonna/core/domain/baby_lifecycle.dart';
import '../../onboarding/presentation/utils/onboarding_baby_helpers.dart';

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

class BabyProfileWritePayload {
  const BabyProfileWritePayload({
    required this.name,
    required this.gender,
    required this.lifecycle,
    this.expectedBirthDate,
    this.actualBirthDate,
    this.profileNameSuggestions = const [],
  });

  final String name;
  final String? gender;
  final BabyLifecycle lifecycle;
  final String? expectedBirthDate;
  final String? actualBirthDate;
  final List<Map<String, String>> profileNameSuggestions;
}

BabyProfileWritePayload buildBabyProfileWritePayload(CreateBabyFormInput input) {
  final name = resolveOnboardingBabyName(
    status: input.status,
    gender: input.gender,
    boyName: input.boyName,
    girlName: input.girlName,
  );

  final expected = input.status == BabyLifecycle.expecting && input.selectedDate != null
      ? toApiCalendarDate(input.selectedDate!)
      : null;
  final actual = input.status == BabyLifecycle.born && input.selectedDate != null
      ? toApiCalendarDate(input.selectedDate!)
      : null;

  final profileNameSuggestions = expectingProfileNameSuggestionsForFun(
    status: input.status,
    gender: input.gender,
    boyName: input.boyName,
    girlName: input.girlName,
  );

  return BabyProfileWritePayload(
    name: name,
    gender: input.gender.apiValue,
    lifecycle: input.status,
    expectedBirthDate: expected,
    actualBirthDate: actual,
    profileNameSuggestions: profileNameSuggestions,
  );
}
