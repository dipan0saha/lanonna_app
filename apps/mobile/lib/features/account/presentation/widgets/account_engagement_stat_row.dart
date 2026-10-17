import 'package:flutter/material.dart';
import 'package:lanonna/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_bordered_surface.dart';
import '../../../../core/theme/la_nonna_theme.dart';
import '../../data/account_repository.dart';

class AccountEngagementStatRow extends StatelessWidget {
  const AccountEngagementStatRow({super.key, required this.stats});

  final UserEngagementStats stats;

  @override
  Widget build(BuildContext context) {
    final label = context.textStyles.labelSmall?.copyWith(color: AppColors.muted);
    return AppBorderedSurface(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Row(
        children: [
          _cell(context, stats.photosSquished.toString(), AppLocalizations.of(context)!.accountPhotosSquished, label),
          _cell(context, stats.eventsAttended.toString(), AppLocalizations.of(context)!.accountEventsAttended, label),
          _cell(context, stats.itemsBought.toString(), AppLocalizations.of(context)!.accountItemsBought, label),
          _cell(context, stats.comments.toString(), AppLocalizations.of(context)!.calendarComments, label),
        ],
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
