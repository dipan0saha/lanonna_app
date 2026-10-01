import '../../../core/api/api_client.dart';
import 'models/photo_models.dart';

class GalleryRepository {
  GalleryRepository(this._api);

  final ApiClient _api;

  Future<List<PhotoSummary>> listPhotos(String babyId) async {
    final list = await _api.getJsonList('/v1/babies/$babyId/photos');
    return list
        .whereType<Map<String, dynamic>>()
        .map(PhotoSummary.fromJson)
        .toList();
  }

  Future<PhotoDetail> fetchPhoto(String babyId, String photoId) async {
    final json =
        await _api.getJson('/v1/babies/$babyId/photos/$photoId');
    return PhotoDetail.fromJson(json);
  }

  Future<void> updateCaption(
    String babyId,
    String photoId,
    String? caption,
  ) async {
    await _api.patchJson('/v1/babies/$babyId/photos/$photoId', body: {
      'caption': caption,
    });
  }

  Future<void> deletePhoto(String babyId, String photoId) async {
    await _api.deleteJson('/v1/babies/$babyId/photos/$photoId');
  }

  Future<bool> toggleSquish(String babyId, String photoId) async {
    final json =
        await _api.postJson('/v1/babies/$babyId/photos/$photoId/squish');
    return json['squished'] as bool? ?? false;
  }

  Future<void> addComment(String babyId, String photoId, String body) async {
    await _api.postJson('/v1/babies/$babyId/photos/$photoId/comments', body: {
      'body': body,
    });
  }

  Future<void> deleteComment(
    String babyId,
    String photoId,
    String commentId,
  ) async {
    await _api.deleteJson(
      '/v1/babies/$babyId/photos/$photoId/comments/$commentId',
    );
  }
}
