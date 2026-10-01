import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/la_nonna_theme.dart';
import '../../data/account_repository.dart';

class AccountEngagementStatRow extends StatelessWidget {
  const AccountEngagementStatRow({super.key, required this.stats});

  final UserEngagementStats stats;

  @override
  Widget build(BuildContext context) {
    final label = context.textStyles.labelSmall?.copyWith(color: AppColors.muted);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Row(
          children: [
            _cell(context, stats.photosSquished.toString(), 'Photos Squished', label),
            _cell(context, stats.eventsAttended.toString(), 'Events Attended', label),
            _cell(context, stats.itemsBought.toString(), 'Items Bought', label),
            _cell(context, stats.comments.toString(), 'Comments', label),
          ],
        ),
      ),
    );
  }

  Widget _cell(
    BuildContext context,
    String value,
    String caption,
    TextStyle? labelStyle,
  ) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: context.textStyles.titleMedium),
          const SizedBox(height: 4),
          Text(
            caption,
            textAlign: TextAlign.center,
            style: labelStyle,
          ),
        ],
      ),
    );
  }
}
