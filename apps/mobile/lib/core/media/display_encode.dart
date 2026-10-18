import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:lanonna/l10n/app_localizations.dart';

import '../api/localized_failure.dart';

/// FR-GAL-002 / platform-architecture §2.5 display asset policy.
///
/// Every photo the app uploads (gallery, event cover, announcement, onboarding
/// first moment, create baby, account and baby avatars) goes through
/// [encodeDisplayAssetInBackground]: decode, bake EXIF orientation, drop the
/// remaining camera metadata, fit the profile's long edge, then **one lossy
/// WebP encode** at [displayWebpQuality]. The 2 MB cap is a guard, not the
/// target: a photo only re-encodes when that one encode is over [maxBytes],
/// and then straight at the size its byte count predicts (no quality ladder).
class EncodedDisplayAsset {
  const EncodedDisplayAsset({
    required this.bytes,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final int width;
  final int height;

  /// Upload `Content-Type`; the API accepts `image/webp` and `image/jpeg`.
  String get contentType => contentTypeWebp;
}

/// Long edge the image picker and the [DisplayEncodeProfile.display] profile
/// cap photos at.
const int displayMaxLongEdge = 2048;

/// Long edge for avatars: the largest avatar draws at 104 dp, about 312 px on
/// a 3x screen.
const int avatarMaxLongEdge = 512;

/// Upload cap; must match the API (`storage.py`, `routers/photos.py`) and the
/// worker (`MAX_DISPLAY_BYTES`).
const int displayMaxBytes = 2_097_152;

/// Lossy WebP quality (0-100), the §2.5 "~80" display target.
const int displayWebpQuality = 80;

/// Lossy WebP effort (0-6). 2 keeps the rate-distortion search but skips the
/// trellis: about 3.5x faster than the default 4 for about 7% more bytes, the
/// right trade for an encode the user waits on.
const int displayWebpMethod = 2;

/// Below this long edge a photo that still misses the cap is rejected
/// rather than uploaded as a postage stamp.
const int _minLongEdge = 640;

/// Aim the re-encode this far under the cap, since bytes only roughly
/// follow pixel count.
const double _capHeadroom = 0.85;

const String contentTypeWebp = 'image/webp';

/// Size class of an upload; picks the long edge.
enum DisplayEncodeProfile {
  /// Gallery photos, event covers, announcement and first-moment photos.
  display(displayMaxLongEdge),

  /// Account and baby profile photos.
  avatar(avatarMaxLongEdge);

  const DisplayEncodeProfile(this.maxLongEdge);

  final int maxLongEdge;
}

/// [bytes] as whole or one-decimal megabytes (`2`, `1.5`) for user copy.
String megabytesLabel(int bytes) {
  final mb = bytes / (1024 * 1024);
  return mb == mb.roundToDouble() ? '${mb.round()}' : mb.toStringAsFixed(1);
}

/// Hint copy for photo-source sheets; follows [displayMaxBytes].
String displayPhotoSourceHint(AppLocalizations l10n) =>
    l10n.photoSourceHint(megabytesLabel(displayMaxBytes));

/// The photo cannot be encoded under the upload cap.
class PhotoTooLargeException implements LocalizedFailure {
  const PhotoTooLargeException(this.maxBytes);

  final int maxBytes;

  @override
  String userMessage(AppLocalizations l10n) =>
      l10n.errorPhotoTooLarge(megabytesLabel(maxBytes));

  @override
  String toString() => 'photo_too_large max_bytes=$maxBytes';
}

/// [encodeDisplayAsset] on a background isolate, so upload spinners keep
/// animating. This is the entry point for uploads.
Future<EncodedDisplayAsset> encodeDisplayAssetInBackground(
  Uint8List rawBytes,
  DisplayEncodeProfile profile,
) =>
    compute(_encodeOnIsolate, (rawBytes, profile));

EncodedDisplayAsset _encodeOnIsolate(
  (Uint8List, DisplayEncodeProfile) request,
) =>
    encodeDisplayAsset(request.$1, profile: request.$2);

/// Decode, orient, fit and encode [rawBytes] for a display upload.
///
/// Synchronous and CPU-heavy: call [encodeDisplayAssetInBackground] from UI
/// code. [maxBytes] exists for tests; uploads use [displayMaxBytes].
///
/// Throws [FormatException] when the bytes are not an image, and
/// [PhotoTooLargeException] when the photo misses [maxBytes] even at
/// [_minLongEdge] (or the profile's own edge, if smaller).
EncodedDisplayAsset encodeDisplayAsset(
  Uint8List rawBytes, {
  DisplayEncodeProfile profile = DisplayEncodeProfile.display,
  int maxBytes = displayMaxBytes,
}) {
  final decoded = img.decodeImage(rawBytes);
  if (decoded == null) {
    throw const FormatException('image_decode_failed');
  }
  final oriented = img.bakeOrientation(decoded)
    // Orientation is baked into the pixels; the rest (GPS, device, serial)
    // must not reach a photo shared with the family (§2.5).
    ..exif = img.ExifData();

  var longEdge = math.min(_longEdge(oriented), profile.maxLongEdge);
  while (true) {
    final image = _fitLongEdge(oriented, longEdge);
    final bytes = img.encodeWebP(
      image,
      lossless: false,
      quality: displayWebpQuality,
      method: displayWebpMethod,
    );
    if (bytes.length <= maxBytes) {
      return EncodedDisplayAsset(
        bytes: bytes,
        width: image.width,
        height: image.height,
      );
    }
    // Lossy WebP bytes scale roughly with pixel count, so one step lands
    // under the cap in practice; the loop only guards the estimate.
    final next =
        (longEdge * math.sqrt(maxBytes * _capHeadroom / bytes.length)).floor();
    if (next < math.min(_minLongEdge, profile.maxLongEdge) ||
        next >= longEdge) {
      throw PhotoTooLargeException(maxBytes);
    }
    longEdge = next;
  }
}

int _longEdge(img.Image image) => math.max(image.width, image.height);

img.Image _fitLongEdge(img.Image image, int longEdge) {
  if (_longEdge(image) <= longEdge) return image;
  return image.width >= image.height
      ? img.copyResize(
          image,
          width: longEdge,
          interpolation: img.Interpolation.average,
        )
      : img.copyResize(
          image,
          height: longEdge,
          interpolation: img.Interpolation.average,
        );
}
