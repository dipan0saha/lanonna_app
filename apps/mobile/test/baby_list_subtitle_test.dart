import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/domain/baby_list_subtitle.dart';
import 'package:lanonna/core/domain/baby_summary.dart';
import 'package:lanonna/core/time/app_date_time.dart';

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
    final due = formatApiCalendarDate('2026-12-01', 'en_US');
    expect(babyListSubtitle(baby, 'en_US'), 'Mother · Due $due');
  });

  test('babyListSubtitle omits empty relationship label', () {
    const baby = BabySummary(
      id: '1',
      name: 'Baby',
      lifecycleStatus: 'expecting',
      role: 'follower',
      expectedBirthDate: '2026-12-01',
    );
    final due = formatApiCalendarDate('2026-12-01', 'en_US');
    expect(babyListSubtitle(baby, 'en_US'), 'Due $due');
  });
}
