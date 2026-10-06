import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';

/// Bordered surface tile aligned with home hero / card chrome (FR-SHELL / #410).
///
/// Parent owns horizontal inset ([AppMetrics.subpageScrollPadding] on subpages,
/// or [AppMetrics.horizontalPadding] via [margin] on home sections).
class AppBorderedSurface extends StatelessWidget {
  const AppBorderedSurface({
    super.key,
    required this.child,
    this.padding,
    this.margin = const EdgeInsets.only(bottom: 8),
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppMetrics.surfaceRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}
