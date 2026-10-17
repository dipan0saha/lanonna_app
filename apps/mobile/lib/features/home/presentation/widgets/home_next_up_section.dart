import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';

import '../../../../core/time/app_date_time.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_metrics.dart';
import '../../../../core/theme/la_nonna_theme.dart';
import '../../../calendar/domain/calendar_routes.dart';
import '../../data/models/home_summary.dart';
import 'home_scroll_section.dart';
import 'home_section_trailing.dart';
import '../../../../l10n/app_localizations.dart';

class HomeNextUpSection extends StatelessWidget {
  const HomeNextUpSection({super.key, required this.event});

  final NextUpEvent event;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (event.id.isEmpty) return const SizedBox.shrink();
    final text = context.textStyles;
    final locale = Localizations.localeOf(context).toString();
    final dt = event.startsAt;
    final month = dt != null ? formatEventMonthBadge(dt, locale) : '';
    final day = dt != null ? formatEventDayBadge(dt).toString() : '';
    final timeLocation = <String>[
      if (dt != null) formatEventDetailWhen(dt, locale),
      if (event.location != null && event.location!.trim().isNotEmpty)
        event.location!.trim(),
    ].join(' · ');

    return HomeScrollSection(
      title: l10n.actionNextUp,
      trailing: HomeSectionLink(
        label: l10n.actionView,
        onPressed: () => context.push(CalendarRoutes.upcoming),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppMetrics.horizontalPadding),
        child: InkWell(
          onTap: () => context.push(CalendarRoutes.eventDetail(event.id)),
          borderRadius: BorderRadius.circular(AppMetrics.surfaceRadius),
          child: Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: AppMetrics.nextUpDateBlockWidth,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.sageTint,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Text(day, style: text.titleSmall),
                        Text(month, style: text.labelSmall),
                      ],
                    ),
                  ),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(event.title, style: text.titleSmall),
                        if (timeLocation.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.xxs),
                            child: Text(
                              timeLocation,
                              style: text.bodySmall?.copyWith(
                                color: AppColors.muted,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
