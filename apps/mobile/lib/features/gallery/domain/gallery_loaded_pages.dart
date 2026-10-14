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
