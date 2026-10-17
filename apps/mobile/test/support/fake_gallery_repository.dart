import 'dart:async';

import 'package:image_picker/image_picker.dart' show XFile;
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/features/gallery/data/gallery_repository.dart';
import 'package:lanonna/features/gallery/data/models/photo_models.dart';

/// Offline [GalleryRepository]: `listPhotos` returns [photos] and counts calls.
class FakeGalleryRepository extends GalleryRepository {
  FakeGalleryRepository() : super(ApiClient(idTokenProvider: () async => null));

  int listCalls = 0;
  List<PhotoSummary> photos = const [];

  /// Files passed to [uploadPhoto], in order.
  final uploadedFiles = <XFile>[];

  /// Each [uploadPhoto] call waits on the next queued completer (tests drive
  /// the upload's progress and outcome); with none queued it returns
  /// `uploaded-<n>` at once.
  final uploadResults = <Completer<String>>[];

  @override
  Future<String> uploadPhoto(
    String babyId,
    XFile imageFile, {
    String? caption,
  }) {
    uploadedFiles.add(imageFile);
    if (uploadResults.isEmpty) {
      return Future.value('uploaded-${uploadedFiles.length}');
    }
    return uploadResults.removeAt(0).future;
  }

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
