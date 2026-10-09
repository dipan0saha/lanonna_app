import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/domain/baby_summary.dart';
import 'package:lanonna/features/fun/domain/birthdate_prediction.dart';

void main() {
  const babyWithDue = BabySummary(
    id: 'b1',
    name: 'Parker',
    lifecycleStatus: 'expecting',
    role: 'follower',
    expectedBirthDate: '2027-02-01',
  );

  test('birthdateGuessToSubmit never uses profile due date', () {
    expect(babyExpectedDueDate(babyWithDue), DateTime(2027, 2, 1));
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
}
