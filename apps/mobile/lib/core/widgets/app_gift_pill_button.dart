import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import '../theme/la_nonna_theme.dart';
import 'app_semantics.dart';

/// Solid green gift CTA (registry "I'll buy this" / "Mark as purchased").
class AppGiftPillButton extends StatelessWidget {
  const AppGiftPillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.semanticsId,
    this.showGiftEmoji = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final String? semanticsId;
  final bool showGiftEmoji;

  @override
  Widget build(BuildContext context) {
    final text = showGiftEmoji ? '🎁 $label' : label;
    final child = Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(AppMetrics.buttonRadius),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppMetrics.buttonRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Text(
            text,
            style: context.textStyles.labelMedium?.copyWith(
              color: AppColors.primaryButtonForeground,
              fontSize: 12.5,
            ),
          ),
        ),
      ),
    );
    if (semanticsId != null) {
      return AppSemantics.button(semanticsId!, child, label: label);
    }
    return child;
  }
}
