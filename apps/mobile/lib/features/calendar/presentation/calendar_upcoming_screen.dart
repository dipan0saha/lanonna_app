import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../home/data/home_repository.dart';
import '../../home/data/selected_baby_store.dart';
import '../../home/presentation/baby_context_reload.dart';
import '../data/calendar_repository.dart';
import '../data/models/calendar_models.dart';
import '../domain/calendar_event_lists.dart';
import 'widgets/calendar_today_upcoming_list.dart';
import '../../../l10n/app_localizations.dart';

class CalendarUpcomingScreen extends StatefulWidget {
  const CalendarUpcomingScreen({super.key});

  @override
  State<CalendarUpcomingScreen> createState() => _CalendarUpcomingScreenState();
}

class _CalendarUpcomingScreenState extends State<CalendarUpcomingScreen>
    with BabyContextReload, TabLoadGenerationCache {
  List<CalendarEvent> _today = [];
  List<CalendarEvent> _upcoming = [];
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
    final store = context.read<SelectedBabyStore>();
    if (shouldShowTabLoadSpinner(
      store,
      hasDisplayedPayload: cachedLoadedBabyId != null,
    )) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final homeRepo = context.read<HomeRepository>();
      final baby = await homeRepo.resolveSelectedBaby(store);
      if (baby == null) {
        setState(() {
          _today = [];
          _upcoming = [];
          _loading = false;
        });
        cachedLoadedBabyId = null;
        cachedSelectionGeneration = -1;
        return;
      }
      if (!mounted) return;
      final calRepo = context.read<CalendarRepository>();
      final now = DateTime.now();
      final currentKey = calendarMonthKey(now);
      final monthForToday =
          await calRepo.listEvents(baby.id, month: currentKey);
      final upcomingApi = await calRepo.listEvents(baby.id, upcoming: true);
      final partition = partitionCalendarListEvents(
        monthEventsForToday: monthForToday,
        upcomingFromApi: upcomingApi,
        now: now,
      );
      setState(() {
        _today = partition.today;
        _upcoming = partition.upcoming;
        _loading = false;
      });
      rememberTabLoadGeneration(store, baby);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = AppLocalizations.of(context)!.calendarCouldNotLoadEventsPull;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.calendarUpcomingTitle)),
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
                : CalendarTodayUpcomingList(
                    today: _today,
                    upcoming: _upcoming,
                    emptyMessage: l10n.calendarNoUpcomingEvents,
                  ),
      ),
    );
  }
}
