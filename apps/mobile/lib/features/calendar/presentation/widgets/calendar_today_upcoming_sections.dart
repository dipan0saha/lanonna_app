import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_metrics.dart';
import '../../../../core/theme/la_nonna_theme.dart';
import '../../../../core/widgets/app_section_caps_label.dart';
import '../../domain/calendar_event_lists.dart';
import '../../../../l10n/app_localizations.dart';
import 'calendar_grouped_events_card.dart';

/// Shared Today + Upcoming sections for Calendar tab and view-all.
class CalendarTodayUpcomingSections extends StatelessWidget {
  const CalendarTodayUpcomingSections({
    super.key,
    required this.buckets,
    this.upcomingHeaderTrailing,
  });

  final CalendarEventBuckets buckets;
  final Widget? upcomingHeaderTrailing;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final styles = context.textStyles;
    final horizontal = AppMetrics.horizontalPadding;
    final children = <Widget>[];

    if (buckets.today.isNotEmpty) {
      children.add(
        Padding(
          padding: EdgeInsets.fromLTRB(
            horizontal,
            AppSpacing.sm,
            horizontal,
            0,
          ),
          child: AppSectionCapsLabel(l10n.labelToday),
        ),
      );
      children.add(
        // The grouped card applies the screen's horizontal padding itself.
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: CalendarGroupedEventsCard(events: buckets.today),
        ),
      );
    }

    // Shown when there is something to list, or when the caller puts an action
    // (Calendar tab: Past) in the header.
    if (!buckets.isEmpty || upcomingHeaderTrailing != null) {
      children.add(
        Padding(
          padding: EdgeInsets.fromLTRB(
            horizontal,
            AppSpacing.md,
            horizontal,
            AppSpacing.sm,
          ),
          child: upcomingHeaderTrailing == null
              ? AppSectionCapsLabel(l10n.labelUpcoming)
              : AppSectionCapsLabel(
                  l10n.labelUpcoming,
                  trailing: upcomingHeaderTrailing,
                ),
        ),
      );
    }

    if (buckets.upcoming.isEmpty && buckets.today.isNotEmpty) {
      children.add(
        Padding(
          padding: EdgeInsets.fromLTRB(
            horizontal,
            0,
            horizontal,
            AppSpacing.lg,
          ),
          child: Text(
            l10n.emptyFurtherUpcomingEvents,
            style: styles.bodyMedium?.copyWith(color: AppColors.muted),
          ),
        ),
      );
    } else if (buckets.upcoming.isNotEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          child: CalendarGroupedEventsCard(events: buckets.upcoming),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}
