import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/la_nonna_theme.dart';

/// Secondary cancel action — readable sage/dark label (not faint grey).
class AppCancelTextButton extends StatelessWidget {
  const AppCancelTextButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  static ButtonStyle style(BuildContext context) {
    return TextButton.styleFrom(
      foregroundColor: AppColors.primaryDark,
      textStyle: context.textStyles.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: style(context),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}
