import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/home_summary.dart';
import '../../domain/app_routes.dart';
import 'home_insight_card.dart';
import 'home_section_label.dart';

class HomeActivityFeed extends StatelessWidget {
  const HomeActivityFeed({
    super.key,
    required this.items,
    required this.babyId,
    this.showViewAll = true,
  });

  final List<HomeActivityItem> items;
  final String babyId;
  final bool showViewAll;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
        HomeInsightCard(
          tinted: false,
          message: 'Latest updates',
          activityLines: items.map((e) => e.summary).toList(),
        ),
        const SizedBox(height: 18),
      ],
    );
  }
}
