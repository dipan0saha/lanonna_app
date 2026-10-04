import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/display_photo_upload.dart';
import 'photo_upload_caption_sheet.dart';

/// Picks optional caption, then uploads to the gallery display bucket.
Future<String> runGalleryPhotoUpload({
  required BuildContext context,
  required String babyProfileId,
  required File imageFile,
  required ApiClient api,
  bool promptCaption = true,
}) async {
  String? caption;
  if (promptCaption) {
    caption = await showPhotoUploadCaptionSheet(context, imageFile: imageFile);
  }
  return DisplayPhotoUpload(api).uploadGalleryPhoto(
    babyProfileId: babyProfileId,
    imageFile: imageFile,
    caption: caption,
  );
}
