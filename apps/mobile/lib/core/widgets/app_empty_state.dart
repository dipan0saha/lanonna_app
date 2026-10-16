import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import '../theme/la_nonna_theme.dart';

/// Centred empty state: pale-green circle icon, dark title, optional CTA.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.expand = true,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final styles = context.textStyles;
    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: AppMetrics.emptyStateIconCircle,
          height: AppMetrics.emptyStateIconCircle,
          decoration: const BoxDecoration(
            color: AppColors.sageTint,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: AppMetrics.emptyStateIconSize,
            color: AppColors.primaryDark,
          ),
        ),
        const SizedBox(height: AppMetrics.emptyStateTitleGap),
        Text(title, textAlign: TextAlign.center, style: styles.titleSmall),
        if (message != null && message!.isNotEmpty) ...[
          const SizedBox(height: AppMetrics.emptyStateMessageGap),
          Text(message!, textAlign: TextAlign.center, style: styles.bodyMedium),
        ],
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: AppMetrics.emptyStateTitleGap),
          FilledButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ],
    );

    if (!expand) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppMetrics.horizontalPadding,
          vertical: 24,
        ),
        child: content,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppMetrics.emptyStateHorizontalInset,
      ),
      child: Center(child: content),
    );
  }
}
