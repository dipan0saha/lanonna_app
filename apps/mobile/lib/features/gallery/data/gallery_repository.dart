import 'package:flutter/foundation.dart';

import '../../../core/api/api_client.dart';
import 'models/photo_models.dart';

class GalleryRepository extends ChangeNotifier {
  GalleryRepository(this._api);

  final ApiClient _api;

  void _markGalleryChanged() => notifyListeners();

  /// Uploads and other flows outside this repository call this after mutating gallery data.
  void markGalleryChanged() => _markGalleryChanged();

  Future<List<PhotoSummary>> listPhotos(
    String babyId, {
    String sort = 'default',
  }) async {
    final list = await _api.getJsonList(
      '/v1/babies/$babyId/photos',
      queryParameters: sort == 'default' ? null : <String, String>{'sort': sort},
    );
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
    _markGalleryChanged();
  }

  Future<bool> toggleSquish(String babyId, String photoId) async {
    final json =
        await _api.postJson('/v1/babies/$babyId/photos/$photoId/squish');
    _markGalleryChanged();
    return json['squished'] as bool? ?? false;
  }

  Future<void> addComment(String babyId, String photoId, String body) async {
    await _api.postJson('/v1/babies/$babyId/photos/$photoId/comments', body: {
      'body': body,
    });
    _markGalleryChanged();
  }

  Future<void> deleteComment(
    String babyId,
    String photoId,
    String commentId,
  ) async {
    await _api.deleteJson(
      '/v1/babies/$babyId/photos/$photoId/comments/$commentId',
    );
    _markGalleryChanged();
  }

  Future<void> updateComment(
    String babyId,
    String photoId,
    String commentId,
    String body,
  ) async {
    await _api.patchJson(
      '/v1/babies/$babyId/photos/$photoId/comments/$commentId',
      body: {'body': body},
    );
  }

  Future<List<PhotoTaggedBaby>> setPhotoTags(
    String babyId,
    String photoId,
    List<String> taggedBabyProfileIds,
  ) async {
    final json = await _api.putJson(
      '/v1/babies/$babyId/photos/$photoId/tags',
      body: {'tagged_baby_profile_ids': taggedBabyProfileIds},
    );
    final tagged = json['tagged_babies'];
    if (tagged is! List) return [];
    return tagged
        .whereType<Map<String, dynamic>>()
        .map(PhotoTaggedBaby.fromJson)
        .toList();
  }
}
