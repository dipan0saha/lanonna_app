import '../../../core/time/app_date_time.dart';
import '../data/models/calendar_models.dart';

class CalendarListPartition {
  const CalendarListPartition({
    required this.today,
    required this.upcoming,
  });

  final List<CalendarEvent> today;
  final List<CalendarEvent> upcoming;
}

/// Splits month + API upcoming lists for Calendar tab and view-all screen.
///
/// [monthEventsForToday] should be events from the **current** local month fetch.
/// [upcomingFromApi] is `GET …/events?upcoming=true` (future instants only).
CalendarListPartition partitionCalendarListEvents({
  required List<CalendarEvent> monthEventsForToday,
  required List<CalendarEvent> upcomingFromApi,
  DateTime? now,
}) {
  final anchor = now ?? DateTime.now();
  final today = monthEventsForToday
      .where((e) => eventOnLocalCalendarDay(e.startsAt, anchor))
      .toList()
    ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  final upcoming = upcomingFromApi
      .where((e) => !eventOnLocalCalendarDay(e.startsAt, anchor))
      .toList()
    ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  return CalendarListPartition(today: today, upcoming: upcoming);
}

String calendarMonthKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}';

bool isSameLocalCalendarDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

List<CalendarEvent> eventsOnLocalCalendarDay(
  List<CalendarEvent> monthEvents,
  DateTime day,
) {
  return monthEvents
      .where((e) => eventOnLocalCalendarDay(e.startsAt, day))
      .toList()
    ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
}
