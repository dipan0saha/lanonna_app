import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// API stores instants in UTC (ISO-8601). UI uses device-local wall time.

DateTime parseApiInstant(String raw) => DateTime.parse(raw).toLocal();

DateTime? tryParseApiInstant(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  return parseApiInstant(raw);
}

String toApiInstant(DateTime value) => value.toUtc().toIso8601String();

/// Normalize API or form [DateTime] to local wall time for display and calendar math.
DateTime eventWallTime(DateTime value) => value.isUtc ? value.toLocal() : value;

DateTime eventLocalStart(DateTime startsAt) => eventWallTime(startsAt);

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

/// Calendar list / upcoming rows (locale-aware date + time).
String formatEventListDateTime(DateTime startsAt, [String? localeName]) {
  final local = eventWallTime(startsAt);
  return DateFormat.yMMMMd(localeName).add_jm().format(local);
}

/// Event detail "When" line.
String formatEventDetailWhen(DateTime startsAt, [String? localeName]) {
  final local = eventWallTime(startsAt);
  final datePart = DateFormat('EEEE, MMM d, y', localeName).format(local);
  final timePart = DateFormat.jm(localeName).format(local);
  return '$datePart · $timePart';
}

/// Home upcoming card month badge (e.g. OCT).
String formatEventMonthBadge(DateTime startsAt, [String? localeName]) {
  return DateFormat.MMM(localeName)
      .format(eventWallTime(startsAt))
      .toUpperCase();
}

int formatEventDayBadge(DateTime startsAt) => eventWallTime(startsAt).day;

/// Locale string for `DateFormat` (full tag, e.g. `en_US`).
String localeNameForFormatting(BuildContext context) {
  return Localizations.localeOf(context).toString();
}

/// Date-only API values (`YYYY-MM-DD`) for due dates, birthdate guesses, etc.
DateTime? tryParseApiCalendarDate(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final trimmed = raw.trim();
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(trimmed);
  if (match != null) {
    return DateTime.utc(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }
  return DateTime.tryParse(trimmed);
}

String formatApiCalendarDateFromParts(DateTime date, [String? localeName]) {
  final calendar = DateTime(date.year, date.month, date.day);
  return DateFormat.yMMMMd(localeName).format(calendar);
}

/// Returns empty string when [raw] is null, blank, or unparseable.
String formatApiCalendarDate(String? raw, [String? localeName]) {
  final dt = tryParseApiCalendarDate(raw);
  if (dt == null) return '';
  return formatApiCalendarDateFromParts(dt, localeName);
}

/// Serialize a calendar date for API fields (`YYYY-MM-DD`). Not for UI display.
String toApiCalendarDate(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
