import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_metrics.dart';
import '../../../../core/theme/la_nonna_theme.dart';
import '../../../../core/time/app_date_time.dart';
import '../../data/models/calendar_models.dart';
import 'calendar_event_list_tile.dart';
import '../../../../l10n/app_localizations.dart';

/// Day-scoped list under the month grid when a calendar day is selected.
class CalendarSelectedDaySection extends StatelessWidget {
  const CalendarSelectedDaySection({
    super.key,
    required this.selectedDay,
    required this.events,
    required this.isOwner,
    required this.onClearSelection,
    required this.onAddEvent,
  });

  final DateTime selectedDay;
  final List<CalendarEvent> events;
  final bool isOwner;
  final VoidCallback onClearSelection;
  final VoidCallback onAddEvent;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final styles = context.textStyles;
    final locale = Localizations.localeOf(context).toString();
    final dateLabel = formatApiCalendarDateFromParts(selectedDay, locale);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppMetrics.horizontalPadding,
            8,
            8,
            8,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  dateLabel,
                  style: styles.labelLarge?.copyWith(color: AppColors.muted),
                ),
              ),
              TextButton(
                onPressed: onClearSelection,
                child: Text(AppLocalizations.of(context)!.actionShowAll),
              ),
            ],
          ),
        ),
        if (events.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppMetrics.horizontalPadding,
              8,
              AppMetrics.horizontalPadding,
              16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.emptyEventsDay,
                  style: styles.bodyMedium?.copyWith(color: AppColors.muted),
                ),
                if (isOwner) ...[
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: onAddEvent,
                    child: Text(AppLocalizations.of(context)!.calendarAddEvent),
                  ),
                ],
              ],
            ),
          )
        else
          for (final event in events) CalendarEventListTile(event: event),
      ],
    );
  }
}
