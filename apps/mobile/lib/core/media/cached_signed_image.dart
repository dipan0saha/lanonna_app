import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:octo_image/octo_image.dart';

import '../theme/app_colors.dart';
import 'display_sized_image.dart';
import 'image_cache_key.dart';

/// The provider for a network image shown in a slot of [logicalSize]: the
/// shared disk cache keyed by [imageCacheKeyForUrl], decoded at the slot's
/// size ([DisplaySizedImage]). The one place the app builds network image
/// providers, so the screen and any precache share one cache entry.
ImageProvider<Object> signedImageProvider(
  String url, {
  required Size logicalSize,
  required double devicePixelRatio,
  required BoxFit fit,
}) {
  return DisplaySizedImage.forSlot(
    CachedNetworkImageProvider(url, cacheKey: imageCacheKeyForUrl(url)),
    logicalSize: logicalSize,
    devicePixelRatio: devicePixelRatio,
    fit: fit,
  );
}

/// Downloads and decodes a signed image ahead of time for a slot of
/// [logicalSize], so a later [CachedSignedImage] of that size paints at once.
/// Best effort.
void precacheSignedImage(
  BuildContext context, {
  required String? imageUrl,
  required Size logicalSize,
  BoxFit fit = BoxFit.cover,
}) {
  if (imageUrl == null || imageUrl.isEmpty) return;
  unawaited(
    precacheImage(
      signedImageProvider(
        imageUrl,
        logicalSize: logicalSize,
        devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
        fit: fit,
      ),
      context,
      onError: (Object e, StackTrace? _) =>
          debugPrint('precache_signed_image_failed: $e'),
    ),
  );
}

/// The app's network image: disk-cached under the object's stable key (signed
/// URLs may change; the key does not) and decoded at the size it is shown.
///
/// Every network image (photos, thumbnails, covers, avatars) goes through
/// this widget; see `signedImageProvider` for the provider policy.
class CachedSignedImage extends StatefulWidget {
  const CachedSignedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.onSignedUrlError,
    this.placeholderImageUrl,
    this.placeholder,
    this.error,
    this.fadeInDuration = _defaultFadeIn,
    this.fadeOutDuration = _defaultFadeOut,
  });

  // The fades CachedNetworkImage applied before this widget rendered
  // OctoImage itself.
  static const _defaultFadeIn = Duration(milliseconds: 500);
  static const _defaultFadeOut = Duration(milliseconds: 1000);

  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final VoidCallback? onSignedUrlError;

  /// A smaller image (e.g. the cached thumbnail) shown while this one loads.
  final String? placeholderImageUrl;

  /// Shown while loading; defaults to the sage tint.
  final WidgetBuilder? placeholder;

  /// Shown when the image fails; defaults to a broken-image icon.
  final WidgetBuilder? error;
  final Duration fadeInDuration;
  final Duration fadeOutDuration;

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

  Widget _tint() => ColoredBox(
    color: AppColors.sageTint,
    child: SizedBox(width: widget.width, height: widget.height),
  );

  Widget _placeholder(BuildContext context) {
    final custom = widget.placeholder;
    if (custom != null) return custom(context);
    final url = widget.placeholderImageUrl;
    if (url == null || url.isEmpty) return _tint();
    return CachedSignedImage(
      imageUrl: url,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      placeholder: (_) => _tint(),
      error: (_) => _tint(),
    );
  }

  Widget _error(BuildContext context) {
    _handleError();
    final custom = widget.error;
    if (custom != null) return custom(context);
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: const Icon(Icons.broken_image_outlined),
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.imageUrl;
    if (url == null || url.isEmpty) {
      return SizedBox(width: widget.width, height: widget.height);
    }
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        // The size the image is laid out at: the requested size within the
        // parent's constraints (an unbounded side stays unbounded).
        final slot = constraints.constrain(
          Size(
            widget.width ?? double.infinity,
            widget.height ?? double.infinity,
          ),
        );
        return OctoImage(
          image: signedImageProvider(
            url,
            logicalSize: slot,
            devicePixelRatio: dpr,
            fit: widget.fit,
          ),
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          filterQuality: FilterQuality.low,
          fadeInDuration: widget.fadeInDuration,
          fadeOutDuration: widget.fadeOutDuration,
          placeholderBuilder: _placeholder,
          errorBuilder: (context, _, _) => _error(context),
        );
      },
    );
  }
}
