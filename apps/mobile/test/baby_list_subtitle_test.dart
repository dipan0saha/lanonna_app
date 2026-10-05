import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/domain/baby_list_subtitle.dart';
import 'package:lanonna/core/domain/baby_summary.dart';

void main() {
  test('babyListSubtitle prefixes relationship label', () {
    const baby = BabySummary(
      id: '1',
      name: 'Baby',
      lifecycleStatus: 'expecting',
      role: 'owner',
      expectedBirthDate: '2026-12-01',
      relationshipLabel: 'Mother',
    );
    expect(babyListSubtitle(baby), 'Mother · Due 2026-12-01');
  });

  test('babyListSubtitle omits empty relationship label', () {
    const baby = BabySummary(
      id: '1',
      name: 'Baby',
      lifecycleStatus: 'expecting',
      role: 'follower',
      expectedBirthDate: '2026-12-01',
    );
    expect(babyListSubtitle(baby), 'Due 2026-12-01');
  });
}
