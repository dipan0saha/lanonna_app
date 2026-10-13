import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/time/app_date_time.dart';
import '../../data/models/calendar_models.dart';
import '../../domain/calendar_routes.dart';
import 'event_date_chip.dart';

class CalendarEventListTile extends StatelessWidget {
  const CalendarEventListTile({super.key, required this.event});

  final CalendarEvent event;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: EventDateChip(startsAt: event.startsAt),
      title: Text(event.title),
      subtitle: Text(
        formatEventListDateTime(
          event.startsAt,
          Localizations.localeOf(context).toString(),
        ),
      ),
      onTap: () => context.push(CalendarRoutes.eventDetail(event.id)),
    );
  }
}
