import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import '../theme/la_nonna_theme.dart';
import 'app_semantics.dart';
import 'gallery_social_glyphs.dart';

/// Outlined engagement chip (squish / comments) used on photo detail and announcement.
class AppEngagementPill extends StatelessWidget {
  const AppEngagementPill({
    super.key,
    required this.label,
    this.icon,
    this.glyph,
    this.onTap,
    this.active = false,
    this.semanticsId,
  });

  final String label;
  final IconData? icon;
  final Widget? glyph;
  final VoidCallback? onTap;
  final bool active;
  final String? semanticsId;

  @override
  Widget build(BuildContext context) {
    final child = Material(
      color: active ? AppColors.peachTint : AppColors.surface,
      borderRadius: BorderRadius.circular(AppMetrics.buttonRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppMetrics.buttonRadius),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppMetrics.compactPillHorizontalPadding,
            vertical: AppMetrics.compactPillVerticalPadding,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppMetrics.buttonRadius),
            border: Border.all(
              color: active ? AppColors.secondaryDark : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (glyph != null)
                glyph!
              else if (icon != null)
                Icon(
                  icon,
                  size: AppMetrics.keepsakeEngagementIconSize,
                  color: AppColors.primaryDark,
                ),
              SizedBox(width: AppSpacing.xs),
              Text(label, style: context.textStyles.labelSmall),
            ],
          ),
        ),
      ),
    );
    if (semanticsId != null) {
      return AppSemantics.button(semanticsId!, child, label: label);
    }
    return child;
  }
}

class AppSquishEngagementPill extends StatelessWidget {
  const AppSquishEngagementPill({
    super.key,
    required this.label,
    required this.onPressed,
    required this.active,
    this.semanticsId,
  });

  final String label;
  final VoidCallback onPressed;
  final bool active;
  final String? semanticsId;

  @override
  Widget build(BuildContext context) {
    return AppEngagementPill(
      label: label,
      glyph: GallerySquishGlyph(
        size: AppMetrics.keepsakeEngagementIconSize,
        color: active ? AppColors.secondaryDark : AppColors.primaryDark,
      ),
      onTap: onPressed,
      active: active,
      semanticsId: semanticsId,
    );
  }
}
