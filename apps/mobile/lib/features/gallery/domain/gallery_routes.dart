abstract final class GalleryRoutes {
  static const gallery = '/gallery';
  static const recent = '/gallery/recent';
  static const favorites = '/gallery/favorites';
  static String photoDetail(String photoId, {String sort = 'default'}) {
    final path = '/gallery/photo/$photoId';
    if (sort == 'default') return path;
    return '$path?sort=${Uri.encodeComponent(sort)}';
  }
}
