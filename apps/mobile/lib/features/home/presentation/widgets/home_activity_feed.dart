import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_metrics.dart';
import '../../../../core/widgets/activity/activity_feed_card.dart';
import '../../data/models/home_summary.dart';
import '../../domain/app_routes.dart';
import 'home_scroll_section.dart';
import 'home_section_trailing.dart';

class HomeActivityFeed extends StatelessWidget {
  const HomeActivityFeed({
    super.key,
    required this.items,
    required this.babyId,
    this.showViewAll = true,
    this.showSectionHeader = true,
  });

  final List<HomeActivityItem> items;
  final String babyId;
  final bool showViewAll;
  final bool showSectionHeader;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final body = ActivityFeedCard(
      items: items,
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
      title: 'Activity Recap',
      trailing: showViewAll
          ? HomeSectionLink(
              label: 'View all',
              onPressed: () => context.push(AppRoutes.homeActivity(babyId)),
            )
          : null,
      body: body,
    );
  }
}
