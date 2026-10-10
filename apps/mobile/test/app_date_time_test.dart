import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/time/app_date_time.dart';

void main() {
  group('parseApiInstant', () {
    test('converts Zulu instant to local wall time', () {
      final local = parseApiInstant('2026-10-21T01:22:00.000Z');
      final expected = DateTime.parse('2026-10-21T01:22:00.000Z').toLocal();
      expect(local, expected);
    });
  });

  group('formatEventDetailWhen', () {
    test('uses local calendar day not UTC fields', () {
      final utcInstant = DateTime.parse('2026-10-21T01:22:00.000Z');
      final local = utcInstant.toLocal();
      final formatted = formatEventDetailWhen(utcInstant, 'en_US');
      expect(formatted, contains('${local.day}'));
      expect(formatted, contains('${local.year}'));
    });
  });

  group('formatEventListDateTime', () {
    test('matches local day for evening US-style instant', () {
      final instant = DateTime.parse('2026-10-21T01:22:00.000Z');
      final local = instant.toLocal();
      final formatted = formatEventListDateTime(instant, 'en_US');
      expect(formatted, contains('${local.day}'));
    });
  });

  group('toApiCalendarDate', () {
    test('serializes calendar day as YYYY-MM-DD', () {
      expect(toApiCalendarDate(DateTime(1990, 4, 12)), '1990-04-12');
    });
  });

  group('formatApiCalendarDate', () {
    test('formats YYYY-MM-DD for display', () {
      final formatted = formatApiCalendarDate('2027-02-01', 'en_US');
      expect(formatted, contains('2027'));
      expect(formatted, isNot(contains('2027-02-01')));
    });

    test('returns empty for invalid input', () {
      expect(formatApiCalendarDate(null), '');
      expect(formatApiCalendarDate(''), '');
      expect(formatApiCalendarDate('not-a-date'), '');
    });

    test('date-only YYYY-MM-DD uses calendar day not timezone shift', () {
      final parsed = tryParseApiCalendarDate('2027-02-01');
      expect(parsed, DateTime.utc(2027, 2, 1));
      final formatted = formatApiCalendarDate('2027-02-01', 'en_US');
      expect(formatted, contains('February'));
      expect(formatted, contains('1'));
      expect(formatted, contains('2027'));
    });
  });

  group('home badge', () {
    test('day and month use local date', () {
      final instant = DateTime.parse('2026-10-21T01:22:00.000Z');
      final local = instant.toLocal();
      expect(formatEventDayBadge(instant), local.day);
      expect(
        formatEventMonthBadge(instant, 'en_US').toLowerCase(),
        isNot(contains('invalid')),
      );
    });
  });
}
