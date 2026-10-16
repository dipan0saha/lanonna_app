import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_metrics.dart';
import '../../../../core/theme/la_nonna_theme.dart';
import '../../../../core/widgets/activity/activity_summary_text.dart';
import '../../../../core/widgets/app_unread_dot.dart';
import '../../data/notifications_repository.dart';
import 'inbox_notification_visuals.dart';

class InboxNotificationRow extends StatelessWidget {
  const InboxNotificationRow({super.key, required this.notification});

  final InboxNotification notification;

  @override
  Widget build(BuildContext context) {
    final visual = inboxNotificationVisual(
      deepLink: notification.deepLink,
      title: notification.title,
      body: notification.body,
    );
    final actor = inboxNotificationActorName(
      title: notification.title,
      body: notification.body,
    );
    final summary = notification.body.trim().isNotEmpty
        ? notification.body.trim()
        : notification.title.trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppMetrics.listRowBottomGap),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          inboxNotificationLeading(visual),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ActivitySummaryText(summary: summary, actorDisplayName: actor),
                if (notification.title.trim().isNotEmpty &&
                    notification.body.trim().isNotEmpty &&
                    actor != notification.title.trim())
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.hairline),
                    child: Text(
                      notification.title.trim(),
                      style: context.textStyles.labelSmall?.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (notification.readAt == null) ...[
            SizedBox(width: AppSpacing.sm),
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.xxs),
              child: AppUnreadDot(),
            ),
          ],
        ],
      ),
    );
  }
}
