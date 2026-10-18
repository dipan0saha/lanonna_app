import 'package:image_picker/image_picker.dart' show XFile;

import '../api/api_client.dart';
import '../api/display_photo_upload.dart';
import '../domain/photo_purpose.dart';

/// Uploads an event cover through the shared display pipeline (not gallery).
abstract interface class EventCoverUploader {
  Future<String> upload(String babyProfileId, XFile imageFile);
}

class ApiEventCoverUploader implements EventCoverUploader {
  ApiEventCoverUploader(this._api);

  final ApiClient _api;

  @override
  Future<String> upload(String babyProfileId, XFile imageFile) {
    return DisplayPhotoUpload(_api).uploadDisplayPhoto(
      babyProfileId: babyProfileId,
      imageFile: imageFile,
      purpose: PhotoPurpose.eventCover,
    );
  }
}
