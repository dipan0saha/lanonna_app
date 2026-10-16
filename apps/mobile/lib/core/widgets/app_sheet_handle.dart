import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import '../theme/app_spacing.dart';

/// Grab handle at the top of modal bottom sheets (prototype `.sheet-handle`).
class AppSheetHandle extends StatelessWidget {
  const AppSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: AppMetrics.sheetHandleWidth,
        height: AppMetrics.sheetHandleHeight,
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(AppMetrics.sheetHandleHeight),
        ),
      ),
    );
  }
}
