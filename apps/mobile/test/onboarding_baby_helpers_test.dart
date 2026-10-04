import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/features/onboarding/domain/baby_gender.dart';
import 'package:lanonna/features/onboarding/domain/baby_lifecycle.dart';
import 'package:lanonna/features/onboarding/presentation/utils/onboarding_baby_helpers.dart';

void main() {
  test('resolveOnboardingBabyName uses Baby when empty', () {
    expect(
      resolveOnboardingBabyName(
        status: BabyLifecycle.expecting,
        gender: BabyGender.unknown,
      ),
      'Baby',
    );
  });

  test('expecting due date helpers reject past dates', () {
    final now = DateTime(2026, 9, 29, 15, 30);
    final past = DateTime(2025, 12, 10);
    expect(onboardingDueDateIsBeforeToday(past), isTrue);
    expect(onboardingSanitizeExpectingDueDate(past), isNull);
    expect(
      onboardingExpectingDatePickerInitial(past, now),
      DateTime(2026, 9, 29),
    );
    expect(
      onboardingExpectingDatePickerInitial(DateTime(2026, 10, 1), now),
      DateTime(2026, 10, 1),
    );
  });

  test('expectingProfileNameSuggestionsForFun maps boy and girl fields', () {
    final suggestions = expectingProfileNameSuggestionsForFun(
      status: BabyLifecycle.expecting,
      gender: BabyGender.unknown,
      boyName: 'Liam',
      girlName: 'Olivia',
    );
    expect(suggestions, [
      {'name': 'Liam', 'gender': 'male'},
      {'name': 'Olivia', 'gender': 'female'},
    ]);
  });

  test('expectingProfileNameSuggestionsForFun dedupes same name', () {
    final suggestions = expectingProfileNameSuggestionsForFun(
      status: BabyLifecycle.expecting,
      gender: BabyGender.unknown,
      boyName: 'Sky',
      girlName: 'sky',
    );
    expect(suggestions.length, 1);
    expect(suggestions.first['name'], 'Sky');
  });

  test('expectingProfileNameSuggestionsForFun empty when born', () {
    expect(
      expectingProfileNameSuggestionsForFun(
        status: BabyLifecycle.born,
        gender: BabyGender.male,
        boyName: 'Leo',
        girlName: '',
      ),
      isEmpty,
    );
  });

  test('resolveOnboardingBabyName prefers boy name', () {
    expect(
      resolveOnboardingBabyName(
        status: BabyLifecycle.expecting,
        gender: BabyGender.unknown,
        boyName: 'Liam',
        girlName: 'Olivia',
      ),
      'Liam',
    );
  });
}
