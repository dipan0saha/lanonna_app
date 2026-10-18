import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/features/calendar/data/models/calendar_models.dart';
import 'package:lanonna/core/time/app_date_time.dart';
import 'package:lanonna/features/calendar/domain/calendar_event_lists.dart';

CalendarEvent _event(String id, DateTime startsAt) {
  return CalendarEvent(
    id: id,
    title: id,
    startsAt: startsAt,
  );
}

void main() {
  final now = DateTime(2026, 10, 12, 15, 0);

  test('past start today appears in today only', () {
    final morning = DateTime(2026, 10, 12, 9, 0);
    final month = [_event('a', morning)];
    final buckets = partitionCalendarListEvents(
      monthEventsForToday: month,
      upcomingFromApi: const [],
      now: now,
    );
    expect(buckets.today.map((e) => e.id), ['a']);
    expect(buckets.upcoming, isEmpty);
  });

  test('tomorrow appears in upcoming only', () {
    final tomorrow = DateTime(2026, 10, 13, 10, 0);
    final upcomingApi = [_event('b', tomorrow)];
    final buckets = partitionCalendarListEvents(
      monthEventsForToday: const [],
      upcomingFromApi: upcomingApi,
      now: now,
    );
    expect(buckets.today, isEmpty);
    expect(buckets.upcoming.map((e) => e.id), ['b']);
  });

  test('later today in API upcoming is not duplicated in upcoming list', () {
    final later = DateTime(2026, 10, 12, 18, 0);
    final month = [_event('c', later)];
    final upcomingApi = [_event('c', later)];
    final buckets = partitionCalendarListEvents(
      monthEventsForToday: month,
      upcomingFromApi: upcomingApi,
      now: now,
    );
    expect(buckets.today.map((e) => e.id), ['c']);
    expect(buckets.upcoming, isEmpty);
  });

  test('local month first day event from offset-aware month fetch', () {
    // Nov 1 2026 01:00 in UTC+11 == Oct 31 14:00 UTC.
    final novFirstLocal = DateTime.utc(2026, 10, 31, 14, 0);
    final anchor = DateTime(2026, 11, 1, 9, 0);
    final month = [_event('edge', novFirstLocal)];
    final buckets = partitionCalendarListEvents(
      monthEventsForToday: month,
      upcomingFromApi: const [],
      now: anchor,
    );
    expect(buckets.today.map((e) => e.id), ['edge']);
  });

  test('calendarMonthKey formats YYYY-MM', () {
    expect(calendarMonthKey(DateTime(2026, 3, 5)), '2026-03');
  });

  test('calendarLocalMonthQueryParams includes offset', () {
    final now = DateTime(2026, 6, 1, 12, 0);
    final params = calendarLocalMonthQueryParams('2026-06', now: now);
    expect(
      params,
      [
        'month=2026-06',
        'utc_offset_minutes=${deviceUtcOffsetMinutes(now)}',
      ],
    );
  });

  test('eventsOnLocalCalendarDay filters and sorts', () {
    final day = DateTime(2026, 10, 12);
    final events = [
      _event('late', DateTime(2026, 10, 12, 18, 0)),
      _event('early', DateTime(2026, 10, 12, 9, 0)),
      _event('other', DateTime(2026, 10, 13, 9, 0)),
    ];
    final onDay = eventsOnLocalCalendarDay(events, day);
    expect(onDay.map((e) => e.id), ['early', 'late']);
  });

  test('isSameLocalCalendarDay ignores time', () {
    expect(
      isSameLocalCalendarDay(
        DateTime(2026, 10, 12, 8),
        DateTime(2026, 10, 12, 20),
      ),
      isTrue,
    );
    expect(
      isSameLocalCalendarDay(
        DateTime(2026, 10, 12),
        DateTime(2026, 10, 13),
      ),
      isFalse,
    );
  });
}
