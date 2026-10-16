import 'package:flutter/material.dart';

import '../../../../core/theme/app_metrics.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/models/calendar_models.dart';
import 'calendar_event_list_tile.dart';

/// White card grouping event rows (prototype upcoming list).
class CalendarGroupedEventsCard extends StatelessWidget {
  const CalendarGroupedEventsCard({
    super.key,
    required this.events,
  });

  final List<CalendarEvent> events;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppMetrics.horizontalPadding),
      child: Card(
        margin: EdgeInsets.zero,
        child: Column(
          children: [
            for (var i = 0; i < events.length; i++) ...[
              CalendarEventListTile(
                event: events[i],
                showChevron: true,
                dense: true,
              ),
              if (i < events.length - 1)
                Divider(
                  height: 1,
                  indent: AppSpacing.lg,
                  endIndent: AppSpacing.lg,
                ),
            ],
          ],
        ),
      ),
    );
  }
}
