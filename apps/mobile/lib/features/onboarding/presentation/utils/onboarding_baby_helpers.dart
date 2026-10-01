import '../../domain/baby_gender.dart';
import '../../domain/baby_lifecycle.dart';

enum OnboardingBabyNameFieldsMode {
  expectingBoth,
  bornSingleBoy,
  bornSingleGirl,
}

OnboardingBabyNameFieldsMode onboardingBabyNameFieldsMode({
  required BabyLifecycle status,
  required BabyGender gender,
}) {
  if (status == BabyLifecycle.expecting && gender == BabyGender.unknown) {
    return OnboardingBabyNameFieldsMode.expectingBoth;
  }
  if (gender == BabyGender.female) {
    return OnboardingBabyNameFieldsMode.bornSingleGirl;
  }
  if (gender == BabyGender.male) {
    return OnboardingBabyNameFieldsMode.bornSingleBoy;
  }
  return OnboardingBabyNameFieldsMode.expectingBoth;
}

DateTime onboardingDateAtMidnight(DateTime date) =>
    DateTime(date.year, date.month, date.day);

bool onboardingBirthDateIsInFuture(DateTime date) {
  final today = onboardingDateAtMidnight(DateTime.now());
  return onboardingDateAtMidnight(date).isAfter(today);
}

bool onboardingDueDateIsBeforeToday(DateTime date) {
  final today = onboardingDateAtMidnight(DateTime.now());
  return onboardingDateAtMidnight(date).isBefore(today);
}

DateTime? onboardingSanitizeExpectingDueDate(DateTime? date) {
  if (date == null) return null;
  if (onboardingDueDateIsBeforeToday(date)) return null;
  return date;
}

DateTime onboardingExpectingDatePickerInitial(DateTime? selected, DateTime now) {
  final today = onboardingDateAtMidnight(now);
  if (selected == null) return today.add(const Duration(days: 90));
  final picked = onboardingDateAtMidnight(selected);
  if (picked.isBefore(today)) return today;
  return selected;
}

DateTime? onboardingSanitizeBornBirthDate(DateTime? date) {
  if (date == null) return null;
  if (onboardingBirthDateIsInFuture(date)) return null;
  return date;
}

DateTime onboardingBornDatePickerInitial(DateTime? selected, DateTime now) {
  final today = onboardingDateAtMidnight(now);
  if (selected == null) return today;
  final picked = onboardingDateAtMidnight(selected);
  if (picked.isAfter(today)) return today;
  return selected;
}

bool onboardingShowsUnsureGenderPill(BabyLifecycle status) =>
    status == BabyLifecycle.expecting;

String resolveOnboardingBabyName({
  required BabyLifecycle status,
  required BabyGender gender,
  String? boyName,
  String? girlName,
  String? bornName,
}) {
  final boy = boyName?.trim() ?? '';
  final girl = girlName?.trim() ?? '';
  final single = bornName?.trim() ?? '';

  if (status == BabyLifecycle.born) {
    if (single.isNotEmpty) return single;
    if (gender == BabyGender.female && girl.isNotEmpty) return girl;
    if (boy.isNotEmpty) return boy;
    if (girl.isNotEmpty) return girl;
    return 'Baby';
  }

  if (boy.isNotEmpty && girl.isEmpty) return boy;
  if (girl.isNotEmpty && boy.isEmpty) return girl;
  if (boy.isNotEmpty) return boy;
  if (girl.isNotEmpty) return girl;
  return 'Baby';
}

String formatApiDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
