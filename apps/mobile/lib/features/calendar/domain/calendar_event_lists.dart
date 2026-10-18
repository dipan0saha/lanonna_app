import '../../../core/time/app_date_time.dart';
import '../data/models/calendar_models.dart';

/// Today vs later-day buckets for Calendar tab and view-all list.
class CalendarEventBuckets {
  const CalendarEventBuckets({
    required this.today,
    required this.upcoming,
  });

  final List<CalendarEvent> today;
  final List<CalendarEvent> upcoming;

  bool get isEmpty => today.isEmpty && upcoming.isEmpty;
}

/// Splits month + API upcoming lists for Calendar tab and view-all screen.
///
/// [monthEventsForToday] should be events from the **current** local month fetch
/// (bounds from [calendarLocalMonthQueryParams]).
/// [upcomingFromApi] is `GET …/events?upcoming=true` (future instants only).
/// Today holds every event starting on the local day (including ones already
/// started); Upcoming holds later days only, so nothing is listed twice.
CalendarEventBuckets partitionCalendarListEvents({
  required List<CalendarEvent> monthEventsForToday,
  required List<CalendarEvent> upcomingFromApi,
  DateTime? now,
}) {
  final anchor = now ?? DateTime.now();
  int byStart(CalendarEvent a, CalendarEvent b) =>
      a.startsAt.compareTo(b.startsAt);
  // Today = every event starting on the local day: earlier ones come from the
  // month list, later ones from either list (deduped by id), so a later-today
  // event never disappears when one list is stale.
  final todayById = <String, CalendarEvent>{
    for (final e in [...monthEventsForToday, ...upcomingFromApi])
      if (eventOnLocalCalendarDay(e.startsAt, anchor)) e.id: e,
  };
  final today = todayById.values.toList()..sort(byStart);
  final upcoming = upcomingFromApi
      .where((e) => !eventOnLocalCalendarDay(e.startsAt, anchor))
      .toList()
    ..sort(byStart);
  return CalendarEventBuckets(today: today, upcoming: upcoming);
}

String calendarMonthKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}';

/// Query params for a device-local calendar month list: the UTC instants of
/// local midnight on the 1st and on the 1st of the next month. `DateTime`
/// applies the device's time-zone rules to each end, so a DST change inside
/// the month still gives the exact local month (#68).
List<String> calendarLocalMonthQueryParams(String monthKey) {
  final parts = monthKey.split('-');
  final year = int.parse(parts[0]);
  final month = int.parse(parts[1]);
  String param(String name, DateTime localMidnight) =>
      '$name=${Uri.encodeQueryComponent(toApiInstant(localMidnight))}';
  return [
    param('starts_from', DateTime(year, month)),
    param('starts_before', DateTime(year, month + 1)),
  ];
}

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
