/// The cache key for an image URL, shared by the disk cache and the in-memory
/// image cache.
///
/// Signed GCS read URLs carry a new signature every time the API mints one,
/// but the object they point at never changes: photos are named by their id
/// (`display/<id>.<ext>`, `thumbnails/…`) and avatars by a new UUID per upload.
/// So a signed URL is keyed by its host and object path, and the same object
/// is cached once wherever it is shown. Any other URL is its own key.
String imageCacheKeyForUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasQuery) return url;
  if (uri.queryParameters['X-Goog-Signature'] == null) return url;
  return '${uri.host}${uri.path}';
}
