import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lanonna/core/media/display_encode.dart';

import 'support/photo_fixture.dart';

/// RIFF chunk ids of a WebP file (`VP8 ` lossy, `VP8L` lossless, `EXIF`...).
List<String> webpChunks(Uint8List bytes) {
  expect(ascii.decode(bytes.sublist(0, 4)), 'RIFF');
  expect(ascii.decode(bytes.sublist(8, 12)), 'WEBP');
  final view = ByteData.sublistView(bytes);
  final chunks = <String>[];
  var offset = 12;
  while (offset + 8 <= bytes.length) {
    chunks.add(ascii.decode(bytes.sublist(offset, offset + 4)));
    final size = view.getUint32(offset + 4, Endian.little);
    offset += 8 + size + (size.isOdd ? 1 : 0);
  }
  return chunks;
}

Uint8List gradientJpeg(int width, int height, {img.ExifData? exif}) {
  final image = img.Image(width: width, height: height);
  for (final p in image) {
    p
      ..r = p.x * 255 ~/ width
      ..g = p.y * 255 ~/ height
      ..b = 128;
  }
  if (exif != null) image.exif = exif;
  return img.encodeJpg(image, quality: 90);
}

Uint8List noiseJpeg(int width, int height) {
  final rnd = math.Random(7);
  final image = img.Image(width: width, height: height);
  for (final p in image) {
    p
      ..r = rnd.nextInt(256)
      ..g = rnd.nextInt(256)
      ..b = rnd.nextInt(256);
  }
  return img.encodeJpg(image, quality: 95);
}

void main() {
  group('display profile', () {
    test('a picked camera photo is one lossy WebP at full size, well under '
        'the cap', () {
      final encoded = encodeDisplayAsset(photoLikeJpeg());

      expect(encoded.contentType, contentTypeWebp);
      expect(webpChunks(encoded.bytes), contains('VP8 '));
      expect(webpChunks(encoded.bytes), isNot(contains('VP8L')));
      expect((encoded.width, encoded.height), (2048, 1536));
      // §2.5: typical display asset ~400 KB-1.5 MB, never the 2 MB cap.
      expect(encoded.bytes.length, lessThan(1536 * 1024));
      final decoded = img.decodeWebP(encoded.bytes)!;
      expect((decoded.width, decoded.height), (2048, 1536));
    });

    test('fits a landscape photo to a 2048 px long edge', () {
      final encoded = encodeDisplayAsset(gradientJpeg(4032, 3024));
      expect((encoded.width, encoded.height), (2048, 1536));
    });

    test('fits a portrait photo to a 2048 px long edge', () {
      final encoded = encodeDisplayAsset(gradientJpeg(1512, 4032));
      expect((encoded.width, encoded.height), (768, 2048));
    });

    test('never upscales a small photo', () {
      final encoded = encodeDisplayAsset(gradientJpeg(800, 600));
      expect((encoded.width, encoded.height), (800, 600));
    });
  });

  test('avatar profile fits a 512 px long edge', () {
    final encoded = encodeDisplayAsset(
      photoLikeJpeg(width: 1024, height: 768),
      profile: DisplayEncodeProfile.avatar,
    );
    expect((encoded.width, encoded.height), (512, 384));
    expect(webpChunks(encoded.bytes), contains('VP8 '));
    expect(encoded.bytes.length, lessThan(100 * 1024));
  });

  test('bakes EXIF orientation into the pixels', () {
    final exif = img.ExifData()..imageIfd.orientation = 6; // rotate 90° CW
    final encoded = encodeDisplayAsset(gradientJpeg(400, 200, exif: exif));
    expect((encoded.width, encoded.height), (200, 400));
  });

  test('drops camera metadata such as GPS', () {
    final exif = img.ExifData()
      ..imageIfd['Make'] = img.IfdValueAscii('PhoneCo')
      ..gpsIfd['GPSLatitudeRef'] = img.IfdValueAscii('N');
    final raw = gradientJpeg(400, 300, exif: exif);
    expect(img.decodeJpg(raw)!.exif.isEmpty, isFalse, reason: 'fixture');

    final encoded = encodeDisplayAsset(raw);
    expect(webpChunks(encoded.bytes), isNot(contains('EXIF')));
  });

  group('upload cap', () {
    test('an over-cap encode re-encodes once at a smaller size, aspect kept',
        () {
      final raw = noiseJpeg(1600, 1200);
      final uncapped = encodeDisplayAsset(raw, maxBytes: 1 << 30);
      final cap = uncapped.bytes.length ~/ 2;

      final encoded = encodeDisplayAsset(raw, maxBytes: cap);
      expect(encoded.bytes.length, lessThanOrEqualTo(cap));
      expect(encoded.width, lessThan(1600));
      expect(encoded.width, greaterThanOrEqualTo(640));
      expect(encoded.width / encoded.height, closeTo(4 / 3, 0.01));
    });

    test('a photo that cannot meet the cap fails with PhotoTooLargeException',
        () {
      expect(
        () => encodeDisplayAsset(noiseJpeg(1200, 900), maxBytes: 4096),
        throwsA(isA<PhotoTooLargeException>()
            .having((e) => e.maxBytes, 'maxBytes', 4096)),
      );
    });

    test('the upload cap matches the API and worker (2 MiB)', () {
      expect(displayMaxBytes, 2 * 1024 * 1024);
    });
  });

  test('rejects bytes that are not an image', () {
    expect(
      () => encodeDisplayAsset(Uint8List.fromList(List.filled(64, 7))),
      throwsFormatException,
    );
  });

  test('encodeDisplayAssetInBackground runs the same encode off the UI '
      'isolate', () async {
    final raw = gradientJpeg(3000, 1000);
    final encoded = await encodeDisplayAssetInBackground(
      raw,
      DisplayEncodeProfile.avatar,
    );
    expect((encoded.width, encoded.height), (512, 171));
  });
}
