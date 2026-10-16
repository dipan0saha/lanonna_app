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
    final style = context.textStyles.labelMedium?.copyWith(
      color: AppColors.primaryButtonForeground,
    );
    final child = Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(AppMetrics.buttonRadius),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppMetrics.buttonRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppMetrics.compactPillHorizontalPadding,
            vertical: AppMetrics.compactPillVerticalPadding,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showGiftEmoji) ...[
                ExcludeSemantics(child: Text('🎁', style: style)),
                SizedBox(width: AppSpacing.xxs),
              ],
              Flexible(
                child: Text(
                  label,
                  style: style,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
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
