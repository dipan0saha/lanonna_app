import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/features/fun/domain/gender_vote_display.dart';

void main() {
  test('zero votes yields no percent or progress', () {
    final d = genderVoteDisplay(maleVotes: 0, femaleVotes: 0);
    expect(d.total, 0);
    expect(d.malePercent, isNull);
    expect(d.femalePercent, isNull);
    expect(d.maleProgress, isNull);
    expect(d.displayPercentForMale(), 0);
    expect(d.displayPercentForFemale(), 0);
  });

  test('non-zero votes compute rounded percent and progress', () {
    final d = genderVoteDisplay(maleVotes: 1, femaleVotes: 3);
    expect(d.total, 4);
    expect(d.malePercent, 25);
    expect(d.femalePercent, 75);
    expect(d.maleProgress, 0.25);
  });
}
