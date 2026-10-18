/// API `photos.purpose` for display uploads (`POST /v1/photos/init`).
enum PhotoPurpose {
  gallery('gallery'),
  eventCover('event_cover');

  const PhotoPurpose(this.apiValue);

  final String apiValue;

  static PhotoPurpose fromApi(String? raw) {
    for (final value in PhotoPurpose.values) {
      if (value.apiValue == raw) return value;
    }
    return PhotoPurpose.gallery;
  }
}
