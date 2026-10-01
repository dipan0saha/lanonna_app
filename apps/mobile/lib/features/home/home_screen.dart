import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../onboarding/data/models/baby_summary.dart';
import 'data/home_repository.dart';
import 'data/models/home_summary.dart';
import 'data/selected_baby_store.dart';
import 'domain/announce_arrival_input.dart';
import '../calendar/domain/calendar_routes.dart';
import '../registry/domain/registry_routes.dart';
import 'presentation/follower_home_composer.dart';
import 'presentation/owner_home_composer.dart';
import 'presentation/sheets/announce_arrival_sheet.dart';
import '../announcement/data/announcement_repository.dart';
import '../shell/presentation/shell_tab_layout.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  BabySummary? _baby;
  HomeSummary? _summary;
  String? _loadError;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repository = context.read<HomeRepository>();
    final store = context.read<SelectedBabyStore>();
    try {
      final babies = await repository.listBabies();
      final selectedId = store.selectedBabyId;
      BabySummary? baby;
      if (selectedId != null) {
        baby = babies.where((b) => b.id == selectedId).firstOrNull;
      }
      baby ??= babies.isNotEmpty ? babies.first : null;
      HomeSummary? summary;
      if (baby != null) {
        summary = await repository.fetchHomeSummary(baby.id);
      }
      setState(() {
        _baby = baby;
        _summary = summary;
        _loadError = null;
      });
    } catch (e) {
      setState(() => _loadError = e.toString());
    }
  }

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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Could not update baby: $e')),
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
        body: ListView(
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
              if (_baby != null && _isOwner)
                OwnerHomeComposer(
                  baby: _baby!,
                  summary: _summary,
                  daysToDueDate: _daysToDueDate(_baby!),
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
                  onVoteInFun: () => context.go('/gamification'),
                  onViewGallery: () => context.go('/gallery'),
                )
              else
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                ),
          ],
        ),
      ),
    );
  }
}
