@Tags(['benchmark'])
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lanonna/core/media/display_encode.dart';

import 'support/photo_fixture.dart';

/// Before vs after for the shared upload encoder (perf fix 1).
///
/// Runs both on the same 2048 x 1536 photo-like JPEG (what the image picker
/// hands back) and prints time, size and dimensions. Run it with
/// `flutter test --tags benchmark test/display_encode_benchmark_test.dart`.
/// The assertions are ratios, so they hold on any machine.
void main() {
  test('shared encoder vs the pre-fix encoder on a 2048 px photo', () {
    final raw = photoLikeJpeg();

    // Warm both paths once so JIT compilation is not timed.
    encodeDisplayAsset(photoLikeJpeg(width: 256, height: 192));
    _legacyEncode(photoLikeJpeg(width: 256, height: 192));

    final before = Stopwatch()..start();
    final legacy = _legacyEncode(raw);
    before.stop();

    final after = Stopwatch()..start();
    final encoded = encodeDisplayAsset(raw);
    after.stop();

    final legacyImage = img.decodeImage(legacy)!;
    // ignore: avoid_print
    print('display encode, 2048x1536 photo-like JPEG (${raw.length} B)\n'
        '  before: ${before.elapsedMilliseconds} ms, ${legacy.length} B, '
        '${legacyImage.width}x${legacyImage.height}\n'
        '  after:  ${after.elapsedMilliseconds} ms, ${encoded.bytes.length} B, '
        '${encoded.width}x${encoded.height}');

    expect((encoded.width, encoded.height), (2048, 1536));
    expect(legacyImage.width, lessThan(2048), reason: 'pre-fix downscaled');
    expect(encoded.bytes.length * 3, lessThan(legacy.length));
    expect(after.elapsedMicroseconds * 4, lessThan(before.elapsedMicroseconds));
  });
}

/// The encoder as it was before the fix (main at 2227241), kept only as the
/// benchmark baseline: `encodeWebP` is lossless by default, so `quality` did
/// nothing and each size step ran four identical lossless encodes.
Uint8List _legacyEncode(Uint8List rawBytes) {
  var image = img.bakeOrientation(img.decodeImage(rawBytes)!);
  if (image.width > 2048 || image.height > 2048) {
    image = image.width >= image.height
        ? img.copyResize(image, width: 2048)
        : img.copyResize(image, height: 2048);
  }
  final start = image.width > image.height ? image.width : image.height;
  final edges = [start, for (var e = 1600; e >= 800; e -= 400) if (e < start) e];
  for (final edge in edges) {
    final resized = edge == start
        ? image
        : image.width >= image.height
            ? img.copyResize(image, width: edge)
            : img.copyResize(image, height: edge);
    for (var q = 85; q >= 50; q -= 10) {
      final bytes = img.encodeWebP(resized, quality: q);
      if (bytes.length <= displayMaxBytes) return bytes;
    }
  }
  throw StateError('legacy encoder found no size under the cap');
}
