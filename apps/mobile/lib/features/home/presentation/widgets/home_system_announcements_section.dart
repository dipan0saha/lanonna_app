import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/router/deep_link_navigation.dart';
import '../../../../core/theme/app_metrics.dart';
import '../../data/home_repository.dart';
import '../../data/models/home_summary.dart';

class HomeSystemAnnouncementsSection extends StatelessWidget {
  const HomeSystemAnnouncementsSection({
    super.key,
    required this.items,
    required this.onDismissed,
  });

  final List<SystemAnnouncementItem> items;
  final VoidCallback onDismissed;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      children: items.map((item) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            AppMetrics.horizontalPadding,
            0,
            AppMetrics.horizontalPadding,
            8,
          ),
          child: MaterialBanner(
            content: Text(item.body),
            leading: const Icon(Icons.campaign_outlined),
            actions: [
              if (item.ctaLabel != null &&
                  item.ctaDeepLink != null &&
                  item.ctaDeepLink!.isNotEmpty)
                TextButton(
                  onPressed: () => navigateAppDeepLink(context, item.ctaDeepLink),
                  child: Text(item.ctaLabel!),
                ),
              TextButton(
                onPressed: () async {
                  await context
                      .read<HomeRepository>()
                      .dismissSystemAnnouncement(item.id);
                  onDismissed();
                },
                child: const Text('Dismiss'),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
