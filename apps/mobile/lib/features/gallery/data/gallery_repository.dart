import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart' show XFile;

import '../../../core/api/api_client.dart';
import '../../../core/api/display_photo_upload.dart';
import '../../../core/api/offset_page.dart';
import '../../../core/data/single_flight.dart';
import 'models/photo_models.dart';

/// The ids of the photos loaded so far for one baby and sort, in gallery
/// order: always a prefix of the full list.
class PhotoIdWindow {
  const PhotoIdWindow({required this.ids, required this.hasMore});

  final List<String> ids;
  final bool hasMore;
}

class GalleryRepository extends ChangeNotifier {
  GalleryRepository(this._api, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final ApiClient _api;
  final DateTime Function() _clock;

  /// A photo detail fetched this recently is shown without refetching (photo
  /// viewer next/previous). Well inside the 15-minute signed URL lifetime.
  static const detailFreshFor = Duration(minutes: 1);

  final Map<String, PhotoIdWindow> _windows = {};
  final Map<String, ({PhotoDetail detail, DateTime fetchedAt})> _details = {};
  final _windowRequests = KeyedSingleFlight<String, void>();
  final _detailRequests = KeyedSingleFlight<String, PhotoDetail>();
  var _epoch = 0;

  static String _windowKey(String babyId, String sort) => '$babyId|$sort';
  static String _detailKey(String babyId, String photoId) => '$babyId/$photoId';

  /// Gallery data changed. With [photoId], only that photo's cached detail
  /// is dropped (this user's own edit); otherwise every cached detail is.
  void _markGalleryChanged({String? photoId}) {
    if (photoId == null) {
      _details.clear();
    } else {
      _details.removeWhere((key, _) => key.endsWith('/$photoId'));
    }
    notifyListeners();
  }

  /// Flows outside this repository call this after mutating gallery data.
  void markGalleryChanged() => _markGalleryChanged();

  /// Sign-out / account deletion: forget every loaded window and detail.
  void clearCachedPhotos() {
    _epoch += 1;
    _windows.clear();
    _details.clear();
    _windowRequests.cancelAll();
    _detailRequests.cancelAll();
  }

  /// The photo ids loaded so far for [babyId] in [sort] order (by the gallery
  /// grid or the photo viewer), or `null` when none are.
  PhotoIdWindow? photoWindow(String babyId, String sort) =>
      _windows[_windowKey(babyId, sort)];

  /// Loads the next page of ids after the current window (or the first page).
  /// Concurrent calls for the same window share one request.
  Future<void> extendPhotoWindow(String babyId, String sort) {
    final key = _windowKey(babyId, sort);
    return _windowRequests.run(key, () async {
      final window = _windows[key];
      if (window != null && !window.hasMore) return;
      final offset = window?.ids.length ?? 0;
      final epoch = _epoch;
      final page = await listPhotosPage(babyId, sort: sort, offset: offset);
      if (epoch == _epoch) _recordPage(key, offset, page);
    });
  }

  /// Keeps the window a prefix of the server list: a first page replaces it,
  /// the page right after it extends it, anything else leaves it alone.
  void _recordPage(String key, int offset, PhotoListPage page) {
    final ids = page.items.map((p) => p.id).toList();
    final window = _windows[key];
    if (offset == 0) {
      final keepTail = window != null &&
          window.ids.length > ids.length &&
          _startsWith(window.ids, ids);
      _windows[key] = keepTail
          ? window
          : PhotoIdWindow(ids: ids, hasMore: page.hasMore);
    } else if (window != null && offset == window.ids.length) {
      _windows[key] = PhotoIdWindow(
        ids: [...window.ids, ...ids],
        hasMore: page.hasMore,
      );
    }
  }

  static bool _startsWith(List<String> list, List<String> prefix) {
    for (var i = 0; i < prefix.length; i++) {
      if (list[i] != prefix[i]) return false;
    }
    return true;
  }

  /// The cached detail for [photoId] when it was fetched within
  /// [detailFreshFor]; otherwise `null`.
  PhotoDetail? cachedPhoto(String babyId, String photoId) {
    final entry = _details[_detailKey(babyId, photoId)];
    if (entry == null) return null;
    if (_clock().difference(entry.fetchedAt) >= detailFreshFor) return null;
    return entry.detail;
  }

  /// Fetches [photoId]'s detail ahead of time (the viewer's neighbours), at
  /// most once while it is fresh or in flight.
  Future<PhotoDetail> prefetchPhoto(String babyId, String photoId) {
    final cached = cachedPhoto(babyId, photoId);
    if (cached != null) return Future.value(cached);
    return _detailRequests.run(
      _detailKey(babyId, photoId),
      () => fetchPhoto(babyId, photoId),
    );
  }

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
    final epoch = _epoch;
    final json = await _api.getJson(
      Uri(path: '/v1/babies/$babyId/photos', queryParameters: params).toString(),
    );
    final page = parseOffsetPage(json, PhotoSummary.fromJson, defaultLimit: limit);
    final result = PhotoListPage(items: page.items, hasMore: page.hasMore);
    if (epoch == _epoch) _recordPage(_windowKey(babyId, sort), offset, result);
    return result;
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
    final epoch = _epoch;
    final json =
        await _api.getJson('/v1/babies/$babyId/photos/$photoId');
    final detail = PhotoDetail.fromJson(json);
    if (epoch == _epoch) {
      _details[_detailKey(babyId, photoId)] = (
        detail: detail,
        fetchedAt: _clock(),
      );
    }
    return detail;
  }

  Future<void> updateCaption(
    String babyId,
    String photoId,
    String? caption,
  ) async {
    await _api.patchJson('/v1/babies/$babyId/photos/$photoId', body: {
      'caption': caption,
    });
    _details.remove(_detailKey(babyId, photoId));
  }

  Future<void> deletePhoto(String babyId, String photoId) async {
    await _api.deleteJson('/v1/babies/$babyId/photos/$photoId');
    _windows.updateAll(
      (_, w) => PhotoIdWindow(
        ids: [for (final id in w.ids) if (id != photoId) id],
        hasMore: w.hasMore,
      ),
    );
    _markGalleryChanged(photoId: photoId);
  }

  Future<bool> toggleSquish(String babyId, String photoId) async {
    final json =
        await _api.postJson('/v1/babies/$babyId/photos/$photoId/squish');
    _markGalleryChanged(photoId: photoId);
    return json['squished'] as bool? ?? false;
  }

  Future<void> addComment(String babyId, String photoId, String body) async {
    await _api.postJson('/v1/babies/$babyId/photos/$photoId/comments', body: {
      'body': body,
    });
    _markGalleryChanged(photoId: photoId);
  }

  Future<void> deleteComment(
    String babyId,
    String photoId,
    String commentId,
  ) async {
    await _api.deleteJson(
      '/v1/babies/$babyId/photos/$photoId/comments/$commentId',
    );
    _markGalleryChanged(photoId: photoId);
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
    _details.remove(_detailKey(babyId, photoId));
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
    _details.remove(_detailKey(babyId, photoId));
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
