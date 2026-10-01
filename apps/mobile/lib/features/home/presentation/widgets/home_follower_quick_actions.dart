import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_metrics.dart';
import '../../../../core/theme/la_nonna_theme.dart';

class HomeFollowerQuickActions extends StatelessWidget {
  const HomeFollowerQuickActions({
    super.key,
    this.onVoteInFun,
    this.onViewGallery,
  });

  final VoidCallback? onVoteInFun;
  final VoidCallback? onViewGallery;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppMetrics.horizontalPadding,
        0,
        AppMetrics.horizontalPadding,
        18,
      ),
      child: Row(
        children: [
          Expanded(
            child: _QuickActionTile(
              icon: Icons.emoji_events_outlined,
              label: 'Vote in Fun',
              onTap: onVoteInFun,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _QuickActionTile(
              icon: Icons.photo_library_outlined,
              label: 'View Gallery',
              onTap: onViewGallery,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppMetrics.surfaceRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppMetrics.surfaceRadius),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppMetrics.surfaceRadius),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Icon(icon, size: 22, color: AppColors.primaryDark),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: context.textStyles.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
