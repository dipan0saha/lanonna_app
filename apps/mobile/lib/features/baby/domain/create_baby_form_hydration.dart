import '../../../core/domain/baby_summary.dart';
import '../../../core/time/app_date_time.dart';
import '../../onboarding/domain/baby_lifecycle.dart';
import '../../onboarding/presentation/utils/onboarding_baby_helpers.dart';

const _genderBoy = 'Boy';
const _genderGirl = 'Girl';
const _genderUnsure = 'Not sure yet';

String genderPillFromApi(String? gender) {
  switch (gender) {
    case 'female':
      return _genderGirl;
    case 'male':
      return _genderBoy;
    default:
      return _genderUnsure;
  }
}

/// Maps server baby into onboarding create-baby form state when local draft is absent.
class CreateBabyFormFromSummary {
  const CreateBabyFormFromSummary({
    required this.lifecycle,
    required this.genderPill,
    this.selectedDate,
    this.boyName = '',
    this.girlName = '',
  });

  final BabyLifecycle lifecycle;
  final String genderPill;
  final DateTime? selectedDate;
  final String boyName;
  final String girlName;

  factory CreateBabyFormFromSummary.fromBaby(BabySummary baby) {
    final lifecycle = baby.isBorn
        ? BabyLifecycle.born
        : BabyLifecycle.expecting;
    var genderPill = genderPillFromApi(baby.gender);
    if (lifecycle == BabyLifecycle.born && genderPill == _genderUnsure) {
      genderPill = _genderBoy;
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

    var boyName = '';
    var girlName = '';
    final name = baby.name.trim();
    if (name.isNotEmpty && name != 'Baby') {
      switch (baby.gender) {
        case 'female':
          girlName = name;
          break;
        case 'male':
          boyName = name;
          break;
        default:
          boyName = name;
      }
    }

    return CreateBabyFormFromSummary(
      lifecycle: lifecycle,
      genderPill: genderPill,
      selectedDate: selectedDate,
      boyName: boyName,
      girlName: girlName,
    );
  }
}
