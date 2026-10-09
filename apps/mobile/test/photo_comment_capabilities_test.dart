import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/features/gallery/data/models/photo_models.dart';

void main() {
  test('PhotoComment parses owner moderation flags from API', () {
    final comment = PhotoComment.fromJson({
      'id': 'c1',
      'body': 'Follower QA comment',
      'author_display_name': 'Alex',
      'created_at': '2026-10-09T12:00:00.000Z',
      'is_mine': false,
      'can_edit': false,
      'can_delete': true,
    });

    expect(comment.isMine, isFalse);
    expect(comment.canEdit, isFalse);
    expect(comment.canDelete, isTrue);
  });

  test('PhotoComment defaults can_edit and can_delete to is_mine', () {
    final comment = PhotoComment.fromJson({
      'id': 'c2',
      'body': 'Mine',
      'created_at': '2026-10-09T12:00:00.000Z',
      'is_mine': true,
    });

    expect(comment.canEdit, isTrue);
    expect(comment.canDelete, isTrue);
  });
}
