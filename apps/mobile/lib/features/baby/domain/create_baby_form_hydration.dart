import '../../../core/domain/baby_summary.dart';
import '../../../core/time/app_date_time.dart';
import 'package:lanonna/core/domain/baby_gender.dart';
import 'package:lanonna/core/domain/baby_lifecycle.dart';
import '../../onboarding/presentation/utils/onboarding_baby_helpers.dart';

/// Maps server baby into onboarding create-baby form state when local draft is absent.
class CreateBabyFormFromSummary {
  const CreateBabyFormFromSummary({
    required this.lifecycle,
    required this.gender,
    this.selectedDate,
    this.boyName = '',
    this.girlName = '',
  });

  final BabyLifecycle lifecycle;
  final BabyGender gender;
  final DateTime? selectedDate;
  final String boyName;
  final String girlName;

  factory CreateBabyFormFromSummary.fromBaby(BabySummary baby) {
    final lifecycle = baby.isBorn
        ? BabyLifecycle.born
        : BabyLifecycle.expecting;
    var gender = baby.gender;
    if (lifecycle == BabyLifecycle.born && gender == BabyGender.unknown) {
      gender = BabyGender.male;
    }

    DateTime? selectedDate;
    final raw = lifecycle == BabyLifecycle.born
        ? baby.actualBirthDate
        : baby.expectedBirthDate;
    if (raw != null) {
      selectedDate = tryParseApiCalendarDate(raw);
      if (lifecycle == BabyLifecycle.expecting) {
        selectedDate = onboardingSanitizeExpectingDueDate(selectedDate);
      } else {
        selectedDate = onboardingSanitizeBornBirthDate(selectedDate);
      }
    }

    // The stored name goes back into the field the form shows for this
    // gender; an unnamed baby (`null`) leaves both fields empty.
    final name = baby.name?.trim() ?? '';
    final girlName = gender == BabyGender.female ? name : '';
    final boyName = gender == BabyGender.female ? '' : name;

    return CreateBabyFormFromSummary(
      lifecycle: lifecycle,
      gender: gender,
      selectedDate: selectedDate,
      boyName: boyName,
      girlName: girlName,
    );
  }
}
