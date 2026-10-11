import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/features/gallery/data/gallery_repository.dart';
import 'package:lanonna/features/gallery/data/models/photo_models.dart';

/// Offline [GalleryRepository]: `listPhotos` returns [photos] and counts calls.
class FakeGalleryRepository extends GalleryRepository {
  FakeGalleryRepository() : super(ApiClient(idTokenProvider: () async => null));

  int listCalls = 0;
  List<PhotoSummary> photos = const [];

  @override
  Future<List<PhotoSummary>> listPhotos(
    String babyId, {
    String sort = 'default',
  }) async {
    listCalls++;
    return photos;
  }
}
