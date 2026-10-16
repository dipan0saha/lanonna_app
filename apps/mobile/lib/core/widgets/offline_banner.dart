import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import '../theme/la_nonna_theme.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.peachTint,
      child: SafeArea(
        bottom: false,
        child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppMetrics.horizontalPadding,
          8,
          AppMetrics.horizontalPadding,
          8,
        ),
        child: Text(
          "You're offline. Check your connection.",
          style: context.textStyles.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: context.brand.ownerBadgeText,
          ),
          textAlign: TextAlign.center,
        ),
        ),
      ),
    );
  }
}
