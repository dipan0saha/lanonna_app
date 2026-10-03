import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_metrics.dart';
import '../../../../core/theme/la_nonna_theme.dart';
import '../../data/models/home_summary.dart';
import 'home_section_label.dart';

class OwnerGettingStartedCard extends StatelessWidget {
  const OwnerGettingStartedCard({
    super.key,
    required this.summary,
    required this.babyId,
  });

  final GettingStartedSummary summary;
  final String babyId;

  @override
  Widget build(BuildContext context) {
    if (summary.completedCount >= summary.total) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeSectionLabel(
          'Getting Started',
          trailing: '${summary.completedCount} / ${summary.total}',
        ),
        Container(
          margin: EdgeInsets.symmetric(horizontal: AppMetrics.horizontalPadding),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppMetrics.surfaceRadius),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              for (final task in summary.tasks)
                InkWell(
                  onTap: !task.done
                      ? () => _navigate(context, task.id, task.deepLink)
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    child: Row(
                      children: [
                        Icon(
                          task.done ? Icons.check_circle : Icons.circle_outlined,
                          size: 20,
                          color: task.done
                              ? AppColors.primaryDark
                              : AppColors.muted,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            task.label,
                            style: context.textStyles.bodyMedium?.copyWith(
                              color: task.done ? AppColors.muted : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
      ],
    );
  }

  void _navigate(BuildContext context, String taskId, String? path) {
    if (path != null && path.isNotEmpty) {
      context.push(path);
      return;
    }
    if (taskId == 'baby_profile') {
      context.push('/baby/$babyId/edit');
    }
  }
}
