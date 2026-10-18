import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/domain/photo_purpose.dart';

void main() {
  test('PhotoPurpose round-trips API values', () {
    expect(PhotoPurpose.gallery.apiValue, 'gallery');
    expect(PhotoPurpose.eventCover.apiValue, 'event_cover');
    expect(PhotoPurpose.fromApi('event_cover'), PhotoPurpose.eventCover);
    expect(PhotoPurpose.fromApi(null), PhotoPurpose.gallery);
    expect(PhotoPurpose.fromApi('unknown'), PhotoPurpose.gallery);
  });
}
