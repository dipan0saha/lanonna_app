import 'package:flutter/material.dart';

import '../../../../core/media/cached_signed_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/la_nonna_theme.dart';
import '../../../../core/widgets/app_semantics.dart';
import '../../data/models/photo_models.dart';

class GalleryPhotoGrid extends StatelessWidget {
  const GalleryPhotoGrid({
    super.key,
    required this.photos,
    required this.onPhotoTap,
    this.onSignedUrlError,
  });

  final List<PhotoSummary> photos;
  final void Function(PhotoSummary photo) onPhotoTap;
  final VoidCallback? onSignedUrlError;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemCount: photos.length,
      itemBuilder: (context, index) {
        final photo = photos[index];
        final tile = GestureDetector(
          onTap: () => onPhotoTap(photo),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _GalleryThumb(
                  photo: photo,
                  onSignedUrlError: onSignedUrlError,
                ),
                if (photo.status == 'pending')
                  Container(
                    color: Colors.black38,
                    alignment: Alignment.center,
                    child: const Text(
                      'Processing…',
                      style: TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                if (photo.status != 'pending') ...[
                  if (photo.commentCount > 0)
                    Positioned(
                      left: 4,
                      bottom: 4,
                      child: _GalleryTileBadge(
                        icon: Icons.chat_bubble_outline,
                        count: photo.commentCount,
                      ),
                    ),
                  if (photo.squishCount > 0)
                    Positioned(
                      right: 4,
                      bottom: 4,
                      child: _GalleryTileBadge(
                        icon: Icons.back_hand_outlined,
                        count: photo.squishCount,
                      ),
                    ),
                ],
              ],
            ),
          ),
        );
        if (index == 0) {
          return AppSemantics.button('gallery_photo_first', tile);
        }
        return tile;
      },
    );
  }
}

class _GalleryTileBadge extends StatelessWidget {
  const _GalleryTileBadge({required this.icon, required this.count});

  final IconData icon;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: Colors.white),
          const SizedBox(width: 2),
          Text(
            '$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _GalleryThumb extends StatelessWidget {
  const _GalleryThumb({
    required this.photo,
    this.onSignedUrlError,
  });

  final PhotoSummary photo;
  final VoidCallback? onSignedUrlError;

  @override
  Widget build(BuildContext context) {
    final muted = context.textStyles.bodySmall?.copyWith(
      color: AppColors.muted,
      fontSize: 10,
    );
    final url = photo.thumbUrl;
    if (url != null && url.isNotEmpty) {
      return ColoredBox(
        color: AppColors.border,
        child: CachedSignedImage(
          imageUrl: url,
          cacheKey: 'thumb-${photo.id}',
          fit: BoxFit.cover,
          onSignedUrlError: onSignedUrlError,
        ),
      );
    }
    return ColoredBox(
      color: AppColors.border,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              photo.status == 'pending'
                  ? Icons.hourglass_empty
                  : Icons.image_not_supported_outlined,
              size: 22,
              color: AppColors.muted,
            ),
            if (photo.status != 'pending') ...[
              const SizedBox(height: 4),
              Text('Unavailable', style: muted, textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }
}
