import '../../../core/domain/baby_summary.dart';

/// Baby due date from profile — calendar navigation and highlight only, never auto-vote.
DateTime? babyExpectedDueDate(BabySummary baby) {
  final raw = baby.expectedBirthDate;
  if (raw == null || raw.isEmpty) return null;
  return DateTime.tryParse(raw);
}

DateTime? parseBirthdateGuessIso(String? iso) {
  if (iso == null || iso.isEmpty) return null;
  return DateTime.tryParse(iso);
}

String birthdateGuessIso(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

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
