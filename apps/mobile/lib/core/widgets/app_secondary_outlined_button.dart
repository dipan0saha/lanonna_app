import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import '../theme/la_nonna_theme.dart';

/// Secondary / cancel outlined button — readable border and label (prototype parity).
class AppSecondaryOutlinedButton extends StatelessWidget {
  const AppSecondaryOutlinedButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool expand;

  static ButtonStyle style(BuildContext context) {
    final labelStyle = context.textStyles.labelLarge?.copyWith(
      color: AppColors.textPrimary,
      fontWeight: FontWeight.w600,
    );
    return OutlinedButton.styleFrom(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.textPrimary,
      minimumSize: const Size(88, AppMetrics.buttonMinHeight),
      padding: const EdgeInsets.symmetric(
        horizontal: AppMetrics.buttonHorizontalPadding,
        vertical: AppMetrics.buttonVerticalPadding,
      ),
      side: const BorderSide(color: AppColors.border),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppMetrics.buttonRadius),
      ),
      textStyle: labelStyle,
    );
  }

  @override
  Widget build(BuildContext context) {
    final button = OutlinedButton(
      style: style(context),
      onPressed: onPressed,
      child: Text(label),
    );
    if (!expand) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}
