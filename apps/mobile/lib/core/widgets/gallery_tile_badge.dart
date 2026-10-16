import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import '../theme/la_nonna_theme.dart';

/// Squish / comment count overlay on gallery thumbnails.
class GalleryTileBadge extends StatelessWidget {
  const GalleryTileBadge({
    super.key,
    required this.glyph,
    required this.count,
    required this.semanticsLabel,
  });

  final Widget glyph;
  final int count;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final labelStyle = context.textStyles.labelSmall?.copyWith(
      color: AppColors.surface,
      letterSpacing: 0,
      fontWeight: FontWeight.w700,
      height: 1,
    );
    return Semantics(
      label: semanticsLabel,
      child: Container(
        padding: AppMetrics.galleryTileBadgePadding,
        decoration: BoxDecoration(
          color: AppColors.textPrimary.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(AppMetrics.galleryTileBadgeRadius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            glyph,
            SizedBox(width: AppSpacing.xxs - 1),
            Text('$count', style: labelStyle),
          ],
        ),
      ),
    );
  }
}
