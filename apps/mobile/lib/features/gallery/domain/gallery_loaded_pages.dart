import '../../../core/domain/paginated_list_refresh.dart';
import '../data/gallery_repository.dart';
import '../data/models/photo_models.dart';

/// Refreshes the loaded gallery window after a mutation; see
/// [refreshPaginatedWindow].
Future<PaginatedListRefreshResult<PhotoSummary>> refreshLoadedPhotoList(
  GalleryRepository repo,
  String babyId, {
  required List<PhotoSummary> currentItems,
  required int loadedCount,
  required bool previousHasMore,
  String sort = 'default',
}) {
  return refreshPaginatedWindow<PhotoSummary>(
    fetchPage: ({required limit, required offset}) async {
      final page = await repo.listPhotosPage(
        babyId,
        sort: sort,
        limit: limit,
        offset: offset,
      );
      return (items: page.items, hasMore: page.hasMore);
    },
    pageSize: GalleryRepository.pageSize,
    currentItems: currentItems,
    loadedCount: loadedCount,
    previousHasMore: previousHasMore,
    idOf: (photo) => photo.id,
  );
}
