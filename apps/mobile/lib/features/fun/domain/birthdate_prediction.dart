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

DateTime birthdatePickerInitialDate({
  DateTime? pendingSelection,
  String? savedVoteIso,
  DateTime? dueDate,
}) {
  return pendingSelection ??
      parseBirthdateGuessIso(savedVoteIso) ??
      dueDate ??
      DateTime.now();
}

DateTime birthdatePickerFirstDate({
  required String? voteMinIso,
  DateTime? dueDate,
}) {
  final fromApi = tryParseApiCalendarDate(voteMinIso);
  if (fromApi != null) return fromApi;
  return dueDate ?? DateTime.now();
}

DateTime birthdatePickerLastDate({
  required String? voteMaxIso,
  DateTime? dueDate,
}) {
  final fromApi = tryParseApiCalendarDate(voteMaxIso);
  if (fromApi != null) return fromApi;
  final anchor = dueDate ?? DateTime.now();
  return anchor.add(const Duration(days: 42));
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
