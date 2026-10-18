import 'dart:async';

import 'package:image_picker/image_picker.dart' show XFile;
import 'package:lanonna/core/media/event_cover_uploader.dart';

class FakeEventCoverUploader implements EventCoverUploader {
  final uploadedFiles = <XFile>[];
  final uploadResults = <Completer<String>>[];

  @override
  Future<String> upload(String babyProfileId, XFile imageFile) {
    uploadedFiles.add(imageFile);
    if (uploadResults.isEmpty) {
      return Future.value('uploaded-${uploadedFiles.length}');
    }
    return uploadResults.removeAt(0).future;
  }
}
