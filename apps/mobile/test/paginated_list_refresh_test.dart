import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/domain/paginated_list_refresh.dart';

typedef _Row = ({String id, String v});

PaginatedPageFetcher<_Row> _server(List<_Row> rows, List<int> offsets) {
  return ({required limit, required offset}) async {
    offsets.add(offset);
    final end = (offset + limit).clamp(0, rows.length);
    final items = offset >= rows.length ? <_Row>[] : rows.sublist(offset, end);
    return (items: items, hasMore: end < rows.length);
  };
}

List<_Row> _rows(Iterable<String> ids, [String v = 'old']) => [
  for (final id in ids) (id: id, v: v),
];

void main() {
  test('prepends new head rows with a single fetch', () async {
    final offsets = <int>[];
    final result = await refreshPaginatedWindow<_Row>(
      fetchPage: _server(_rows(['5', '1', '2', '3', '4', '6']), offsets),
      pageSize: 3,
      currentItems: _rows(['1', '2', '3', '4']),
      loadedCount: 4,
      previousHasMore: true,
      idOf: (r) => r.id,
    );
    expect(result.items.map((e) => e.id), ['5', '1', '2', '3', '4']);
    expect(result.loadedCount, 5);
    expect(result.hasMore, isTrue);
    expect(offsets, [0]);
  });

  test('re-fetches the loaded window when no new head rows', () async {
    final offsets = <int>[];
    final result = await refreshPaginatedWindow<_Row>(
      fetchPage: _server(_rows(['1', '2', '3', '4', '5'], 'new'), offsets),
      pageSize: 2,
      currentItems: _rows(['1', '2', '3']),
      loadedCount: 3,
      previousHasMore: true,
      idOf: (r) => r.id,
    );
    expect(result.items.map((e) => e.id), ['1', '2', '3']);
    expect(result.items.every((e) => e.v == 'new'), isTrue);
    expect(result.hasMore, isTrue);
    expect(offsets, [0, 2]);
  });

  test(
    'falls back to a window reload when the first page has no overlap',
    () async {
      final offsets = <int>[];
      final result = await refreshPaginatedWindow<_Row>(
        fetchPage: _server(_rows(['9', '8', '1', '2']), offsets),
        pageSize: 2,
        currentItems: _rows(['1', '2']),
        loadedCount: 2,
        previousHasMore: false,
        idOf: (r) => r.id,
      );
      expect(result.items.map((e) => e.id), ['9', '8']);
      expect(result.hasMore, isTrue);
    },
  );

  test('deletion shrinks the window', () async {
    final result = await refreshPaginatedWindow<_Row>(
      fetchPage: _server(_rows(['1', '3']), []),
      pageSize: 50,
      currentItems: _rows(['1', '2', '3']),
      loadedCount: 3,
      previousHasMore: false,
      idOf: (r) => r.id,
    );
    expect(result.items.map((e) => e.id), ['1', '3']);
    expect(result.hasMore, isFalse);
  });
}
