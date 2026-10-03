import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../home/data/selected_baby_store.dart';
import '../data/calendar_repository.dart';
import '../data/models/calendar_models.dart';
import '../domain/calendar_routes.dart';
import 'widgets/event_date_chip.dart';

class CalendarUpcomingScreen extends StatefulWidget {
  const CalendarUpcomingScreen({super.key});

  @override
  State<CalendarUpcomingScreen> createState() => _CalendarUpcomingScreenState();
}

class _CalendarUpcomingScreenState extends State<CalendarUpcomingScreen> {
  List<CalendarEvent> _events = [];
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final babyId = context.read<SelectedBabyStore>().selectedBabyId;
    if (babyId == null) {
      setState(() => _loading = false);
      return;
    }
    final events = await context.read<CalendarRepository>().listEvents(
      babyId,
      upcoming: true,
    );
    setState(() {
      _events = events;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upcoming events')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _events.isEmpty
              ? const Center(child: Text('No upcoming events'))
              : ListView.builder(
                  itemCount: _events.length,
                  itemBuilder: (context, i) {
                    final event = _events[i];
                    return ListTile(
                      leading: EventDateChip(startsAt: event.startsAt),
                      title: Text(event.title),
                      subtitle: event.location != null && event.location!.isNotEmpty
                          ? Text(event.location!)
                          : null,
                      onTap: () => context.push(CalendarRoutes.eventDetail(event.id)),
                    );
                  },
                ),
    );
  }
}
