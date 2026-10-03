import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/theme/la_nonna_theme.dart';
import '../../home/data/home_repository.dart';
import '../../home/data/selected_baby_store.dart';
import '../../shell/presentation/shell_tab_layout.dart';
import '../../../core/domain/baby_summary.dart';
import '../data/calendar_repository.dart';
import '../data/models/calendar_models.dart';
import '../domain/calendar_routes.dart';
import 'widgets/event_date_chip.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  BabySummary? _baby;
  DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);
  List<CalendarEvent> _monthEvents = [];
  List<CalendarEvent> _upcoming = [];
  var _loading = true;

  @override
  void initState() {
    super.initState();
    context.read<CalendarRepository>().addListener(_onEventsChanged);
    _load();
  }

  @override
  void dispose() {
    context.read<CalendarRepository>().removeListener(_onEventsChanged);
    super.dispose();
  }

  void _onEventsChanged() => _load();

  String _monthKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final homeRepo = context.read<HomeRepository>();
      final calRepo = context.read<CalendarRepository>();
      final store = context.read<SelectedBabyStore>();
      final baby = await homeRepo.resolveSelectedBaby(store);
      if (baby == null) {
        setState(() {
          _baby = null;
          _loading = false;
        });
        return;
      }
      final month = await calRepo.listEvents(baby.id, month: _monthKey(_visibleMonth));
      final upcoming = await calRepo.listEvents(baby.id, upcoming: true);
      setState(() {
        _baby = baby;
        _monthEvents = month;
        _upcoming = upcoming;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  void _shiftMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    });
    _load();
  }

  bool get _isOwner => _baby?.role == 'owner';

  Set<int> _eventDays() {
    return _monthEvents
        .map((e) => DateTime(e.startsAt.year, e.startsAt.month, e.startsAt.day))
        .where((d) => d.year == _visibleMonth.year && d.month == _visibleMonth.month)
        .map((d) => d.day)
        .toSet();
  }

  @override
  Widget build(BuildContext context) {
    final styles = context.textStyles;
    final monthLabel =
        '${_monthName(_visibleMonth.month)} ${_visibleMonth.year}';
    final daysWithEvents = _eventDays();
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
              if (_loading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_baby == null)
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
                                IconButton(
                                  onPressed: () => _shiftMonth(-1),
                                  icon: const Icon(Icons.chevron_left),
                                ),
                                Text(monthLabel, style: styles.titleMedium),
                                IconButton(
                                  onPressed: () => _shiftMonth(1),
                                  icon: const Icon(Icons.chevron_right),
                                ),
                              ],
                            ),
                            _MonthGrid(
                              month: _visibleMonth,
                              daysWithEvents: daysWithEvents,
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
                                  'Not sure where to start? See AI-suggested events for this stage.',
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
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Text(
                      'Upcoming',
                      style: styles.labelLarge?.copyWith(color: AppColors.muted),
                    ),
                  ),
                ),
                if (_upcoming.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Text(
                            'No events yet',
                            style: styles.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _isOwner
                                ? 'Add ultrasounds, showers, or the gender reveal so family knows when to celebrate.'
                                : 'Nothing on the calendar yet — check back soon.',
                            textAlign: TextAlign.center,
                            style: styles.bodyMedium?.copyWith(
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final event = _upcoming[index];
                        return ListTile(
                          leading: EventDateChip(startsAt: event.startsAt),
                          title: Text(event.title),
                          subtitle: Text(_formatDateTime(event.startsAt)),
                          onTap: () => context.push(
                            CalendarRoutes.eventDetail(event.id),
                          ),
                        );
                      },
                      childCount: _upcoming.length,
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 96)),
              ],
            ],
          ),
        ),
      floatingActionButton: _isOwner && _baby != null
          ? FloatingActionButton(
              onPressed: () => context.push(CalendarRoutes.createEvent),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  String _monthName(int m) {
    const names = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return names[m - 1];
  }

  String _formatDateTime(DateTime dt) {
    return '${_monthName(dt.month)} ${dt.day}, ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.daysWithEvents,
  });

  final DateTime month;
  final Set<int> daysWithEvents;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final startWeekday = first.weekday % 7;
    final cells = <Widget>[
      for (final label in ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
        Center(child: Text(label, style: context.textStyles.labelSmall)),
    ];
    for (var i = 0; i < startWeekday; i++) {
      cells.add(const SizedBox());
    }
    for (var day = 1; day <= daysInMonth; day++) {
      final hasEvent = daysWithEvents.contains(day);
      cells.add(
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('$day'),
            if (hasEvent)
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppColors.primaryDark,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      );
    }
    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: cells,
    );
  }
}
