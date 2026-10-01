import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_metrics.dart';
import '../../../../core/theme/la_nonna_theme.dart';

class HomeInsightCard extends StatelessWidget {
  const HomeInsightCard({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.tinted = true,
    this.activityLines = const [],
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool tinted;
  final List<String> activityLines;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final text = context.textStyles;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: AppMetrics.horizontalPadding),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: tinted ? brand.sageTint : brand.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppMetrics.surfaceRadius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: text.bodySmall?.copyWith(
                    color: tinted ? brand.insightOnSageTint : brand.shellIconMuted,
                  ),
                ),
                if (activityLines.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  for (final line in activityLines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        line,
                        style: text.labelMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: brand.shellIconMuted,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
          if (actionLabel != null) ...[
            const SizedBox(width: 12),
            Material(
              color: AppColors.primaryDark,
              borderRadius: BorderRadius.circular(999),
              child: InkWell(
                onTap: onAction,
                borderRadius: BorderRadius.circular(999),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Text(
                    actionLabel!,
                    style: text.labelMedium,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
