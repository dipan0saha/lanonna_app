import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import '../theme/la_nonna_theme.dart';

/// Peach→sage gradient AI prompt (Calendar + Registry tabs).
class CalendarAiSuggestionBanner extends StatelessWidget {
  const CalendarAiSuggestionBanner({
    super.key,
    required this.message,
    required this.onTap,
  });

  final String message;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final body = context.textStyles.bodyMedium?.copyWith(
      color: AppColors.textPrimary,
      fontWeight: FontWeight.w600,
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppMetrics.horizontalPadding,
        AppSpacing.lg,
        AppMetrics.horizontalPadding,
        AppSpacing.lg,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppMetrics.aiBannerRadius),
          child: Ink(
            padding: AppMetrics.aiBannerPadding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppMetrics.aiBannerRadius),
              gradient: LinearGradient(
                colors: [brand.peachTint, brand.sageTint],
              ),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: AppMetrics.aiBannerIconChipSize,
                  height: AppMetrics.aiBannerIconChipSize,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(
                      AppMetrics.tintedIconSquareRadius,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.auto_awesome_outlined,
                    size: AppMetrics.tintedIconSquareIconSize,
                    color: AppColors.primaryDark,
                  ),
                ),
                SizedBox(width: AppSpacing.smMd),
                Expanded(child: Text(message, style: body)),
                Icon(
                  Icons.chevron_right,
                  color: context.brand.shellIconMuted,
                  size: AppMetrics.shellIconSize,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
