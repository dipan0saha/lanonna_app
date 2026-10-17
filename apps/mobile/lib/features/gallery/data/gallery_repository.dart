import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart' show XFile;

import '../../../core/api/api_client.dart';
import '../../../core/api/display_photo_upload.dart';
import '../../../core/api/offset_page.dart';
import 'models/photo_models.dart';

class GalleryRepository extends ChangeNotifier {
  GalleryRepository(this._api);

  final ApiClient _api;

  void _markGalleryChanged() => notifyListeners();

  /// Flows outside this repository call this after mutating gallery data.
  void markGalleryChanged() => _markGalleryChanged();

  /// Uploads [imageFile] to the baby's gallery and returns the new photo id.
  /// The photo is `pending` until the worker has made its thumbnails.
  Future<String> uploadPhoto(
    String babyId,
    XFile imageFile, {
    String? caption,
  }) async {
    final photoId = await DisplayPhotoUpload(_api).uploadGalleryPhoto(
      babyProfileId: babyId,
      imageFile: imageFile,
      caption: caption,
    );
    _markGalleryChanged();
    return photoId;
  }

  static const int pageSize = 50;

  Future<PhotoListPage> listPhotosPage(
    String babyId, {
    String sort = 'default',
    int limit = pageSize,
    int offset = 0,
  }) async {
    final params = <String, String>{
      'limit': '$limit',
      'offset': '$offset',
    };
    if (sort != 'default') {
      params['sort'] = sort;
    }
    final json = await _api.getJson(
      Uri(path: '/v1/babies/$babyId/photos', queryParameters: params).toString(),
    );
    final page = parseOffsetPage(json, PhotoSummary.fromJson, defaultLimit: limit);
    return PhotoListPage(items: page.items, hasMore: page.hasMore);
  }

  /// Fetches every page (for pickers and upload polling).
  Future<List<PhotoSummary>> listPhotos(
    String babyId, {
    String sort = 'default',
  }) async {
    final all = <PhotoSummary>[];
    var offset = 0;
    while (true) {
      final page = await listPhotosPage(
        babyId,
        sort: sort,
        limit: 100,
        offset: offset,
      );
      all.addAll(page.items);
      if (!page.hasMore) break;
      offset += page.items.length;
    }
    return all;
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

class PhotoListPage {
  PhotoListPage({required this.items, required this.hasMore});

  final List<PhotoSummary> items;
  final bool hasMore;
}
