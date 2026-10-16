import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import '../theme/la_nonna_theme.dart';

/// Icon or emoji in a pale-green rounded square (prototype `.quick-action .ic`).
class TintedIconSquare extends StatelessWidget {
  const TintedIconSquare({
    super.key,
    this.icon,
    this.emoji,
    this.size = AppMetrics.tintedIconSquareSize,
    this.iconSize = AppMetrics.tintedIconSquareIconSize,
    this.backgroundColor,
  }) : assert(icon != null || emoji != null);

  /// Material icon; ignored when [emoji] is set.
  final IconData? icon;

  /// Emoji glyph shown instead of [icon] (e.g. notification types).
  final String? emoji;
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
      child: emoji != null
          ? Text(emoji!, style: context.textStyles.titleMedium)
          : Icon(icon, size: iconSize, color: AppColors.primaryDark),
    );
  }
}
