import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/features/gallery/data/gallery_repository.dart';
import 'package:lanonna/features/gallery/data/models/photo_models.dart';

/// Offline [GalleryRepository]: `listPhotos` returns [photos] and counts calls.
class FakeGalleryRepository extends GalleryRepository {
  FakeGalleryRepository() : super(ApiClient(idTokenProvider: () async => null));

  int listCalls = 0;
  List<PhotoSummary> photos = const [];

  @override
  Future<PhotoListPage> listPhotosPage(
    String babyId, {
    String sort = 'default',
    int limit = 50,
    int offset = 0,
  }) async {
    listCalls++;
    final slice = photos.skip(offset).take(limit).toList();
    return PhotoListPage(
      items: slice,
      hasMore: offset + slice.length < photos.length,
    );
  }

  @override
  Future<List<PhotoSummary>> listPhotos(
    String babyId, {
    String sort = 'default',
  }) async {
    listCalls++;
    return photos;
  }

  @override
  Future<PhotoDetail> fetchPhoto(String babyId, String photoId) async {
    PhotoSummary? summary;
    for (final p in photos) {
      if (p.id == photoId) {
        summary = p;
        break;
      }
    }
    if (summary == null) {
      return PhotoDetail(
        id: photoId,
        status: 'ready',
        createdAt: DateTime.utc(2026, 1, 1),
        uploaderDisplayName: 'Owner',
        squishCount: 0,
        viewerHasSquished: false,
        comments: const [],
        taggedBabies: const [],
      );
    }
    return PhotoDetail(
      id: summary.id,
      status: summary.status,
      caption: summary.caption,
      createdAt: summary.createdAt,
      thumbUrl: summary.thumbUrl,
      uploaderDisplayName: summary.uploaderDisplayName,
      squishCount: summary.squishCount,
      viewerHasSquished: false,
      comments: const [],
      taggedBabies: const [],
    );
  }
}
