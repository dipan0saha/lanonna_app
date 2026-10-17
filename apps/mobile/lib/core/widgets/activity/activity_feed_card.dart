import 'package:flutter/material.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../../../features/gallery/domain/gallery_routes.dart';
import '../../../features/home/data/models/home_summary.dart';
import '../app_semantics.dart';
import '../../theme/app_colors.dart';
import '../../time/app_date_time.dart';
import '../../theme/app_metrics.dart';
import '../../theme/la_nonna_theme.dart';
import 'activity_event_icon.dart';
import 'activity_sentence.dart';
import 'feed_sentence.dart';
import 'format_activity_when.dart';

class ActivityFeedCard extends StatelessWidget {
  const ActivityFeedCard({
    super.key,
    required this.items,
    this.showEmptyState = false,
    this.emptyMessage,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppMetrics.horizontalPadding,
    ),
  });

  final List<HomeActivityItem> items;
  final bool showEmptyState;
  final String? emptyMessage;
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
                    emptyMessage ??
                        AppLocalizations.of(context)!.activityEmptyDefault,
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
  const _ActivityRow({required this.item, required this.timeStyle, this.onTap});

  final HomeActivityItem item;
  final TextStyle? timeStyle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sentence = activitySentence(l10n, item);
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
                FeedSentenceText(sentence: sentence),
                const SizedBox(height: 2),
                Text(
                  formatActivityWhen(
                    l10n,
                    item.createdAt,
                    localeNameForFormatting(context),
                  ),
                  style: timeStyle,
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return content;
    final label = sentence.plainText.trim();
    return AppSemantics.button(
      'activity_${item.id}',
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: content,
      ),
      label: label.isEmpty ? l10n.activityTitle : label,
    );
  }
}
