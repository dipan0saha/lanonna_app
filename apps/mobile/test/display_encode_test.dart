import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lanonna/core/media/display_encode.dart';

void main() {
  test('encodeDisplayAsset shrinks large image under max bytes', () {
    final huge = img.Image(width: 4000, height: 3000);
    img.fill(huge, color: img.ColorRgb8(120, 80, 200));
    final raw = Uint8List.fromList(img.encodeJpg(huge, quality: 95));

    final encoded = encodeDisplayAsset(raw);

    expect(encoded.bytes.length, lessThanOrEqualTo(displayMaxBytes));
    expect(
      encoded.contentType,
      anyOf(contentTypeWebp, contentTypeJpeg),
    );
    final out = img.decodeImage(encoded.bytes);
    expect(out, isNotNull);
    expect(out!.width <= displayMaxLongEdge || out.height <= displayMaxLongEdge,
        isTrue);
  });
}
