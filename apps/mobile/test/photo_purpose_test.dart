import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/domain/photo_purpose.dart';

void main() {
  test('PhotoPurpose maps to API values', () {
    expect(PhotoPurpose.gallery.apiValue, 'gallery');
    expect(PhotoPurpose.eventCover.apiValue, 'event_cover');
  });
}
