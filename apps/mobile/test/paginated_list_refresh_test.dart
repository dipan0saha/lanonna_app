import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/domain/paginated_list_refresh.dart';

void main() {
  test('prepends new head items and grows loaded count', () {
    final current = [
      {'id': '1'},
      {'id': '2'},
      {'id': '3'},
      {'id': '4'},
    ];
    final firstPage = [
      {'id': '5'},
      {'id': '1'},
      {'id': '2'},
    ];

    final result = mergePaginatedListRefresh<Map<String, String>>(
      currentItems: current.cast(),
      firstPage: firstPage.cast(),
      firstPageHasMore: false,
      pageSize: 50,
      previousLoadedCount: 4,
      previousHasMore: false,
      idOf: (item) => item['id']!,
      fullReload: current.cast(),
      fullReloadHasMore: false,
    );

    expect(result.items.map((e) => e['id']), ['5', '1', '2', '3', '4']);
    expect(result.loadedCount, 5);
    expect(result.hasMore, isFalse);
  });

  test('full reload updates items when no new head rows', () {
    final current = [
      {'id': '1', 'v': 'old'},
      {'id': '2', 'v': 'old'},
    ];
    final firstPage = [
      {'id': '1', 'v': 'new'},
      {'id': '2', 'v': 'new'},
    ];

    final result = mergePaginatedListRefresh<Map<String, String>>(
      currentItems: current.cast(),
      firstPage: firstPage.cast(),
      firstPageHasMore: false,
      pageSize: 50,
      previousLoadedCount: 2,
      previousHasMore: false,
      idOf: (item) => item['id']!,
      fullReload: firstPage.cast(),
      fullReloadHasMore: false,
    );

    expect(result.items.every((e) => e['v'] == 'new'), isTrue);
    expect(result.loadedCount, 2);
  });
}
