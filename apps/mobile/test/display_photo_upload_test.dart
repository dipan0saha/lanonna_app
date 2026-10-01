import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/api/display_photo_upload.dart';

void main() {
  test('signed PUT headers include GCS content-length range', () {
    final headers = DisplayPhotoUpload.signedPutHeadersForInit(
      {
        'required_headers': {'Content-Type': 'image/jpeg'},
        'max_bytes': 2097152,
      },
      'image/jpeg',
      1200,
    );

    expect(headers['Content-Type'], 'image/jpeg');
    expect(headers['x-goog-content-length-range'], '0,2097152');
  });

  test('signed PUT headers fall back when API omits range header', () {
    final headers = DisplayPhotoUpload.signedPutHeadersForInit(
      {'max_bytes': 1024},
      'image/webp',
      500,
    );

    expect(headers['x-goog-content-length-range'], '0,1024');
  });
}
