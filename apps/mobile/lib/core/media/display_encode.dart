import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// FR-GAL-002 / platform-architecture §2.5 display asset policy.
class EncodedDisplayAsset {
  const EncodedDisplayAsset({
    required this.bytes,
    required this.contentType,
  });

  final Uint8List bytes;
  final String contentType;
}

const int displayMaxLongEdge = 2048;
const int displayMaxBytes = 2_097_152;

const String contentTypeWebp = 'image/webp';
const String contentTypeJpeg = 'image/jpeg';

/// Resize, orient, and encode for GCS display upload (WebP preferred, JPEG fallback).
EncodedDisplayAsset encodeDisplayAsset(Uint8List rawBytes) {
  final decoded = img.decodeImage(rawBytes);
  if (decoded == null) {
    throw FormatException('Could not decode image');
  }
  var image = img.bakeOrientation(decoded);
  image = _fitLongEdge(image, displayMaxLongEdge);

  final webp = _tryEncodeWebpUnderCap(image);
  if (webp != null) {
    return EncodedDisplayAsset(bytes: webp, contentType: contentTypeWebp);
  }

  final jpeg = _tryEncodeJpegUnderCap(image);
  if (jpeg != null) {
    return EncodedDisplayAsset(bytes: jpeg, contentType: contentTypeJpeg);
  }

  throw StateError('Could not encode image under $displayMaxBytes bytes');
}

img.Image _fitLongEdge(img.Image image, int maxLongEdge) {
  final w = image.width;
  final h = image.height;
  final long = w > h ? w : h;
  if (long <= maxLongEdge) return image;
  if (w >= h) {
    return img.copyResize(image, width: maxLongEdge);
  }
  return img.copyResize(image, height: maxLongEdge);
}

Uint8List? _tryEncodeWebpUnderCap(img.Image image) {
  for (final edge in _edgeSteps(image)) {
    final resized =
        edge == _longEdge(image) ? image : _resizeToLongEdge(image, edge);
    for (var q = 85; q >= 50; q -= 10) {
      final bytes = Uint8List.fromList(img.encodeWebP(resized, quality: q));
      if (bytes.length <= displayMaxBytes) return bytes;
    }
  }
  return null;
}

Uint8List? _tryEncodeJpegUnderCap(img.Image image) {
  for (final edge in _edgeSteps(image)) {
    final resized = edge == _longEdge(image)
        ? image
        : _resizeToLongEdge(image, edge);
    for (var q = 85; q >= 50; q -= 10) {
      final bytes = Uint8List.fromList(img.encodeJpg(resized, quality: q));
      if (bytes.length <= displayMaxBytes) return bytes;
    }
  }
  return null;
}

int _longEdge(img.Image image) =>
    image.width > image.height ? image.width : image.height;

img.Image _resizeToLongEdge(img.Image image, int longEdge) {
  if (image.width >= image.height) {
    return img.copyResize(image, width: longEdge);
  }
  return img.copyResize(image, height: longEdge);
}

List<int> _edgeSteps(img.Image image) {
  final start = _longEdge(image);
  final steps = <int>[start];
  for (var e = 1600; e >= 800; e -= 400) {
    if (e < start) steps.add(e);
  }
  return steps;
}
