import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/domain/baby_summary.dart';
import '../../core/widgets/app_snackbar.dart';
import 'data/home_refresh_signal.dart';
import 'data/home_repository.dart';
import 'data/home_summary_result.dart';
import 'data/models/home_summary.dart';
import 'data/selected_baby_store.dart';
import 'domain/announce_arrival_input.dart';
import 'domain/app_routes.dart';
import '../calendar/domain/calendar_routes.dart';
import '../registry/domain/registry_routes.dart';
import 'presentation/follower_home_composer.dart';
import 'presentation/owner_home_composer.dart';
import 'presentation/sheets/announce_arrival_sheet.dart';
import '../announcement/data/announcement_repository.dart';
import '../onboarding/presentation/widgets/onboarding_buttons.dart';
import '../shell/presentation/shell_tab_layout.dart';
import '../../../core/api/api_error_message.dart';
import '../../core/network/connectivity_service.dart';
import '../../core/widgets/app_semantics.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  BabySummary? _baby;
  HomeSummary? _summary;
  String? _loadError;
  String? _summaryError;
  var _busy = false;
  var _loadComplete = false;
  SelectedBabyStore? _babyStore;
  HomeRefreshSignal? _homeRefresh;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = context.read<SelectedBabyStore>();
    if (_babyStore != store) {
      _babyStore?.removeListener(_onBabySelectionChanged);
      _babyStore = store;
      _babyStore!.addListener(_onBabySelectionChanged);
    }
    final refresh = context.read<HomeRefreshSignal>();
    if (_homeRefresh != refresh) {
      _homeRefresh?.removeListener(_onHomeRefreshRequested);
      _homeRefresh = refresh;
      _homeRefresh!.addListener(_onHomeRefreshRequested);
    }
  }

  @override
  void dispose() {
    _babyStore?.removeListener(_onBabySelectionChanged);
    _homeRefresh?.removeListener(_onHomeRefreshRequested);
    super.dispose();
  }

  void _onHomeRefreshRequested() {
    if (mounted) _load();
  }

  void _onBabySelectionChanged() {
    if (mounted) _load();
  }

  Future<void> _load() async {
    final repository = context.read<HomeRepository>();
    final store = context.read<SelectedBabyStore>();
    try {
      final baby = await repository.resolveSelectedBaby(store);
      HomeSummary? summary;
      String? summaryError;
      if (baby != null) {
        final result = await repository.fetchHomeSummary(baby.id);
        switch (result) {
          case HomeSummaryLoaded loaded:
            summary = loaded.summary;
          case HomeSummaryFailed failed:
            summaryError = _errorMessage(failed.error);
        }
      }
      setState(() {
        _baby = baby;
        _summary = summary;
        _summaryError = summaryError;
        _loadError = null;
        _loadComplete = true;
      });
    } catch (e) {
      final offline = !context.read<ConnectivityService>().isOnline;
      setState(() {
        if (offline && _baby != null) {
          _loadError = null;
        } else if (offline) {
          _loadError = 'Connect to the internet to load your family.';
        } else {
          _loadError = _errorMessage(e);
        }
        _loadComplete = true;
      });
    }
  }

  String _errorMessage(Object e) => apiErrorMessage(e);

  int? _daysToDueDate(BabySummary baby) {
    final fromSummary = _summary?.daysToDue;
    if (fromSummary != null) return fromSummary;
    final raw = baby.expectedBirthDate;
    if (raw == null) return null;
    final due = DateTime.tryParse(raw);
    if (due == null) return null;
    final today = DateTime.now();
    final dueDay = DateTime(due.year, due.month, due.day);
    final todayDay = DateTime(today.year, today.month, today.day);
    return dueDay.difference(todayDay).inDays;
  }

  bool get _isOwner => _baby?.role == 'owner';

  Future<void> _onAnnounceArrival() async {
    final baby = _baby;
    if (baby == null || _busy) return;
    await showAnnounceArrivalSheet(
      context,
      onConfirm: (date) async {
        setState(() => _busy = true);
        try {
          final updated = await context.read<HomeRepository>().updateBaby(
            baby.id,
            lifecycleStatus: 'born',
            actualBirthDate: formatApiBirthDate(date),
          );
          setState(() => _baby = updated);
          await _load();
          if (!mounted) return;
          final ann = await context.read<AnnouncementRepository>().fetch(baby.id);
          if (ann == null) {
            final goCreate = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Create announcement?'),
                content: const Text(
                  'Share a keepsake card with photo and birth details for family.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Later'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Create'),
                  ),
                ],
              ),
            );
            if (goCreate == true && mounted) {
              context.push('/baby/${baby.id}/announcement/create');
            }
          }
        } catch (e) {
          if (mounted) {
            AppSnackBar.showAlert(
              context,
              'Could not update baby: ${_errorMessage(e)}',
            );
          }
        } finally {
          if (mounted) setState(() => _busy = false);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ShellTabLayout(
        onRefresh: _load,
        body: AppSemantics.container(
          'home_section_list',
          ListView(
            key: const Key('home_section_list'),
            physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            if (_loadError != null)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    _loadError!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
            if (_summaryError != null && _baby != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: MaterialBanner(
                  content: Text(_summaryError!),
                  actions: [
                    TextButton(onPressed: _load, child: const Text('Retry')),
                  ],
                ),
              ),
              if (_baby != null && _isOwner)
                OwnerHomeComposer(
                  baby: _baby!,
                  summary: _summary,
                  daysToDueDate: _daysToDueDate(_baby!),
                  onRefresh: _load,
                  onAnnounceTap:
                      _baby!.lifecycleStatus == 'expecting' ? () => _onAnnounceArrival() : null,
                  onAddPhoto: () => context.go('/gallery'),
                  onAddEvent: () => context.push(CalendarRoutes.createEvent),
                  onRegistry: () => context.push(RegistryRoutes.createItem),
                )
              else if (_baby != null)
                FollowerHomeComposer(
                  baby: _baby!,
                  summary: _summary,
                  daysToDueDate: _daysToDueDate(_baby!),
                  onRefresh: _load,
                  onVoteInFun: () => context.go(AppRoutes.gamification),
                  onViewGallery: () => context.go('/gallery'),
                )
              else if (_loadComplete)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        'Add your first baby profile to get started.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      OnboardingPrimaryButton(
                        label: 'Add baby',
                        onPressed: () => context.push('/baby/create'),
                      ),
                    ],
                  ),
                )
              else
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                ),
          ],
          ),
        ),
      ),
    );
  }
}
