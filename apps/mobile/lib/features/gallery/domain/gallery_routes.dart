abstract final class GalleryRoutes {
  static const gallery = '/gallery';
  static const recent = '/gallery/recent';
  static const favorites = '/gallery/favorites';
  static String photoDetail(String photoId) => '/gallery/photo/$photoId';
}
