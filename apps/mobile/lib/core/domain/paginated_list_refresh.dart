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

/// Merges a freshly fetched first page into [currentItems] when new rows appear
/// at the head (e.g. a new gallery photo). Otherwise re-fetches the full loaded
/// window so metadata updates without dropping rows.
PaginatedListRefreshResult<T> mergePaginatedListRefresh<T>({
  required List<T> currentItems,
  required List<T> firstPage,
  required bool firstPageHasMore,
  required int pageSize,
  required int previousLoadedCount,
  required bool previousHasMore,
  required Object idOf(T item),
  List<T>? fullReload,
  bool? fullReloadHasMore,
}) {
  final currentIds = currentItems.map(idOf).toSet();
  final newAtHead =
      firstPage.where((item) => !currentIds.contains(idOf(item))).toList();

  if (newAtHead.isNotEmpty) {
    final merged = <T>[...newAtHead, ...currentItems];
    final seen = <Object>{};
    final deduped = <T>[];
    for (final item in merged) {
      final id = idOf(item);
      if (seen.add(id)) {
        deduped.add(item);
      }
    }
    final updates = <Object, T>{for (final item in firstPage) idOf(item): item};
    for (var i = 0; i < deduped.length; i++) {
      final updated = updates[idOf(deduped[i])];
      if (updated != null) {
        deduped[i] = updated;
      }
    }
    return PaginatedListRefreshResult(
      items: deduped,
      loadedCount: deduped.length,
      hasMore: previousHasMore,
    );
  }

  final refreshed = fullReload ?? firstPage;
  final loaded = refreshed.length;
  final hasMore = fullReloadHasMore ??
      (loaded >= pageSize && firstPageHasMore);
  return PaginatedListRefreshResult(
    items: refreshed,
    loadedCount: loaded,
    hasMore: hasMore,
  );
}
