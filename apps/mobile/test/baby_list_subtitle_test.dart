import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:lanonna/core/domain/baby_lifecycle.dart';
import 'package:lanonna/core/domain/baby_list_subtitle.dart';
import 'package:lanonna/core/domain/baby_summary.dart';
import 'package:lanonna/core/time/app_date_time.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  test('babyListSubtitle prefixes relationship label', () {
    const baby = BabySummary(
      id: '1',
      name: 'Baby',
      lifecycle: BabyLifecycle.expecting,
      role: 'owner',
      expectedBirthDate: '2026-12-01',
      relationshipLabel: 'Mother',
    );
    final due = formatApiCalendarDate('2026-12-01', 'en_US');
    expect(babyListSubtitle(l10n, baby, 'en_US'), 'Mother · Due $due');
  });

  test('babyListSubtitle omits empty relationship label', () {
    const baby = BabySummary(
      id: '1',
      name: 'Baby',
      lifecycle: BabyLifecycle.expecting,
      role: 'follower',
      expectedBirthDate: '2026-12-01',
    );
    final due = formatApiCalendarDate('2026-12-01', 'en_US');
    expect(babyListSubtitle(l10n, baby, 'en_US'), 'Due $due');
  });

  test('babyLifecycleSubtitle falls back to lifecycle label without a date', () {
    const baby = BabySummary(
      id: '1',
      name: 'Baby',
      lifecycle: BabyLifecycle.born,
      role: 'owner',
    );
    expect(babyLifecycleSubtitle(l10n, baby), l10n.lifecycleBorn);
  });
}
