import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_metrics.dart';
import '../../../../core/theme/la_nonna_theme.dart';
import '../../../calendar/domain/calendar_routes.dart';
import '../../data/models/home_summary.dart';
import 'home_section_label.dart';

class HomeNextUpCard extends StatelessWidget {
  const HomeNextUpCard({super.key, required this.event});

  final NextUpEvent event;

  @override
  Widget build(BuildContext context) {
    final dt = DateTime.tryParse(event.startsAt);
    final month = dt != null ? _month(dt.month) : '';
    final day = dt?.day.toString() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppMetrics.horizontalPadding),
          child: Row(
            children: [
              const Expanded(child: HomeSectionLabel('Next Up')),
              TextButton(
                onPressed: () => context.go(CalendarRoutes.calendar),
                child: const Text('View all'),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppMetrics.horizontalPadding),
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
                          Text(day, style: context.textStyles.titleSmall),
                          Text(
                            month.toUpperCase(),
                            style: context.textStyles.labelSmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(event.title, style: context.textStyles.titleSmall),
                          if (event.location != null && event.location!.isNotEmpty)
                            Text(
                              event.location!,
                              style: context.textStyles.bodySmall?.copyWith(
                                color: AppColors.muted,
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
        const SizedBox(height: 18),
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
