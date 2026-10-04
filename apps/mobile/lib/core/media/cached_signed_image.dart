import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

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
  });

  final String? imageUrl;
  final String? cacheKey;
  final double? width;
  final double? height;
  final BoxFit fit;
  final VoidCallback? onSignedUrlError;

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
    return CachedNetworkImage(
      imageUrl: url,
      cacheKey: widget.cacheKey ?? url,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      placeholder: (_, __) => SizedBox(
        width: widget.width,
        height: widget.height,
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
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
