import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/presentation/tab_load_failure.dart';
import '../../../core/presentation/tab_load_kind.dart';
import '../../../core/time/app_date_time.dart';
import '../../../core/widgets/app_icon_button.dart';
import '../../../core/widgets/app_semantics.dart';
import '../../../core/widgets/async_tab_body.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/theme/la_nonna_theme.dart';
import '../../home/data/home_repository.dart';
import '../../home/data/selected_baby_store.dart';
import '../../home/presentation/baby_context_reload.dart';
import '../../shell/presentation/shell_tab_layout.dart';
import '../../../core/domain/baby_summary.dart';
import '../data/calendar_repository.dart';
import '../data/models/calendar_models.dart';
import '../domain/calendar_event_lists.dart';
import '../domain/calendar_routes.dart';
import 'calendar_display.dart';
import 'event_form_screen.dart';
import 'widgets/calendar_event_list_tile.dart';
import 'widgets/calendar_selected_day_section.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen>
    with BabyContextReload {
  BabySummary? _baby;
  DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);
  List<CalendarEvent> _monthEvents = [];
  List<CalendarEvent> _today = [];
  List<CalendarEvent> _upcoming = [];
  DateTime? _selectedDay;
  var _loading = true;
  String? _loadError;
  CalendarRepository? _calendarRepo;

  @override
  void initState() {
    super.initState();
    _calendarRepo = context.read<CalendarRepository>();
    _calendarRepo!.addListener(_onEventsChanged);
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
    _calendarRepo?.removeListener(_onEventsChanged);
    super.dispose();
  }

  @override
  void onBabyContextReload() => _load();

  void _onEventsChanged() => _load();

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final homeRepo = context.read<HomeRepository>();
      final calRepo = context.read<CalendarRepository>();
      final store = context.read<SelectedBabyStore>();
      final baby = await homeRepo.resolveSelectedBaby(store);
      if (!mounted) return;
      if (baby == null) {
        setState(() {
          _baby = null;
          _monthEvents = [];
          _today = [];
          _upcoming = [];
          _loading = false;
        });
        return;
      }
      final now = DateTime.now();
      final visibleKey = calendarMonthKey(_visibleMonth);
      final currentKey = calendarMonthKey(now);
      final month = await calRepo.listEvents(baby.id, month: visibleKey);
      final upcomingApi = await calRepo.listEvents(baby.id, upcoming: true);
      final monthForToday = visibleKey == currentKey
          ? month
          : await calRepo.listEvents(baby.id, month: currentKey);
      final partition = partitionCalendarListEvents(
        monthEventsForToday: monthForToday,
        upcomingFromApi: upcomingApi,
        now: now,
      );
      if (!mounted) return;
      setState(() {
        _baby = baby;
        _monthEvents = month;
        _today = partition.today;
        _upcoming = partition.upcoming;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      final hadBaby = _baby != null;
      reportTabLoadFailure(
        context,
        e,
        hasPayload: hadBaby,
        onBlockingError: (message) {
          setState(() {
            _loadError = message;
            _loading = false;
          });
        },
      );
      if (hadBaby && mounted) {
        setState(() {
          _loadError = null;
          _loading = false;
        });
      }
    }
  }

  Future<void> _openCreateEvent({DateTime? onDate}) async {
    final created = await context.push<bool>(
      CalendarRoutes.createEvent,
      extra: onDate != null
          ? EventFormPrefill(title: '', description: '', initialDate: onDate)
          : null,
    );
    if (created == true && mounted) {
      await _load();
    }
  }

  void _onMonthDayTap(int day) {
    final tapped = DateTime(_visibleMonth.year, _visibleMonth.month, day);
    if (_selectedDay != null && isSameLocalCalendarDay(_selectedDay!, tapped)) {
      return;
    }
    setState(() => _selectedDay = tapped);
  }

  void _clearSelectedDay() {
    if (_selectedDay == null) return;
    setState(() => _selectedDay = null);
  }

  void _shiftMonth(int delta) {
    setState(() {
      _selectedDay = null;
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    });
    _load();
  }

  List<CalendarEvent> _eventsForSelectedDay() {
    final day = _selectedDay;
    if (day == null) return const [];
    return eventsOnLocalCalendarDay(_monthEvents, day);
  }

  bool get _isOwner => _baby?.role == 'owner';

  Set<int> _eventDays() {
    return _monthEvents
        .where((e) => eventOnLocalMonthDay(e.startsAt, _visibleMonth))
        .map((e) => eventLocalDayOfMonth(e.startsAt))
        .toSet();
  }

  @override
  Widget build(BuildContext context) {
    final styles = context.textStyles;
    final monthLabel =
        '${_monthName(_visibleMonth.month)} ${_visibleMonth.year}';
    final daysWithEvents = _eventDays();
    final kind = resolveTabLoadKind(
      loading: _loading,
      hasError: _loadError != null,
      hasPayload: _baby != null,
    );
    return Scaffold(
      backgroundColor: AppColors.background,
      body: ShellTabLayout(
        onRefresh: _load,
        body: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  AppMetrics.horizontalPadding,
                  0,
                  AppMetrics.horizontalPadding,
                  10,
                ),
                child: Text('Calendar', style: styles.headlineSmall),
              ),
            ),
            if (kind == TabLoadKind.loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (kind == TabLoadKind.error)
              SliverFillRemaining(
                child: AsyncTabBody(
                  loading: false,
                  error: _loadError,
                  onRetry: _load,
                  child: const SizedBox.shrink(),
                ),
              )
            else if (kind == TabLoadKind.empty)
              const SliverFillRemaining(
                child: Center(child: Text('No baby profile yet.')),
              )
            else ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              AppIconButton(
                                semanticsId: 'calendar_previous_month',
                                label: 'Previous month',
                                onPressed: () => _shiftMonth(-1),
                                icon: const Icon(Icons.chevron_left),
                              ),
                              Text(monthLabel, style: styles.titleMedium),
                              AppIconButton(
                                semanticsId: 'calendar_next_month',
                                label: 'Next month',
                                onPressed: () => _shiftMonth(1),
                                icon: const Icon(Icons.chevron_right),
                              ),
                            ],
                          ),
                          _MonthGrid(
                            month: _visibleMonth,
                            daysWithEvents: daysWithEvents,
                            selectedDay: _selectedDay,
                            onDayTap: _onMonthDayTap,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (_isOwner)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: InkWell(
                      onTap: () => context.push(CalendarRoutes.aiSuggestions),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.peachTint,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.auto_awesome_outlined),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Not sure where to start? See AI-suggested events by stage and age.',
                                style: styles.bodyMedium,
                              ),
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              if (_selectedDay != null)
                SliverToBoxAdapter(
                  child: CalendarSelectedDaySection(
                    selectedDay: _selectedDay!,
                    events: _eventsForSelectedDay(),
                    isOwner: _isOwner,
                    onClearSelection: _clearSelectedDay,
                    onAddEvent: () => _openCreateEvent(onDate: _selectedDay),
                  ),
                )
              else ...[
                if (_today.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Text(
                        'Today',
                        style:
                            styles.labelLarge?.copyWith(color: AppColors.muted),
                      ),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) =>
                          CalendarEventListTile(event: _today[index]),
                      childCount: _today.length,
                    ),
                  ),
                ],
                if (_today.isNotEmpty || _upcoming.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Text(
                        'Upcoming',
                        style:
                            styles.labelLarge?.copyWith(color: AppColors.muted),
                      ),
                    ),
                  ),
                if (_today.isEmpty && _upcoming.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Text('No events yet', style: styles.titleMedium),
                          const SizedBox(height: 8),
                          Text(
                            _isOwner
                                ? 'Add ultrasounds, showers, or the gender reveal so family knows when to celebrate.'
                                : 'Nothing on the calendar yet - check back soon.',
                            textAlign: TextAlign.center,
                            style: styles.bodyMedium?.copyWith(
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (_upcoming.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Text(
                        'No further upcoming events',
                        style: styles.bodyMedium?.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) =>
                          CalendarEventListTile(event: _upcoming[index]),
                      childCount: _upcoming.length,
                    ),
                  ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 96)),
            ],
          ],
        ),
      ),
      floatingActionButton: _isOwner && _baby != null
          ? AppSemantics.button(
              'calendar_create_fab',
              FloatingActionButton(
                onPressed: () => _openCreateEvent(),
                child: const Icon(Icons.add),
              ),
            )
          : null,
    );
  }

  String _monthName(int m) {
    const names = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return names[m - 1];
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.daysWithEvents,
    required this.selectedDay,
    required this.onDayTap,
  });

  final DateTime month;
  final Set<int> daysWithEvents;
  final DateTime? selectedDay;
  final ValueChanged<int> onDayTap;

  @override
  Widget build(BuildContext context) {
    final styles = context.textStyles;
    final now = DateTime.now();
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final startWeekday = first.weekday % 7;
    final cells = <Widget>[
      for (final label in ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
        Center(child: Text(label, style: styles.labelSmall)),
    ];
    for (var i = 0; i < startWeekday; i++) {
      cells.add(const SizedBox());
    }
    for (var day = 1; day <= daysInMonth; day++) {
      final hasEvent = daysWithEvents.contains(day);
      final cellDate = DateTime(month.year, month.month, day);
      final isToday =
          now.year == month.year && now.month == month.month && now.day == day;
      final isSelected = selectedDay != null &&
          isSameLocalCalendarDay(selectedDay!, cellDate);
      cells.add(
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onDayTap(day),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              decoration: BoxDecoration(
                color: isToday ? AppColors.primary : null,
                borderRadius: BorderRadius.circular(10),
                border: isSelected
                    ? Border.all(color: AppColors.primaryDark, width: 2)
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$day',
                    style: styles.labelSmall?.copyWith(
                      fontWeight: isToday ? FontWeight.w800 : null,
                      color: isToday
                          ? AppColors.primaryButtonForeground
                          : AppColors.textPrimary,
                    ),
                  ),
                  if (hasEvent)
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(top: 2),
                      decoration: BoxDecoration(
                        color: isToday
                            ? AppColors.primaryButtonForeground
                            : AppColors.primaryDark,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      primary: false,
      physics: const NeverScrollableScrollPhysics(),
      children: cells,
    );
  }
}
