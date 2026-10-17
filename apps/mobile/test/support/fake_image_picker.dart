import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

/// Replaces the platform image picker: every pick returns [nextPath], or
/// `null` (cancelled) when it is null. Records how many picks were made.
class FakeImagePickerPlatform extends ImagePickerPlatform {
  String? nextPath = '/tmp/picked_cover.jpg';
  int picks = 0;

  static FakeImagePickerPlatform install() {
    final fake = FakeImagePickerPlatform();
    ImagePickerPlatform.instance = fake;
    return fake;
  }

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    picks++;
    final path = nextPath;
    return path == null ? null : XFile(path);
  }
}
