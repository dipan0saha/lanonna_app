import 'package:flutter/material.dart';

import '../../../../core/theme/app_metrics.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/app_date_time.dart';
import '../../data/models/calendar_models.dart';
import '../../domain/calendar_routes.dart';
import 'event_date_chip.dart';

class CalendarEventListTile extends StatelessWidget {
  const CalendarEventListTile({
    super.key,
    required this.event,
    this.showChevron = false,
    this.dense = false,
  });

  final CalendarEvent event;
  final bool showChevron;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final time = formatEventDetailWhen(event.startsAt, locale);
    final location = event.location?.trim();
    final subtitle = [
      if (time.isNotEmpty) time,
      if (location != null && location.isNotEmpty) location,
    ].join(' · ');

    return ListTile(
      contentPadding: EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: dense ? 0 : AppSpacing.xxs,
      ),
      leading: EventDateChip(startsAt: event.startsAt),
      title: Text(event.title),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      trailing: showChevron
          ? const Icon(
              Icons.chevron_right,
              color: AppColors.muted,
              size: AppMetrics.trailingIconSize,
            )
          : null,
      onTap: () => context.push(CalendarRoutes.eventDetail(event.id)),
    );
  }
}
