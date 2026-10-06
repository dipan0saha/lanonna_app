import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_metrics.dart';
import '../../../../core/theme/la_nonna_theme.dart';
import '../../data/models/home_summary.dart';
import 'home_scroll_section.dart';
import 'home_section_trailing.dart';

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
    return HomeScrollSection.bordered(
      title: 'Getting Started',
      trailing: HomeSectionMeta(
        text: '${summary.completedCount} / ${summary.total}',
      ),
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final task in summary.tasks)
            InkWell(
              onTap: !task.done
                  ? () => _navigate(context, task.id, task.deepLink)
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppMetrics.surfacePadding,
                  vertical: 12,
                ),
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
