import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_metrics.dart';
import '../../../../core/theme/la_nonna_theme.dart';
import '../../../calendar/domain/calendar_routes.dart';
import '../../data/models/home_summary.dart';
import 'home_section_header.dart';

class HomeUpcomingEventsSection extends StatelessWidget {
  const HomeUpcomingEventsSection({super.key, required this.events});

  final List<NextUpEvent> events;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const SizedBox.shrink();
    final text = context.textStyles;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeSectionHeader(
          title: 'Upcoming Events',
          action: TextButton(
            onPressed: () => context.push(CalendarRoutes.upcoming),
            child: const Text('View all'),
          ),
        ),
        ...events.map((event) {
          final dt = DateTime.tryParse(event.startsAt);
          final month = dt != null ? _month(dt.month) : '';
          final day = dt?.day.toString() ?? '';
          return Padding(
            padding: EdgeInsets.fromLTRB(
              AppMetrics.horizontalPadding,
              0,
              AppMetrics.horizontalPadding,
              8,
            ),
            child: InkWell(
              onTap: () => context.push(CalendarRoutes.eventDetail(event.id)),
              borderRadius: BorderRadius.circular(AppMetrics.surfaceRadius),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.sageTint,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          children: [
                            Text(day, style: text.titleSmall),
                            Text(month.toUpperCase(), style: text.labelSmall),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(event.title, style: text.titleSmall),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 10),
      ],
    );
  }

  String _month(int m) {
    const names = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return names[m - 1];
  }
}
