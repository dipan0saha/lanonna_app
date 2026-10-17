import 'package:image_picker/image_picker.dart';

import 'display_encode.dart';

/// Picks one photo with the display-asset policy shared by every photo form
/// and the gallery source sheet (long edge capped at [displayMaxLongEdge];
/// the upload still re-encodes through `encodeDisplayAsset`).
/// Returns `null` when the user cancels.
Future<XFile?> pickDisplayPhoto({ImageSource source = ImageSource.gallery}) {
  return ImagePicker().pickImage(
    source: source,
    maxWidth: displayMaxLongEdge.toDouble(),
    maxHeight: displayMaxLongEdge.toDouble(),
    imageQuality: 85,
  );
}
