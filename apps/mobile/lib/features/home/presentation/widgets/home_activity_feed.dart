import 'package:flutter/material.dart';

import '../../../../core/theme/app_metrics.dart';
import '../../data/models/home_summary.dart';
import 'home_insight_card.dart';
import 'home_section_label.dart';

class HomeActivityFeed extends StatelessWidget {
  const HomeActivityFeed({super.key, required this.items});

  final List<HomeActivityItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const HomeSectionLabel('Recent Activity'),
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
