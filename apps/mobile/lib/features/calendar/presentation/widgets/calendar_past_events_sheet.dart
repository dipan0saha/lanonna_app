import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_metrics.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/calendar_repository.dart';
import '../../data/models/calendar_models.dart';
import 'calendar_event_list_tile.dart';

Future<void> showCalendarPastEventsSheet(
  BuildContext context, {
  required String babyId,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      return _CalendarPastEventsBody(babyId: babyId);
    },
  );
}

class _CalendarPastEventsBody extends StatefulWidget {
  const _CalendarPastEventsBody({required this.babyId});

  final String babyId;

  @override
  State<_CalendarPastEventsBody> createState() => _CalendarPastEventsBodyState();
}

class _CalendarPastEventsBodyState extends State<_CalendarPastEventsBody> {
  List<CalendarEvent> _events = [];
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final events = await context.read<CalendarRepository>().listEvents(
      widget.babyId,
      past: true,
    );
    if (!mounted) return;
    setState(() {
      _events = events;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppMetrics.horizontalPadding,
          AppSpacing.md,
          AppMetrics.horizontalPadding,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Past events', style: Theme.of(context).textTheme.titleSmall),
            SizedBox(height: AppSpacing.md),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_events.isEmpty)
              const Text('No past events yet.')
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final e in _events) CalendarEventListTile(event: e),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
