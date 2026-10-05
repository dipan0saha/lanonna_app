import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../features/gallery/domain/gallery_routes.dart';
import '../../../features/home/data/models/home_summary.dart';
import '../../theme/app_colors.dart';
import '../../theme/la_nonna_theme.dart';
import 'activity_event_icon.dart';
import 'activity_summary_text.dart';
import 'format_activity_when.dart';

class ActivityFeedCard extends StatelessWidget {
  const ActivityFeedCard({
    super.key,
    required this.items,
    this.showEmptyState = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  final List<HomeActivityItem> items;
  final bool showEmptyState;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty && !showEmptyState) {
      return const SizedBox.shrink();
    }

    final muted = context.textStyles.bodySmall?.copyWith(
      fontSize: 11,
      color: AppColors.muted,
    );

    return Padding(
      padding: padding,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          child: items.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    'Nothing yet - activity will show up here.',
                    textAlign: TextAlign.center,
                    style: context.textStyles.bodySmall?.copyWith(
                      fontSize: 12.5,
                      color: AppColors.muted,
                    ),
                  ),
                )
              : Column(
                  children: [
                    for (var i = 0; i < items.length; i++) ...[
                      _ActivityRow(
                        item: items[i],
                        timeStyle: muted,
                        onTap: items[i].photoId == null
                            ? null
                            : () => context.push(
                                  GalleryRoutes.photoDetail(items[i].photoId!),
                                ),
                      ),
                      if (i < items.length - 1)
                        const Divider(height: 1, color: AppColors.border),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.item,
    required this.timeStyle,
    this.onTap,
  });

  final HomeActivityItem item;
  final TextStyle? timeStyle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ActivityEventIcon(eventType: item.eventType),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ActivitySummaryText(
                  summary: item.summary,
                  actorDisplayName: item.actorDisplayName,
                ),
                const SizedBox(height: 2),
                Text(
                  formatActivityWhen(item.createdAt),
                  style: timeStyle,
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: content,
    );
  }
}
