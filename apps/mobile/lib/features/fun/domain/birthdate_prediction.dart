import '../../../core/domain/baby_summary.dart';
import '../../../core/time/app_date_time.dart';

/// Baby due date from profile — calendar navigation and highlight only, never auto-vote.
DateTime? babyExpectedDueDate(BabySummary baby) {
  return tryParseApiCalendarDate(baby.expectedBirthDate);
}

DateTime? parseBirthdateGuessIso(String? iso) {
  return tryParseApiCalendarDate(iso);
}

String birthdateGuessIso(DateTime date) => toApiCalendarDate(date);

/// API payload: explicit calendar selection only (never profile due date).
DateTime? birthdateGuessToSubmit({required DateTime? pendingSelection}) =>
    pendingSelection;

/// Enable save when there is a pending day that differs from the saved vote (or no vote yet).
bool birthdateGuessSubmitEnabled({
  required DateTime? pendingSelection,
  required String? savedVoteIso,
}) {
  if (pendingSelection == null) return false;
  if (savedVoteIso == null || savedVoteIso.isEmpty) return true;
  return birthdateGuessIso(pendingSelection) != savedVoteIso;
}

/// Days a guess can be saved on (#413). The API owns the rule and sends it as
/// `birthdate_vote_min` / `birthdate_vote_max` (never empty); null until the
/// predictions payload has loaded.
typedef BirthdateGuessWindow = ({DateTime first, DateTime last});

BirthdateGuessWindow? birthdateGuessWindow({
  required String? voteMinIso,
  required String? voteMaxIso,
}) {
  final first = tryParseApiCalendarDate(voteMinIso);
  final last = tryParseApiCalendarDate(voteMaxIso);
  if (first == null || last == null || first.isAfter(last)) return null;
  return (first: calendarDay(first), last: calendarDay(last));
}

/// Day the picker opens on: the pending pick, saved guess, due date or today,
/// moved into [window] (a saved guess can fall outside it once days pass).
DateTime birthdatePickerInitialDate({
  required BirthdateGuessWindow window,
  DateTime? pendingSelection,
  String? savedVoteIso,
  DateTime? dueDate,
  DateTime? now,
}) {
  final wanted = calendarDay(
    pendingSelection ??
        parseBirthdateGuessIso(savedVoteIso) ??
        dueDate ??
        now ??
        DateTime.now(),
  );
  if (wanted.isBefore(window.first)) return window.first;
  if (wanted.isAfter(window.last)) return window.last;
  return wanted;
}

DateTime visibleMonthForBirthdateGuess({
  String? savedVoteIso,
  DateTime? dueDate,
  DateTime? now,
}) {
  final anchor = now ?? DateTime.now();
  final saved = parseBirthdateGuessIso(savedVoteIso);
  if (saved != null) {
    return DateTime(saved.year, saved.month);
  }
  if (dueDate != null) {
    return DateTime(dueDate.year, dueDate.month);
  }
  return DateTime(anchor.year, anchor.month);
}
