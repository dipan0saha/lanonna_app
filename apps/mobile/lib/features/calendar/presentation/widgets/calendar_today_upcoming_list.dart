import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_metrics.dart';
import '../../../../core/theme/la_nonna_theme.dart';
import '../../data/models/calendar_models.dart';
import 'calendar_event_list_tile.dart';

/// Scrollable Today + Upcoming sections for view-all and similar screens.
class CalendarTodayUpcomingList extends StatelessWidget {
  const CalendarTodayUpcomingList({
    super.key,
    required this.today,
    required this.upcoming,
    required this.emptyMessage,
  });

  final List<CalendarEvent> today;
  final List<CalendarEvent> upcoming;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (today.isEmpty && upcoming.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          Center(child: Text(emptyMessage)),
        ],
      );
    }

    final styles = context.textStyles;
    final children = <Widget>[];

    if (today.isNotEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppMetrics.horizontalPadding,
            16,
            AppMetrics.horizontalPadding,
            8,
          ),
          child: Text(
            'Today',
            style: styles.labelLarge?.copyWith(color: AppColors.muted),
          ),
        ),
      );
      for (final event in today) {
        children.add(CalendarEventListTile(event: event));
      }
    }

    if (today.isNotEmpty || upcoming.isNotEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppMetrics.horizontalPadding,
            8,
            AppMetrics.horizontalPadding,
            8,
          ),
          child: Text(
            'Upcoming',
            style: styles.labelLarge?.copyWith(color: AppColors.muted),
          ),
        ),
      );
    }

    if (upcoming.isEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppMetrics.horizontalPadding,
            0,
            AppMetrics.horizontalPadding,
            24,
          ),
          child: Text(
            'No further upcoming events',
            style: styles.bodyMedium?.copyWith(color: AppColors.muted),
          ),
        ),
      );
    } else {
      for (final event in upcoming) {
        children.add(CalendarEventListTile(event: event));
      }
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: children,
    );
  }
}
