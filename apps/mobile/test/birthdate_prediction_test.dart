import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/domain/baby_lifecycle.dart';
import 'package:lanonna/core/domain/baby_summary.dart';
import 'package:lanonna/features/fun/domain/birthdate_prediction.dart';

void main() {
  const babyWithDue = BabySummary(
    id: 'b1',
    name: 'Parker',
    lifecycle: BabyLifecycle.expecting,
    role: 'follower',
    expectedBirthDate: '2027-02-01',
  );

  test('birthdateGuessToSubmit never uses profile due date', () {
    final due = babyExpectedDueDate(babyWithDue)!;
    expect(due.year, 2027);
    expect(due.month, 2);
    expect(due.day, 1);
    expect(birthdateGuessToSubmit(pendingSelection: null), isNull);
    expect(
      birthdateGuessToSubmit(
        pendingSelection: DateTime(2027, 3, 15),
      ),
      DateTime(2027, 3, 15),
    );
  });

  test('birthdateGuessSubmitEnabled requires explicit pending selection', () {
    expect(
      birthdateGuessSubmitEnabled(
        pendingSelection: null,
        savedVoteIso: null,
      ),
      isFalse,
    );
    expect(
      birthdateGuessSubmitEnabled(
        pendingSelection: null,
        savedVoteIso: '2027-02-01',
      ),
      isFalse,
    );
    expect(
      birthdateGuessSubmitEnabled(
        pendingSelection: DateTime(2027, 2, 1),
        savedVoteIso: null,
      ),
      isTrue,
    );
    expect(
      birthdateGuessSubmitEnabled(
        pendingSelection: DateTime(2027, 2, 1),
        savedVoteIso: '2027-02-01',
      ),
      isFalse,
    );
    expect(
      birthdateGuessSubmitEnabled(
        pendingSelection: DateTime(2027, 3, 1),
        savedVoteIso: '2027-02-01',
      ),
      isTrue,
    );
  });

  test('birthdateGuessIso formats zero-padded month and day', () {
    expect(birthdateGuessIso(DateTime(2027, 2, 1)), '2027-02-01');
    expect(birthdateGuessIso(DateTime(2027, 12, 9)), '2027-12-09');
  });

  test('visibleMonthForBirthdateGuess prefers saved vote then due date', () {
    expect(
      visibleMonthForBirthdateGuess(
        savedVoteIso: '2027-05-10',
        dueDate: DateTime(2027, 2, 1),
      ),
      DateTime(2027, 5),
    );
    expect(
      visibleMonthForBirthdateGuess(
        savedVoteIso: null,
        dueDate: DateTime(2027, 2, 1),
      ),
      DateTime(2027, 2),
    );
  });

  test('guess window comes only from the server', () {
    final window = birthdateGuessWindow(
      voteMinIso: '2026-12-04',
      voteMaxIso: '2027-02-26',
    )!;
    expect(window.first, DateTime(2026, 12, 4));
    expect(window.last, DateTime(2027, 2, 26));
    expect(birthdateGuessWindow(voteMinIso: null, voteMaxIso: '2027-02-26'), isNull);
    expect(
      birthdateGuessWindow(voteMinIso: '2027-03-01', voteMaxIso: '2027-02-26'),
      isNull,
    );
  });

  test('picker opens inside the window even for an old saved guess', () {
    final window = (first: DateTime(2026, 12, 4), last: DateTime(2027, 2, 26));
    expect(
      birthdatePickerInitialDate(window: window, savedVoteIso: '2026-11-01'),
      DateTime(2026, 12, 4),
    );
    expect(
      birthdatePickerInitialDate(window: window, savedVoteIso: '2099-12-31'),
      DateTime(2027, 2, 26),
    );
    expect(
      birthdatePickerInitialDate(window: window, dueDate: DateTime(2027, 1, 15)),
      DateTime(2027, 1, 15),
    );
    expect(
      birthdatePickerInitialDate(window: window, now: DateTime(2026, 10, 23, 15)),
      DateTime(2026, 12, 4),
    );
  });
}
