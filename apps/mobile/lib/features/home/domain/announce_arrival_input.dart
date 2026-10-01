import '../../onboarding/presentation/utils/onboarding_baby_helpers.dart';

export '../../onboarding/presentation/utils/onboarding_baby_helpers.dart'
    show onboardingDateAtMidnight, onboardingBirthDateIsInFuture;

String formatApiBirthDate(DateTime date) {
  final d = onboardingDateAtMidnight(date);
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

bool birthDateValidForAnnounce(DateTime date) {
  return !onboardingBirthDateIsInFuture(date);
}
