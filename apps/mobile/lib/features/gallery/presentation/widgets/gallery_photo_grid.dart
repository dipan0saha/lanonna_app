import 'package:flutter/material.dart';
import 'package:lanonna/l10n/app_localizations.dart';

import '../../../../core/media/cached_signed_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_metrics.dart';
import '../../../../core/widgets/gallery_social_glyphs.dart';
import '../../../../core/widgets/gallery_tile_badge.dart';
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
    final l10n = AppLocalizations.of(context)!;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: AppMetrics.horizontalPadding),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: AppMetrics.galleryGridSpacing,
        mainAxisSpacing: AppMetrics.galleryGridSpacing,
      ),
      itemCount: photos.length,
      itemBuilder: (context, index) {
        final photo = photos[index];
        final tile = GestureDetector(
          onTap: () => onPhotoTap(photo),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppMetrics.galleryTileRadius),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _GalleryThumb(photo: photo, onSignedUrlError: onSignedUrlError),
                if (photo.status == 'pending')
                  Container(
                    color: Colors.black38,
                    alignment: Alignment.center,
                    child: Text(
                      l10n.photoProcessing,
                      style: context.textStyles.labelSmall?.copyWith(
                        color: AppColors.surface,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                if (photo.status != 'pending') ...[
                  if (photo.commentCount > 0)
                    Positioned(
                      left: AppMetrics.appChipDenseVerticalPadding + 1,
                      bottom: AppMetrics.appChipDenseVerticalPadding + 1,
                      child: GalleryTileBadge(
                        glyph: const GalleryCommentGlyph(),
                        count: photo.commentCount,
                        semanticsLabel: l10n.photoCommentCount(
                          photo.commentCount,
                        ),
                      ),
                    ),
                  if (photo.squishCount > 0)
                    Positioned(
                      right: AppMetrics.appChipDenseVerticalPadding + 1,
                      bottom: AppMetrics.appChipDenseVerticalPadding + 1,
                      child: GalleryTileBadge(
                        glyph: const GallerySquishGlyph(),
                        count: photo.squishCount,
                        semanticsLabel: l10n.photoSquishCount(
                          photo.squishCount,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        );
        final label =
            (photo.caption != null && photo.caption!.trim().isNotEmpty)
            ? photo.caption!.trim()
            : AppLocalizations.of(context)!.eventPhotoLabel;
        return AppSemantics.button(
          index == 0 ? 'gallery_photo_first' : 'gallery_photo_${photo.id}',
          tile,
          label: label,
        );
      },
    );
  }
}

class _GalleryThumb extends StatelessWidget {
  const _GalleryThumb({required this.photo, this.onSignedUrlError});

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
          cacheKey: photoThumbCacheKey(photo.id),
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
              size: AppMetrics.shellAddIconSize,
              color: AppColors.muted,
            ),
            if (photo.status != 'pending') ...[
              SizedBox(height: AppSpacing.xxs),
              Text(AppLocalizations.of(context)!.photoUnavailable, style: muted, textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }
}
