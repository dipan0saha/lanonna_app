import 'package:flutter/material.dart';
import 'package:lanonna/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_metrics.dart';
import '../../../../core/theme/la_nonna_theme.dart';
import '../../../../core/time/app_date_time.dart';
import '../../../../core/widgets/activity/feed_sentence.dart';
import '../../../../core/widgets/app_unread_dot.dart';
import '../../data/notifications_repository.dart';
import 'inbox_notification_visuals.dart';
import 'inbox_sentence.dart';

class InboxNotificationRow extends StatelessWidget {
  const InboxNotificationRow({super.key, required this.notification});

  final InboxNotification notification;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final visual = inboxNotificationVisualForType(notification.notificationType);
    final sentence = inboxSentence(l10n, notification);
    final bodyLine = _bodyLine(context, notification);

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
                FeedSentenceText(sentence: sentence),
                if (bodyLine != null) ...[
                  SizedBox(height: AppSpacing.hairline),
                  Text(
                    bodyLine,
                    style: context.textStyles.bodySmall?.copyWith(
                      color: AppColors.muted,
                      height: 1.35,
                    ),
                  ),
                ],
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

  String? _bodyLine(BuildContext context, InboxNotification notification) {
    final created = notification.createdAt;
    if (created == null) return null;
    return formatRelativeTime(
      AppLocalizations.of(context)!,
      created,
      localeNameForFormatting(context),
    );
  }
}
