import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/domain/baby_gender.dart';
import 'package:lanonna/core/domain/baby_summary.dart';
import 'package:lanonna/features/baby/domain/create_baby_form_hydration.dart';
import 'package:lanonna/core/domain/baby_lifecycle.dart';

void main() {
  test('fromBaby maps expecting female name to girl field', () {
    const baby = BabySummary(
      id: '1',
      name: 'Olivia',
      lifecycle: BabyLifecycle.expecting,
      role: 'owner',
      gender: BabyGender.female,
      expectedBirthDate: '2026-12-01',
    );
    final form = CreateBabyFormFromSummary.fromBaby(baby);
    expect(form.lifecycle, BabyLifecycle.expecting);
    expect(form.girlName, 'Olivia');
    expect(form.boyName, isEmpty);
    expect(form.gender, BabyGender.female);
  });

  test('fromBaby leaves both name fields empty for an unnamed baby', () {
    const baby = BabySummary(
      id: '2',
      name: null,
      lifecycle: BabyLifecycle.expecting,
      role: 'owner',
    );
    final form = CreateBabyFormFromSummary.fromBaby(baby);
    expect(form.boyName, isEmpty);
    expect(form.girlName, isEmpty);
    expect(form.gender, BabyGender.unknown);
  });

  test('fromBaby keeps a stored name that happens to be "Baby"', () {
    // The name is data; only `null` means "no name" (L-36).
    const baby = BabySummary(
      id: '3',
      name: 'Baby',
      lifecycle: BabyLifecycle.born,
      role: 'owner',
      gender: BabyGender.male,
      actualBirthDate: '2026-01-01',
    );
    final form = CreateBabyFormFromSummary.fromBaby(baby);
    expect(form.boyName, 'Baby');
    expect(form.girlName, isEmpty);
  });

  test('fromBaby puts a born baby with unknown gender in the boy field', () {
    const baby = BabySummary(
      id: '4',
      name: 'Sam',
      lifecycle: BabyLifecycle.born,
      role: 'owner',
      actualBirthDate: '2026-01-01',
    );
    final form = CreateBabyFormFromSummary.fromBaby(baby);
    expect(form.gender, BabyGender.male);
    expect(form.boyName, 'Sam');
  });
}
