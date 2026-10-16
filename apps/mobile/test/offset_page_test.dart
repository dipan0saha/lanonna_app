import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/api/offset_page.dart';

void main() {
  test('parseOffsetPage maps items and has_more', () {
    final page = parseOffsetPage<int>(
      {
        'items': [
          {'value': 1},
          {'value': 2},
        ],
        'has_more': true,
        'offset': 10,
        'limit': 2,
      },
      (json) => json['value'] as int,
      defaultLimit: 2,
    );
    expect(page.items, [1, 2]);
    expect(page.hasMore, isTrue);
    expect(page.offset, 10);
    expect(page.limit, 2);
  });
}
