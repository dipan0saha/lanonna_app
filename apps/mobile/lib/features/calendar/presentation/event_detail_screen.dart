import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../home/data/home_repository.dart';
import '../../home/data/selected_baby_store.dart';
import '../../onboarding/data/models/baby_summary.dart';
import '../data/calendar_repository.dart';
import '../data/models/calendar_models.dart';
import '../domain/calendar_navigation.dart';
import '../domain/calendar_routes.dart';

class EventDetailScreen extends StatefulWidget {
  const EventDetailScreen({super.key, required this.eventId});

  final String eventId;

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  BabySummary? _baby;
  EventDetail? _detail;
  final _commentController = TextEditingController();
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final homeRepo = context.read<HomeRepository>();
      final store = context.read<SelectedBabyStore>();
      final baby = await homeRepo.resolveSelectedBaby(store);
      if (baby == null) {
        if (mounted) returnToCalendar(context);
        return;
      }
      final detail = await context
          .read<CalendarRepository>()
          .fetchEvent(baby.id, widget.eventId);
      setState(() {
        _baby = baby;
        _detail = detail;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      returnToCalendar(context);
    }
  }

  bool get _isOwner => _baby?.role == 'owner';

  Future<void> _setRsvp(String status) async {
    final baby = _baby;
    if (baby == null) return;
    await context.read<CalendarRepository>().setRsvp(
      baby.id,
      widget.eventId,
      status,
    );
    await _load();
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    final baby = _baby;
    if (baby == null || text.isEmpty) return;
    await context.read<CalendarRepository>().addComment(
      baby.id,
      widget.eventId,
      text,
    );
    _commentController.clear();
    await _load();
  }

  Future<void> _deleteEvent() async {
    final baby = _baby;
    if (baby == null || !_isOwner) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this event?'),
        content: const Text('Family will no longer see it on the calendar.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await context.read<CalendarRepository>().deleteEvent(baby.id, widget.eventId);
    if (mounted) returnToCalendar(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final detail = _detail;
    if (detail == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) returnToCalendar(context);
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(detail.title),
        actions: [
          if (_isOwner)
            IconButton(
              onPressed: () => context.push(CalendarRoutes.eventEdit(detail.id)),
              icon: const Icon(Icons.edit_outlined),
            ),
          if (_isOwner)
            IconButton(
              onPressed: _deleteEvent,
              icon: const Icon(Icons.delete_outline, color: AppColors.error),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (detail.description != null) Text(detail.description!),
                if (detail.location != null) Text('📍 ${detail.location}'),
                if (detail.videoCallUrl != null)
                  Text('Video: ${detail.videoCallUrl}'),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  children: [
                    _RsvpChip(
                      label: 'Going',
                      selected: detail.viewerRsvp == 'going',
                      onTap: () => _setRsvp('going'),
                    ),
                    _RsvpChip(
                      label: 'Maybe',
                      selected: detail.viewerRsvp == 'maybe',
                      onTap: () => _setRsvp('maybe'),
                    ),
                    _RsvpChip(
                      label: "Can't go",
                      selected: detail.viewerRsvp == 'cant_go',
                      onTap: () => _setRsvp('cant_go'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${detail.rsvpSummary.going} going · ${detail.rsvpSummary.maybe} maybe',
                ),
                const Divider(height: 24),
                const Text('Comments', style: TextStyle(fontWeight: FontWeight.bold)),
                for (final c in detail.comments)
                  ListTile(
                    title: Text(c.authorDisplayName),
                    subtitle: Text(c.body),
                  ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: const InputDecoration(hintText: 'Add a comment…'),
                      onSubmitted: (_) => _addComment(),
                    ),
                  ),
                  IconButton(onPressed: _addComment, icon: const Icon(Icons.send)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RsvpChip extends StatelessWidget {
  const _RsvpChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}
