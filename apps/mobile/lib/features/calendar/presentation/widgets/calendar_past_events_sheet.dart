import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/widgets/app_modal_sheet.dart';
import '../../data/calendar_repository.dart';
import '../../data/models/calendar_models.dart';
import 'calendar_event_list_tile.dart';

Future<void> showCalendarPastEventsSheet(
  BuildContext context, {
  required String babyId,
}) async {
  await showAppModalSheet<void>(
    context: context,
    title: 'Past events',
    subtitle: 'Events that have already happened',
    bodyBuilder: (ctx) => _CalendarPastEventsBody(babyId: babyId),
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
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_events.isEmpty) {
      return const Text('No past events yet.');
    }
    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (final e in _events) CalendarEventListTile(event: e),
      ],
    );
  }
}
