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
      gender: 'female',
      expectedBirthDate: '2026-12-01',
    );
    final form = CreateBabyFormFromSummary.fromBaby(baby);
    expect(form.lifecycle, BabyLifecycle.expecting);
    expect(form.girlName, 'Olivia');
    expect(form.boyName, isEmpty);
    expect(form.gender, BabyGender.female);
  });
}
