import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/features/gallery/data/models/photo_models.dart';

void main() {
  test('PhotoSummary parses numeric counts from JSON numbers', () {
    final summary = PhotoSummary.fromJson({
      'id': 'p1',
      'status': 'ready',
      'created_at': '2026-01-01T12:00:00Z',
      'squish_count': 3.0,
      'comment_count': 2.0,
    });
    expect(summary.squishCount, 3);
    expect(summary.commentCount, 2);
  });
}
