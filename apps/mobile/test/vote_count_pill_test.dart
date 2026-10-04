import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/widgets/vote_count_pill.dart';

void main() {
  test('VoteCountPill label singular and plural', () {
    expect(VoteCountPill.labelFor(1), '1 VOTE');
    expect(VoteCountPill.labelFor(2), '2 VOTES');
    expect(VoteCountPill.labelFor(11), '11 VOTES');
  });
}
