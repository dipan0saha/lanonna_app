import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

/// What a form's photo slot holds: nothing, a photo already stored on the
/// server, or a file picked on this device that uploads when the form saves.
///
/// Forms keep the picked file and upload it as the first step of Save (inside
/// the save `try`/`catch`), so the preview is immediate, nothing is uploaded
/// for a form the user abandons, and a failed save can simply be retried.
@immutable
class PhotoSelection {
  const PhotoSelection._({this.localFile, this.remoteRef, this.previewUrl});

  /// No photo.
  const PhotoSelection.none() : this._();

  /// A photo the server already stores. [ref] is what the API persists (a
  /// gallery photo id or an avatar object path); [previewUrl] is a signed
  /// read URL for display.
  const PhotoSelection.remote({required String ref, String? previewUrl})
    : this._(remoteRef: ref, previewUrl: previewUrl);

  /// A file picked on this device that has not been uploaded yet.
  const PhotoSelection.local(XFile file) : this._(localFile: file);

  /// A stored photo from a nullable API value; blank means [PhotoSelection.none].
  factory PhotoSelection.fromStored(String? ref, {String? previewUrl}) {
    final trimmed = ref?.trim();
    if (trimmed == null || trimmed.isEmpty) return const PhotoSelection.none();
    return PhotoSelection.remote(ref: trimmed, previewUrl: previewUrl);
  }

  /// A picked file, or [PhotoSelection.none] when the picker was cancelled.
  factory PhotoSelection.fromPicked(XFile? file) =>
      file == null ? const PhotoSelection.none() : PhotoSelection.local(file);

  final XFile? localFile;
  final String? remoteRef;
  final String? previewUrl;

  bool get hasPhoto => localFile != null || remoteRef != null;

  /// A picked file that still has to be uploaded before the form can save.
  bool get needsUpload => localFile != null && remoteRef == null;

  /// The local file was uploaded as [ref]. The file is kept so the preview
  /// does not flash while the server processes the photo.
  PhotoSelection uploaded(String ref) =>
      PhotoSelection._(localFile: localFile, remoteRef: ref);

  /// Same stored photo with a fresh signed read URL.
  PhotoSelection withPreviewUrl(String? url) => PhotoSelection._(
    localFile: localFile,
    remoteRef: remoteRef,
    previewUrl: url,
  );

  @override
  bool operator ==(Object other) =>
      other is PhotoSelection &&
      other.localFile?.path == localFile?.path &&
      other.remoteRef == remoteRef &&
      other.previewUrl == previewUrl;

  @override
  int get hashCode => Object.hash(localFile?.path, remoteRef, previewUrl);
}
