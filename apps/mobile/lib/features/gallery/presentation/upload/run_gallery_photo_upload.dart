import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart' show XFile;

import '../../data/gallery_repository.dart';
import 'photo_upload_caption_sheet.dart';

/// Picks optional caption, then uploads to the gallery display bucket.
Future<String> runGalleryPhotoUpload({
  required BuildContext context,
  required String babyProfileId,
  required XFile imageFile,
  required GalleryRepository gallery,
  bool promptCaption = true,
}) async {
  String? caption;
  if (promptCaption) {
    caption = await showPhotoUploadCaptionSheet(context, imageFile: imageFile);
  }
  return gallery.uploadPhoto(babyProfileId, imageFile, caption: caption);
}
