import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/l10n/app_localizations_en.dart';

void main() {
  final l10n = AppLocalizationsEn();

  group('photoSquishCount', () {
    test('pluralizes 0, 1, 2+', () {
      expect(l10n.photoSquishCount(0), '0 squishes');
      expect(l10n.photoSquishCount(1), '1 squish');
      expect(l10n.photoSquishCount(2), '2 squishes');
    });
  });

  group('photoCommentCount', () {
    test('pluralizes 0, 1, 2+', () {
      expect(l10n.photoCommentCount(0), '0 comments');
      expect(l10n.photoCommentCount(1), '1 comment');
      expect(l10n.photoCommentCount(3), '3 comments');
    });
  });

  group('predictionVoteCount', () {
    test('pluralizes 0, 1, 2+', () {
      expect(l10n.predictionVoteCount(0), '0 votes');
      expect(l10n.predictionVoteCount(1), '1 vote');
      expect(l10n.predictionVoteCount(5), '5 votes');
    });
  });

  group('rsvpResponseCount', () {
    test('singular and plural', () {
      expect(l10n.rsvpResponseCount(0), '0 responses');
      expect(l10n.rsvpResponseCount(1), '1 response');
      expect(l10n.rsvpResponseCount(3), '3 responses');
    });
  });

  group('nameLoveCount', () {
    test('pluralizes 0, 1, 2+', () {
      expect(l10n.nameLoveCount(0), '0 loves');
      expect(l10n.nameLoveCount(1), '1 love');
      expect(l10n.nameLoveCount(2), '2 loves');
    });
  });

  group('followerCount', () {
    test('pluralizes 0, 1, 2+', () {
      expect(l10n.followerCount(0), '0 followers');
      expect(l10n.followerCount(1), '1 follower');
      expect(l10n.followerCount(3), '3 followers');
    });
  });
}
