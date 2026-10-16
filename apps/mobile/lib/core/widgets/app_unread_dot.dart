import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';

/// Orange unread indicator (shell bell, inbox rows).
class AppUnreadDot extends StatelessWidget {
  const AppUnreadDot({super.key, this.size});

  final double? size;

  @override
  Widget build(BuildContext context) {
    final dotSize = size ?? AppMetrics.shellUnreadDotSize;
    return Container(
      width: dotSize,
      height: dotSize,
      decoration: BoxDecoration(
        color: AppColors.secondaryDark,
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.surface,
          width: AppMetrics.shellUnreadDotBorderWidth,
        ),
      ),
    );
  }
}
