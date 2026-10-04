/// Local calendar display helpers (API stores `starts_at` in UTC).
DateTime eventLocalStart(DateTime startsAt) => startsAt.toLocal();

bool eventOnLocalMonthDay(DateTime startsAt, DateTime visibleMonth) {
  final local = eventLocalStart(startsAt);
  return local.year == visibleMonth.year && local.month == visibleMonth.month;
}

int eventLocalDayOfMonth(DateTime startsAt) => eventLocalStart(startsAt).day;

bool eventOnLocalCalendarDay(DateTime startsAt, DateTime day) {
  final local = eventLocalStart(startsAt);
  return local.year == day.year &&
      local.month == day.month &&
      local.day == day.day;
}

bool isEventStartInPast(DateTime startsAtLocal) {
  return startsAtLocal.isBefore(DateTime.now());
}
