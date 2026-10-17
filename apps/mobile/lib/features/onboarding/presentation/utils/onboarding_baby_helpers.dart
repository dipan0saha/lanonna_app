import '../../../../core/input/app_text_input_kind.dart';
import 'package:lanonna/core/domain/baby_gender.dart';
import 'package:lanonna/core/domain/baby_lifecycle.dart';
import 'package:lanonna/core/domain/name_suggestion_draft.dart';

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

/// Fun name suggestions from expecting create-baby optional name fields (#400).
List<NameSuggestionDraft> expectingProfileNameSuggestionsForFun({
  required BabyLifecycle status,
  required BabyGender gender,
  required String boyName,
  required String girlName,
}) {
  if (status != BabyLifecycle.expecting) return const [];

  final seen = <String>{};
  final out = <NameSuggestionDraft>[];

  void add(String raw, BabyGender nameGender) {
    final normalized = AppTextInputPolicy.normalizeForSubmit(
      AppTextInputKind.personName,
      raw,
    );
    if (normalized.isEmpty) return;
    final key = normalized.toLowerCase();
    if (seen.contains(key)) return;
    seen.add(key);
    out.add(NameSuggestionDraft(name: normalized, gender: nameGender));
  }

  switch (onboardingBabyNameFieldsMode(status: status, gender: gender)) {
    case OnboardingBabyNameFieldsMode.expectingBoth:
      add(boyName, BabyGender.male);
      add(girlName, BabyGender.female);
    case OnboardingBabyNameFieldsMode.bornSingleBoy:
      add(boyName, BabyGender.male);
    case OnboardingBabyNameFieldsMode.bornSingleGirl:
      add(girlName, BabyGender.female);
  }
  return out;
}

/// Name to store for the baby profile from the create-baby name fields, or
/// `null` when the owner has not entered one. The fallback ("Baby") is a
/// display concern (`babyNameLabel`) and is never stored.
String? resolveOnboardingBabyName({
  required BabyLifecycle status,
  required BabyGender gender,
  String? boyName,
  String? girlName,
}) {
  final boy = AppTextInputPolicy.normalizeForSubmit(
    AppTextInputKind.personName,
    boyName ?? '',
  );
  final girl = AppTextInputPolicy.normalizeForSubmit(
    AppTextInputKind.personName,
    girlName ?? '',
  );

  final preferGirl = status == BabyLifecycle.born && gender == BabyGender.female;
  final first = preferGirl ? girl : boy;
  final second = preferGirl ? boy : girl;
  if (first.isNotEmpty) return first;
  if (second.isNotEmpty) return second;
  return null;
}
