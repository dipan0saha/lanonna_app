import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/features/gallery/domain/gallery_routes.dart';

void main() {
  test('adjacent navigation uses gallery photo detail route', () {
    expect(GalleryRoutes.photoDetail('abc'), '/gallery/photo/abc');
  });
}
