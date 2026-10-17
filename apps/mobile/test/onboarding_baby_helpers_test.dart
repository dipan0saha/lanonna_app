import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/domain/baby_gender.dart';
import 'package:lanonna/core/domain/baby_lifecycle.dart';
import 'package:lanonna/core/domain/relationship_preset.dart';
import 'package:lanonna/features/baby/domain/baby_name_resolution.dart';
import 'package:lanonna/features/onboarding/presentation/utils/onboarding_baby_helpers.dart';

final _parentSmith = BabyNameParentContext(
  ownerLastName: 'Smith',
  relationshipLabel: RelationshipPreset.father.membershipLabel,
);

void main() {
  test('profileLastNameFromDisplayName splits on whitespace', () {
    expect(profileLastNameFromDisplayName('John Smith'), 'Smith');
    expect(
      profileLastNameFromDisplayName('Mary Anne van der Berg'),
      'Anne van der Berg',
    );
    expect(profileLastNameFromDisplayName('Madonna'), isNull);
    expect(profileLastNameFromDisplayName(''), isNull);
  });

  test('resolveOnboardingBabyName is null when no name was entered', () {
    // The display fallback ("Baby") is never stored (L-36).
    expect(
      resolveOnboardingBabyName(
        status: BabyLifecycle.expecting,
        gender: BabyGender.unknown,
        boyName: '  ',
      ),
      isNull,
    );
  });

  test('resolveOnboardingBabyName prefers the girl field for a born girl', () {
    expect(
      resolveOnboardingBabyName(
        status: BabyLifecycle.born,
        gender: BabyGender.female,
        boyName: 'Leo',
        girlName: 'Mia',
      ),
      'Mia',
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
    expect(suggestions.map((s) => s.toJson()), [
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
    expect(suggestions.first.name, 'Sky');
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

  test('resolveOnboardingBabyName #316 both tentative names use owner surname', () {
    expect(
      resolveOnboardingBabyName(
        status: BabyLifecycle.expecting,
        gender: BabyGender.unknown,
        boyName: 'Liam',
        girlName: 'Olivia',
        parentContext: _parentSmith,
      ),
      'Smith',
    );
    expect(
      resolveOnboardingBabyName(
        status: BabyLifecycle.expecting,
        gender: BabyGender.unknown,
        boyName: 'Liam',
        girlName: 'Olivia',
        parentContext: BabyNameParentContext(
          ownerLastName: 'Smith',
          relationshipLabel: RelationshipPreset.mother.membershipLabel,
        ),
      ),
      'Smith',
    );
  });

  test('resolveOnboardingBabyName boy or girl only when expecting unsure', () {
    expect(
      resolveOnboardingBabyName(
        status: BabyLifecycle.expecting,
        gender: BabyGender.unknown,
        boyName: 'Liam',
        girlName: '',
      ),
      'Liam',
    );
    expect(
      resolveOnboardingBabyName(
        status: BabyLifecycle.expecting,
        gender: BabyGender.unknown,
        boyName: '',
        girlName: 'Olivia',
      ),
      'Olivia',
    );
  });

  test('resolveOnboardingBabyName both names without parent context is null', () {
    expect(
      resolveOnboardingBabyName(
        status: BabyLifecycle.expecting,
        gender: BabyGender.unknown,
        boyName: 'Liam',
        girlName: 'Olivia',
      ),
      isNull,
    );
  });

  test('resolveOnboardingBabyName both names unknown relationship is null', () {
    expect(
      resolveOnboardingBabyName(
        status: BabyLifecycle.expecting,
        gender: BabyGender.unknown,
        boyName: 'Liam',
        girlName: 'Olivia',
        parentContext: const BabyNameParentContext(
          ownerLastName: 'Smith',
          relationshipLabel: 'Aunt',
        ),
      ),
      isNull,
    );
  });

  test('resolveOnboardingBabyName expecting known gender uses single field', () {
    expect(
      resolveOnboardingBabyName(
        status: BabyLifecycle.expecting,
        gender: BabyGender.male,
        boyName: 'Liam',
        girlName: 'Olivia',
      ),
      'Liam',
    );
  });
}
