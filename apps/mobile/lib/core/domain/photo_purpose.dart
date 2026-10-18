/// API `photos.purpose` for display uploads (`POST /v1/photos/init`).
enum PhotoPurpose {
  gallery('gallery'),
  eventCover('event_cover');

  const PhotoPurpose(this.apiValue);

  final String apiValue;

}
