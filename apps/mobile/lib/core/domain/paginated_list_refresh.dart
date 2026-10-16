/// One fetched page of an offset-paginated list.
typedef PaginatedPage<T> = ({List<T> items, bool hasMore});

/// Fetches [limit] rows starting at [offset].
typedef PaginatedPageFetcher<T> =
    Future<PaginatedPage<T>> Function({
      required int limit,
      required int offset,
    });

/// Result of refreshing a paginated list while preserving scroll depth.
class PaginatedListRefreshResult<T> {
  const PaginatedListRefreshResult({
    required this.items,
    required this.loadedCount,
    required this.hasMore,
  });

  final List<T> items;
  final int loadedCount;
  final bool hasMore;
}

/// Refreshes an offset-paginated, newest-first list after a mutation without
/// dropping rows the user already scrolled to.
///
/// Fetches the first page once. When it starts with rows the list has not seen
/// and still overlaps the current list, those rows are prepended (the offset
/// cursor stays valid because the server shifted by exactly that many rows).
/// Otherwise the loaded window is re-fetched, reusing the first page as
/// offset 0, so edits and deletions are reflected.
Future<PaginatedListRefreshResult<T>> refreshPaginatedWindow<T>({
  required PaginatedPageFetcher<T> fetchPage,
  required int pageSize,
  required List<T> currentItems,
  required int loadedCount,
  required bool previousHasMore,
  required Object Function(T item) idOf,
}) async {
  final first = await fetchPage(limit: pageSize, offset: 0);
  final merged = mergeNewHeadItems(
    currentItems: currentItems,
    firstPage: first.items,
    previousHasMore: previousHasMore,
    idOf: idOf,
  );
  if (merged != null) return merged;

  final window = <T>[...first.items];
  var hasMore = first.hasMore;
  while (hasMore && window.length < loadedCount) {
    final limit = (loadedCount - window.length).clamp(1, pageSize);
    final page = await fetchPage(limit: limit, offset: window.length);
    window.addAll(page.items);
    hasMore = page.hasMore;
    if (page.items.isEmpty) break;
  }
  return PaginatedListRefreshResult(
    items: window,
    loadedCount: window.length,
    hasMore: hasMore,
  );
}

/// Prepends rows at the head of [firstPage] that [currentItems] lacks, and
/// applies fresh copies of overlapping rows. Returns null when there are no new
/// head rows, or when the first page has no overlap (a gap may exist), in which
/// case the caller must re-fetch the window.
PaginatedListRefreshResult<T>? mergeNewHeadItems<T>({
  required List<T> currentItems,
  required List<T> firstPage,
  required bool previousHasMore,
  required Object Function(T item) idOf,
}) {
  if (currentItems.isEmpty) return null;
  final currentIds = currentItems.map(idOf).toSet();
  final headCount = firstPage
      .takeWhile((item) => !currentIds.contains(idOf(item)))
      .length;
  if (headCount == 0 || headCount == firstPage.length) return null;

  final updates = <Object, T>{for (final item in firstPage) idOf(item): item};
  final items = <T>[
    ...firstPage.take(headCount),
    for (final item in currentItems) updates[idOf(item)] ?? item,
  ];
  return PaginatedListRefreshResult(
    items: items,
    loadedCount: items.length,
    hasMore: previousHasMore,
  );
}
