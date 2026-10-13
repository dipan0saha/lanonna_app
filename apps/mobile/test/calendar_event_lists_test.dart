import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/features/calendar/data/models/calendar_models.dart';
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
    final partition = partitionCalendarListEvents(
      monthEventsForToday: month,
      upcomingFromApi: const [],
      now: now,
    );
    expect(partition.today.map((e) => e.id), ['a']);
    expect(partition.upcoming, isEmpty);
  });

  test('tomorrow appears in upcoming only', () {
    final tomorrow = DateTime(2026, 10, 13, 10, 0);
    final upcomingApi = [_event('b', tomorrow)];
    final partition = partitionCalendarListEvents(
      monthEventsForToday: const [],
      upcomingFromApi: upcomingApi,
      now: now,
    );
    expect(partition.today, isEmpty);
    expect(partition.upcoming.map((e) => e.id), ['b']);
  });

  test('later today in API upcoming is not duplicated in upcoming list', () {
    final later = DateTime(2026, 10, 12, 18, 0);
    final month = [_event('c', later)];
    final upcomingApi = [_event('c', later)];
    final partition = partitionCalendarListEvents(
      monthEventsForToday: month,
      upcomingFromApi: upcomingApi,
      now: now,
    );
    expect(partition.today.map((e) => e.id), ['c']);
    expect(partition.upcoming, isEmpty);
  });

  test('calendarMonthKey formats YYYY-MM', () {
    expect(calendarMonthKey(DateTime(2026, 3, 5)), '2026-03');
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
