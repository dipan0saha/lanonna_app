import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Clears in-memory Flutter images and disk cache used by [CachedSignedImage].
Future<void> evictSignedImageCaches() async {
  try {
    final imageCache = PaintingBinding.instance.imageCache;
    imageCache.clear();
    imageCache.clearLiveImages();
    await DefaultCacheManager().emptyCache();
  } catch (_) {
    // Best-effort on sign-out; cache plugins may be unavailable in tests.
  }
}
