import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_error_message.dart';
import '../../../core/input/app_text_input_kind.dart';
import '../../../core/media/cached_signed_image.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/app_text_field.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/prototype_subpage_scaffold.dart';
import '../../home/data/home_repository.dart';
import '../../home/data/selected_baby_store.dart';
import '../../../core/domain/baby_summary.dart';
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

  void _onCoverUrlError() {
    _load();
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
      AppSnackBar.showAlert(context, apiErrorMessage(e));
      returnToCalendar(context);
    }
  }

  void _showApiError(Object e) {
    if (!mounted) return;
    AppSnackBar.showAlert(context, apiErrorMessage(e));
  }

  bool get _isOwner => _baby?.role == 'owner';

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  String _formatWhen(DateTime startsAt, DateTime? endsAt) {
    const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final w = weekdays[startsAt.weekday - 1];
    final date =
        '$w, ${months[startsAt.month - 1]} ${startsAt.day}, ${startsAt.year}';
    final hour = startsAt.hour % 12 == 0 ? 12 : startsAt.hour % 12;
    final min = startsAt.minute.toString().padLeft(2, '0');
    final ap = startsAt.hour >= 12 ? 'PM' : 'AM';
    return '$date · $hour:$min $ap';
  }

  Future<void> _openVideo(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _showRsvpSheet(EventDetail detail) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('RSVPs', style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (detail.rsvpAttendees.isEmpty)
              const Text('No RSVPs yet')
            else
              for (final a in detail.rsvpAttendees)
                ListTile(
                  title: Text(a.displayName),
                  trailing: Text(a.status.replaceAll('_', ' ')),
                ),
          ],
        ),
      ),
    );
  }

  Future<void> _setRsvp(String status) async {
    final baby = _baby;
    if (baby == null) return;
    try {
      await context.read<CalendarRepository>().setRsvp(
        baby.id,
        widget.eventId,
        status,
      );
      await _load();
    } catch (e) {
      _showApiError(e);
    }
  }

  Future<void> _addComment() async {
    final text = AppTextInputPolicy.normalizeForSubmit(
      AppTextInputKind.prose,
      _commentController.text,
    );
    final baby = _baby;
    if (baby == null || text.isEmpty) return;
    try {
      await context.read<CalendarRepository>().addComment(
        baby.id,
        widget.eventId,
        text,
      );
      _commentController.clear();
      await _load();
    } catch (e) {
      _showApiError(e);
    }
  }

  Future<void> _editComment(EventComment comment) async {
    final baby = _baby;
    if (baby == null || !comment.isMine) return;
    final controller = TextEditingController(text: comment.body);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit comment'),
        content: AppTextField(
          kind: AppTextInputKind.prose,
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(hintText: 'Comment'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (saved != true) {
      controller.dispose();
      return;
    }
    final text = AppTextInputPolicy.normalizeForSubmit(
      AppTextInputKind.prose,
      controller.text,
    );
    controller.dispose();
    if (text.isEmpty) return;
    try {
      await context.read<CalendarRepository>().updateComment(
        baby.id,
        widget.eventId,
        comment.id,
        text,
      );
      await _load();
    } catch (e) {
      _showApiError(e);
    }
  }

  Future<void> _deleteComment(EventComment comment) async {
    final baby = _baby;
    if (baby == null || !comment.isMine) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete comment?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await context.read<CalendarRepository>().deleteComment(
        baby.id,
        widget.eventId,
        comment.id,
      );
      await _load();
    } catch (e) {
      _showApiError(e);
    }
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
    return PrototypeSubpageScaffold(
      includeShellTopBar: true,
      title: 'Event',
      actions: [
        if (_isOwner)
          IconButton(
            onPressed: () => context.push(CalendarRoutes.eventEdit(detail.id)),
            icon: const Icon(Icons.edit_outlined, size: 20),
          ),
        if (_isOwner)
          IconButton(
            onPressed: _deleteEvent,
            icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
          ),
      ],
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(detail.title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 12),
                Text('When', style: Theme.of(context).textTheme.labelLarge),
                Text(_formatWhen(detail.startsAt, detail.endsAt)),
                if (detail.location != null) ...[
                  const SizedBox(height: 12),
                  Text('Location', style: Theme.of(context).textTheme.labelLarge),
                  Text('📍 ${detail.location}'),
                ],
                if (detail.videoCallUrl != null) ...[
                  const SizedBox(height: 12),
                  Text('Video Call', style: Theme.of(context).textTheme.labelLarge),
                  TextButton(
                    onPressed: () => _openVideo(detail.videoCallUrl!),
                    child: const Text('Join video call'),
                  ),
                ],
                if (detail.coverPhotoDisplayUrl != null) ...[
                  const SizedBox(height: 12),
                  Text('Photo', style: Theme.of(context).textTheme.labelLarge),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedSignedImage(
                      imageUrl: detail.coverPhotoDisplayUrl,
                      cacheKey: detail.coverPhotoId != null
                          ? 'display-${detail.coverPhotoId}'
                          : null,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      onSignedUrlError: _onCoverUrlError,
                    ),
                  ),
                ],
                if (detail.description != null) ...[
                  const SizedBox(height: 12),
                  Text('Details', style: Theme.of(context).textTheme.labelLarge),
                  Text(detail.description!),
                ],
                const SizedBox(height: 16),
                Text('Your RSVP', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
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
                InkWell(
                  onTap: () => _showRsvpSheet(detail),
                  child: Row(
                    children: [
                      if (detail.rsvpAttendees.isNotEmpty)
                        SizedBox(
                          height: 28,
                          width: (detail.rsvpAttendees.length.clamp(0, 4) * 18.0) + 10,
                          child: Stack(
                            children: [
                              for (var i = 0; i < detail.rsvpAttendees.length && i < 4; i++)
                                Positioned(
                                  left: i * 18.0,
                                  child: CircleAvatar(
                                    radius: 14,
                                    backgroundColor: AppColors.sageTint,
                                    child: Text(
                                      _initials(detail.rsvpAttendees[i].displayName),
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      Expanded(
                        child: Text(
                          '${detail.rsvpSummary.going} going · ${detail.rsvpSummary.maybe} maybe — View RSVPs ›',
                          style: const TextStyle(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 24),
                const Text('Comments', style: TextStyle(fontWeight: FontWeight.bold)),
                for (final c in detail.comments)
                  ListTile(
                    title: Text(c.authorDisplayName),
                    subtitle: Text(c.body),
                    trailing: c.isMine
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 20),
                                onPressed: () => _editComment(c),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20),
                                onPressed: () => _deleteComment(c),
                              ),
                            ],
                          )
                        : null,
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
                    child: AppTextField(
                      kind: AppTextInputKind.prose,
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
