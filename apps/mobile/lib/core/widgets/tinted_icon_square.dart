import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import '../theme/la_nonna_theme.dart';

/// Quick-action icon in a pale-green rounded square (prototype `.quick-action .ic`).
class TintedIconSquare extends StatelessWidget {
  const TintedIconSquare({
    super.key,
    required this.icon,
    this.size = AppMetrics.tintedIconSquareSize,
    this.iconSize = AppMetrics.tintedIconSquareIconSize,
    this.backgroundColor,
  });

  final IconData icon;
  final double size;
  final double iconSize;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? context.brand.sageTint,
        borderRadius: BorderRadius.circular(AppMetrics.tintedIconSquareRadius),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: iconSize, color: AppColors.primaryDark),
    );
  }
}
