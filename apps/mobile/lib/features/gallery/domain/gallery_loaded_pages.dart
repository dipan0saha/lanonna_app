import '../../../core/domain/paginated_list_refresh.dart';
import '../data/gallery_repository.dart';
import '../data/models/photo_models.dart';

/// Re-fetches gallery list pages covering [loadedCount] items (offset 0).
Future<List<PhotoSummary>> fetchLoadedPhotoRange(
  GalleryRepository repo,
  String babyId, {
  required int loadedCount,
  String sort = 'default',
}) async {
  if (loadedCount <= 0) return const [];
  final merged = <PhotoSummary>[];
  var offset = 0;
  while (merged.length < loadedCount) {
    final limit = (loadedCount - merged.length).clamp(1, GalleryRepository.pageSize);
    final page = await repo.listPhotosPage(
      babyId,
      sort: sort,
      limit: limit,
      offset: offset,
    );
    merged.addAll(page.items);
    if (!page.hasMore || page.items.isEmpty) break;
    offset += page.items.length;
  }
  if (merged.length > loadedCount) {
    return merged.sublist(0, loadedCount);
  }
  return merged;
}

/// Refreshes the gallery list after a mutation, prepending new head items when
/// the server gained rows without shrinking the visible window.
Future<PaginatedListRefreshResult<PhotoSummary>> refreshLoadedPhotoList(
  GalleryRepository repo,
  String babyId, {
  required List<PhotoSummary> currentItems,
  required int loadedCount,
  required bool previousHasMore,
  String sort = 'default',
}) async {
  final firstPage = await repo.listPhotosPage(
    babyId,
    sort: sort,
    limit: GalleryRepository.pageSize,
    offset: 0,
  );
  List<PhotoSummary> fullReload = firstPage.items;
  var fullReloadHasMore = firstPage.hasMore;
  if (currentItems.isNotEmpty && loadedCount > 0) {
    final merged = <PhotoSummary>[];
    var offset = 0;
    while (merged.length < loadedCount) {
      final limit =
          (loadedCount - merged.length).clamp(1, GalleryRepository.pageSize);
      final page = await repo.listPhotosPage(
        babyId,
        sort: sort,
        limit: limit,
        offset: offset,
      );
      merged.addAll(page.items);
      fullReloadHasMore = page.hasMore;
      if (!page.hasMore || page.items.isEmpty) break;
      offset += page.items.length;
    }
    fullReload = merged.length > loadedCount
        ? merged.sublist(0, loadedCount)
        : merged;
  }
  return mergePaginatedListRefresh(
    currentItems: currentItems,
    firstPage: firstPage.items,
    firstPageHasMore: firstPage.hasMore,
    pageSize: GalleryRepository.pageSize,
    previousLoadedCount: loadedCount,
    previousHasMore: previousHasMore,
    idOf: (photo) => photo.id,
    fullReload: fullReload,
    fullReloadHasMore: fullReloadHasMore,
  );
}
