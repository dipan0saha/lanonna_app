import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../home/data/home_repository.dart';
import '../../home/data/selected_baby_store.dart';
import '../../home/presentation/baby_context_reload.dart';
import '../data/calendar_repository.dart';
import '../data/models/calendar_models.dart';
import '../../../core/time/app_date_time.dart';
import '../domain/calendar_routes.dart';
import 'widgets/event_date_chip.dart';

class CalendarUpcomingScreen extends StatefulWidget {
  const CalendarUpcomingScreen({super.key});

  @override
  State<CalendarUpcomingScreen> createState() => _CalendarUpcomingScreenState();
}

class _CalendarUpcomingScreenState extends State<CalendarUpcomingScreen>
    with BabyContextReload {
  List<CalendarEvent> _events = [];
  var _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    context.read<CalendarRepository>().addListener(_onEventsChanged);
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    registerBabyContextListeners();
  }

  @override
  void dispose() {
    disposeBabyContextListeners();
    context.read<CalendarRepository>().removeListener(_onEventsChanged);
    super.dispose();
  }

  @override
  void onBabyContextReload() => _load();

  void _onEventsChanged() => _load();

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final homeRepo = context.read<HomeRepository>();
      final store = context.read<SelectedBabyStore>();
      final baby = await homeRepo.resolveSelectedBaby(store);
      if (baby == null) {
        setState(() {
          _events = [];
          _loading = false;
        });
        return;
      }
      if (!mounted) return;
      final events = await context.read<CalendarRepository>().listEvents(
            baby.id,
            upcoming: true,
          );
      setState(() {
        _events = events;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Could not load events. Pull to refresh or try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upcoming events')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? ListView(
                children: [
                  const SizedBox(height: 120),
                  const Center(child: CircularProgressIndicator()),
                ],
              )
            : _error != null
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  )
                : _events.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 120),
                          Center(child: Text('No upcoming events')),
                        ],
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: _events.length,
                        itemBuilder: (context, i) {
                          final event = _events[i];
                          return ListTile(
                            leading: EventDateChip(startsAt: event.startsAt),
                            title: Text(event.title),
                            subtitle: Text(
                              formatEventListDateTime(
                                event.startsAt,
                                Localizations.localeOf(context).toString(),
                              ),
                            ),
                            onTap: () => context.push(
                              CalendarRoutes.eventDetail(event.id),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
