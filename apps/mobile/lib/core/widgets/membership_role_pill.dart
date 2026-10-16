import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import '../theme/la_nonna_theme.dart';

/// OWNER / FOLLOWER badge (account + baby switcher).
class MembershipRolePill extends StatelessWidget {
  const MembershipRolePill({super.key, required this.isOwner});

  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppMetrics.appChipHorizontalPadding,
        vertical: AppMetrics.appChipDenseVerticalPadding,
      ),
      decoration: BoxDecoration(
        color: isOwner ? AppColors.peachTint : context.brand.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppMetrics.buttonRadius),
        border: Border.all(
          color: isOwner ? AppColors.secondaryDark : AppColors.border,
        ),
      ),
      child: Text(
        isOwner ? 'OWNER' : 'FOLLOWER',
        style: context.textStyles.labelSmall?.copyWith(
          color: isOwner ? AppColors.secondaryDark : AppColors.muted,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
