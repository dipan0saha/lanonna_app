import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/media/display_encode.dart';

void main() {
  test('displayPhotoSourceHint reflects displayMaxBytes', () {
    expect(displayPhotoSourceHint(), 'JPEG or PNG, up to 2MB');
  });
}
