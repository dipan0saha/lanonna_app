import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Clears in-memory Flutter images and disk cache used by [CachedSignedImage].
Future<void> evictSignedImageCaches() async {
  final imageCache = PaintingBinding.instance.imageCache;
  imageCache.clear();
  imageCache.clearLiveImages();
  await DefaultCacheManager().emptyCache();
}
