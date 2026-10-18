import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Stable cache key for a gallery photo's thumbnail (signed URLs change on
/// every fetch; the key does not).
String photoThumbCacheKey(String photoId) => 'thumb-$photoId';

/// Stable cache key for a gallery photo's display-size image.
String photoDisplayCacheKey(String photoId) => 'display-$photoId';

/// Downloads and decodes a signed image ahead of time under [cacheKey], so a
/// later [CachedSignedImage] with the same key paints at once. Best effort.
void precacheSignedImage(
  BuildContext context, {
  required String? imageUrl,
  required String cacheKey,
}) {
  if (imageUrl == null || imageUrl.isEmpty) return;
  unawaited(
    precacheImage(
      CachedNetworkImageProvider(imageUrl, cacheKey: cacheKey),
      context,
      onError: (Object e, StackTrace? _) =>
          debugPrint('precache_signed_image_failed: $e'),
    ),
  );
}

/// Disk-cached network image for short-lived signed GCS read URLs.
class CachedSignedImage extends StatefulWidget {
  const CachedSignedImage({
    super.key,
    required this.imageUrl,
    this.cacheKey,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.onSignedUrlError,
    this.placeholderImageUrl,
    this.placeholderCacheKey,
  });

  final String? imageUrl;
  final String? cacheKey;
  final double? width;
  final double? height;
  final BoxFit fit;
  final VoidCallback? onSignedUrlError;

  /// A smaller image (e.g. the cached thumbnail) shown while this one loads.
  final String? placeholderImageUrl;
  final String? placeholderCacheKey;

  @override
  State<CachedSignedImage> createState() => _CachedSignedImageState();
}

class _CachedSignedImageState extends State<CachedSignedImage> {
  var _errorNotified = false;

  void _handleError() {
    if (_errorNotified || widget.onSignedUrlError == null) return;
    _errorNotified = true;
    widget.onSignedUrlError!();
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.imageUrl;
    if (url == null || url.isEmpty) {
      return SizedBox(width: widget.width, height: widget.height);
    }
    assert(() {
      if (widget.cacheKey == null &&
          url.contains('X-Goog-Signature') &&
          widget.onSignedUrlError != null) {
        debugPrint(
          'CachedSignedImage: signed URL without cacheKey (prefer stable id keys)',
        );
      }
      return true;
    }());
    return CachedNetworkImage(
      imageUrl: url,
      cacheKey: widget.cacheKey ?? url,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      placeholder: (_, _) {
        final placeholderUrl = widget.placeholderImageUrl;
        final tint = ColoredBox(
          color: AppColors.sageTint,
          child: SizedBox(width: widget.width, height: widget.height),
        );
        if (placeholderUrl == null || placeholderUrl.isEmpty) return tint;
        return CachedNetworkImage(
          imageUrl: placeholderUrl,
          cacheKey: widget.placeholderCacheKey ?? placeholderUrl,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          placeholder: (_, _) => tint,
          errorWidget: (_, _, _) => tint,
        );
      },
      errorWidget: (_, __, ___) {
        _handleError();
        return SizedBox(
          width: widget.width,
          height: widget.height,
          child: const Icon(Icons.broken_image_outlined),
        );
      },
    );
  }
}
