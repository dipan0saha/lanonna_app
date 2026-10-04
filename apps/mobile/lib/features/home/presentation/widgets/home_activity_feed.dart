import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/activity/activity_feed_card.dart';
import '../../data/models/home_summary.dart';
import '../../domain/app_routes.dart';
import 'home_section_label.dart';

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showSectionHeader)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Expanded(child: HomeSectionLabel('Activity Recap')),
                if (showViewAll)
                  TextButton(
                    onPressed: () => context.push(
                      AppRoutes.homeActivity(babyId),
                    ),
                    child: const Text('View all'),
                  ),
              ],
            ),
          ),
        ActivityFeedCard(
          items: items,
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ),
        const SizedBox(height: 18),
      ],
    );
  }
}
