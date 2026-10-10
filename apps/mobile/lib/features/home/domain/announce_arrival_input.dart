import '../../../core/time/app_date_time.dart';
import '../../onboarding/presentation/utils/onboarding_baby_helpers.dart';

export '../../onboarding/presentation/utils/onboarding_baby_helpers.dart'
    show onboardingDateAtMidnight, onboardingBirthDateIsInFuture;

String formatApiBirthDate(DateTime date) =>
    toApiCalendarDate(onboardingDateAtMidnight(date));

bool birthDateValidForAnnounce(DateTime date) {
  return !onboardingBirthDateIsInFuture(date);
}
