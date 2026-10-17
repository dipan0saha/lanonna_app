import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_metrics.dart';
import '../../../../core/widgets/activity/activity_feed_card.dart';
import '../../data/models/home_summary.dart';
import '../../domain/app_routes.dart';
import 'home_scroll_section.dart';
import 'home_section_trailing.dart';
import '../../../../l10n/app_localizations.dart';

class HomeActivityFeed extends StatelessWidget {
  const HomeActivityFeed({
    super.key,
    required this.items,
    required this.babyId,
    this.showViewAll = true,
    this.showSectionHeader = true,
    this.showEmptyPlaceholder = false,
    this.emptyMessage,
  });

  final List<HomeActivityItem> items;
  final String babyId;
  final bool showViewAll;
  final bool showSectionHeader;
  final bool showEmptyPlaceholder;
  final String? emptyMessage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (items.isEmpty && !showEmptyPlaceholder) {
      return const SizedBox.shrink();
    }

    final isEmpty = items.isEmpty;
    final body = ActivityFeedCard(
      items: items,
      showEmptyState: isEmpty,
      emptyMessage: emptyMessage,
      padding: EdgeInsets.symmetric(horizontal: AppMetrics.horizontalPadding),
    );

    if (!showSectionHeader) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          body,
          const SizedBox(height: AppMetrics.sectionBlockSpacing),
        ],
      );
    }

    return HomeScrollSection(
      title: l10n.labelRecentActivity,
      trailing: showViewAll && !isEmpty
          ? HomeSectionLink(
              label: l10n.actionView,
              onPressed: () => context.push(AppRoutes.homeActivity(babyId)),
            )
          : null,
      body: body,
    );
  }
}
