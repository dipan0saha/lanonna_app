import 'package:flutter/material.dart';
import 'package:lanonna/core/domain/person_display_label.dart';
import 'package:lanonna/core/domain/rsvp_status.dart';

import 'package:lanonna/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../../../core/api/api_error_message.dart';
import '../../../core/platform/external_link_launcher.dart';
import '../../../core/comments/comment_actions.dart';
import '../../../core/comments/comment_composer_controller.dart';
import '../../../core/time/app_date_time.dart';
import '../../../core/presentation/detail_screen_load.dart';
import '../../../core/media/cached_signed_image.dart';
import '../../../core/widgets/app_rsvp_tile_row.dart';
import '../../../core/widgets/app_modal_sheet.dart';
import '../../../core/widgets/app_section_caps_label.dart';
import '../../../core/widgets/avatar_stack.dart';
import '../../../core/widgets/app_icon_button.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/detail_comment_composer.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/theme/la_nonna_theme.dart';
import '../../../core/widgets/prototype_subpage_scaffold.dart';
import '../../home/data/home_repository.dart';
import '../../home/data/selected_baby_store.dart';
import '../../../core/domain/baby_summary.dart';
import '../data/calendar_repository.dart';
import '../data/event_comment_thread.dart';
import '../data/models/calendar_models.dart';
import '../domain/calendar_navigation.dart';
import '../domain/calendar_routes.dart';

String _rsvpInlineSummary(AppLocalizations l10n, RsvpSummary summary) {
  final parts = <String>[];
  if (summary.going > 0) {
    parts.add(l10n.eventRsvpGoingCount(summary.going));
  }
  if (summary.maybe > 0) {
    parts.add(l10n.eventRsvpMaybeCount(summary.maybe));
  }
  if (parts.isEmpty) {
    return l10n.eventNoRsvps;
  }
  return parts.join(' · ');
}

class EventDetailScreen extends StatefulWidget {
  const EventDetailScreen({super.key, required this.eventId});

  final String eventId;

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  BabySummary? _baby;
  EventDetail? _detail;
  late final CommentComposerController _comments;
  final _scrollController = ScrollController();
  var _initialLoadInFlight = true;
  CalendarRepository? _calendarRepo;

  @override
  void initState() {
    super.initState();
    _calendarRepo = context.read<CalendarRepository>();
    _calendarRepo!.addListener(_onCalendarRepositoryChanged);
    _comments = CommentComposerController(
      port: EventCommentThread(
        repository: _calendarRepo!,
        babyId: () => _baby?.id,
        eventId: widget.eventId,
      ),
      onPosted: () => _refreshEventDetail(scrollToComments: true),
      onError: (error) {
        if (mounted) _showApiError(error);
      },
    );
    _loadInitial();
  }

  @override
  void dispose() {
    _calendarRepo?.removeListener(_onCalendarRepositoryChanged);
    _scrollController.dispose();
    _comments.dispose();
    super.dispose();
  }

  void _onCalendarRepositoryChanged() {
    if (_detail == null) return;
    _refreshEventDetail();
  }

  Future<void> _openEdit() async {
    await pushAndRefresh<bool>(
      context,
      CalendarRoutes.eventEdit(widget.eventId),
      composer: _comments,
      refresh: _refreshEventDetail,
      shouldRefresh: (saved) => saved == true,
    );
  }

  void _onCoverUrlError() {
    _refreshEventDetail();
  }

  Future<void> _loadInitial() async {
    setState(() => _initialLoadInFlight = true);
    try {
      final homeRepo = context.read<HomeRepository>();
      final store = context.read<SelectedBabyStore>();
      final baby = await homeRepo.resolveSelectedBaby(store);
      if (baby == null) {
        if (mounted) returnToCalendar(context);
        return;
      }
      if (!mounted) return;
      final detail = await context.read<CalendarRepository>().fetchEvent(
        baby.id,
        widget.eventId,
      );
      if (!mounted) return;
      setState(() {
        _baby = baby;
        _detail = detail;
        _initialLoadInFlight = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _initialLoadInFlight = false);
      AppSnackBar.showAlert(context, apiErrorMessage(AppLocalizations.of(context)!, e));
      returnToCalendar(context);
    }
  }

  Future<void> _refreshEventDetail({bool scrollToComments = false}) async {
    final baby = _baby;
    if (baby == null) return;
    if (!scrollToComments) {
      _comments.unfocus();
    }
    try {
      final detail = await context.read<CalendarRepository>().fetchEvent(
        baby.id,
        widget.eventId,
      );
      if (!mounted) return;
      setState(() => _detail = detail);
      if (scrollToComments) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_scrollController.hasClients) return;
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        });
      }
    } catch (e) {
      _showApiError(e);
    }
  }

  void _showApiError(Object e) {
    if (!mounted) return;
    AppSnackBar.showAlert(context, apiErrorMessage(AppLocalizations.of(context)!, e));
  }

  bool get _isOwner => _baby?.role == 'owner';

  Future<void> _openVideo(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !mounted) return;
    await openExternalLink(context, uri);
  }

  void _showRsvpSheet(EventDetail detail) {
    final l10n = AppLocalizations.of(context)!;
    showAppModalSheet<void>(
      context: context,
      title: l10n.eventRsvpsTitle,
      subtitle: detail.rsvpAttendees.isEmpty
          ? AppLocalizations.of(context)!.eventNoRsvps
          : l10n.rsvpResponseCount(detail.rsvpAttendees.length),
      bodyBuilder: (ctx) {
        final l10n = AppLocalizations.of(ctx)!;
        return ListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            if (detail.rsvpAttendees.isEmpty)
              Text(AppLocalizations.of(context)!.eventNoRsvps)
            else
              for (final a in detail.rsvpAttendees)
                ListTile(
                  title: Text(personDisplayName(AppLocalizations.of(context)!, a.displayName)),
                  trailing: Text(a.status?.label(l10n) ?? ''),
                ),
          ],
        );
      },
    );
  }

  Future<void> _setRsvp(RsvpStatus status) async {
    final baby = _baby;
    if (baby == null) return;
    try {
      await context.read<CalendarRepository>().setRsvp(
        baby.id,
        widget.eventId,
        status,
      );
      await _refreshEventDetail();
    } catch (e) {
      _showApiError(e);
    }
  }

  Future<void> _editComment(EventComment comment) async {
    final baby = _baby;
    if (baby == null || !comment.canEdit) return;
    final text = await showEditCommentDialog(context, comment.body);
    if (text == null || !mounted) return;
    try {
      await context.read<CalendarRepository>().updateComment(
        baby.id,
        widget.eventId,
        comment.id,
        text,
      );
      await _refreshEventDetail();
    } catch (e) {
      if (mounted) showCommentError(context, e);
    }
  }

  Future<void> _deleteComment(EventComment comment) async {
    final baby = _baby;
    if (baby == null || !comment.canDelete) return;
    final ok = await confirmDeleteComment(context);
    if (!ok || !mounted) return;
    try {
      await context.read<CalendarRepository>().deleteComment(
        baby.id,
        widget.eventId,
        comment.id,
      );
      await _refreshEventDetail();
    } catch (e) {
      if (mounted) showCommentError(context, e);
    }
  }

  Future<void> _deleteEvent() async {
    final baby = _baby;
    if (baby == null || !_isOwner) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(ctx)!.eventDeleteConfirmTitle),
        content: Text(AppLocalizations.of(ctx)!.eventDeleteConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(ctx)!.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocalizations.of(ctx)!.actionDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    await context.read<CalendarRepository>().deleteEvent(
      baby.id,
      widget.eventId,
    );
    if (mounted) returnToCalendar(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (shouldShowDetailFullScreenLoader(
      hasContent: _detail != null,
      initialLoadInFlight: _initialLoadInFlight,
    )) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final detail = _detail;
    if (detail == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) returnToCalendar(context);
      });
      return Scaffold(body: Center(child: Text(AppLocalizations.of(context)!.eventNotFound)));
    }
    return PrototypeSubpageScaffold(
      title: l10n.eventTitle,
      actions: [
        if (_isOwner)
          AppIconButton(
            semanticsId: 'event_edit',
            label: l10n.eventEditAction,
            onPressed: _openEdit,
            icon: const Icon(Icons.edit_outlined, size: 20),
          ),
        if (_isOwner)
          AppIconButton(
            semanticsId: 'event_delete',
            label: l10n.eventDeleteAction,
            onPressed: _deleteEvent,
            icon: const Icon(
              Icons.delete_outline,
              color: AppColors.error,
              size: 20,
            ),
          ),
      ],
      body: Column(
        children: [
          Expanded(
            child: ListView(
              key: PageStorageKey<String>('event-detail-${widget.eventId}'),
              controller: _scrollController,
              padding: AppMetrics.subpageScrollPadding,
              children: [
                Text(
                  detail.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                AppSectionCapsLabel(AppLocalizations.of(context)!.calendarWhen),
                SizedBox(height: AppSpacing.xs),
                Text(
                  formatEventDetailWhen(
                    detail.startsAt,
                    Localizations.localeOf(context).toString(),
                  ),
                ),
                if (detail.location != null) ...[
                  const SizedBox(height: 12),
                  AppSectionCapsLabel(AppLocalizations.of(context)!.calendarLocation),
                  SizedBox(height: AppSpacing.xs),
                  Text('📍 ${detail.location}'),
                ],
                if (detail.videoCallUrl != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    l10n.eventVideoCallLabel,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  TextButton(
                    onPressed: () => _openVideo(detail.videoCallUrl!),
                    child: Text(AppLocalizations.of(context)!.eventJoinVideoCall),
                  ),
                ],
                if (detail.coverPhotoDisplayUrl != null) ...[
                  const SizedBox(height: 12),
                  Text(AppLocalizations.of(context)!.eventPhotoLabel, style: Theme.of(context).textTheme.labelLarge),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedSignedImage(
                      imageUrl: detail.coverPhotoDisplayUrl,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      onSignedUrlError: _onCoverUrlError,
                    ),
                  ),
                ],
                if (detail.description != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    l10n.eventDetailsHeading,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  Text(detail.description!),
                ],
                const SizedBox(height: 16),
                AppSectionCapsLabel(AppLocalizations.of(context)!.calendarYourRsvp),
                const SizedBox(height: 8),
                AppRsvpTileRow(
                  selectedStatus: detail.viewerRsvp,
                  onSelect: _setRsvp,
                ),
                SizedBox(height: AppSpacing.smMd),
                InkWell(
                  onTap: () => _showRsvpSheet(detail),
                  child: Row(
                    children: [
                      AvatarStack(
                        displayNames: detail.rsvpAttendees
                            .map((a) => personDisplayName(AppLocalizations.of(context)!, a.displayName))
                            .toList(),
                      ),
                      SizedBox(width: AppSpacing.smMd),
                      Expanded(
                        child: Text(
                          _rsvpInlineSummary(l10n, detail.rsvpSummary),
                          style: context.textStyles.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        l10n.actionViewRsvps,
                        style: context.textStyles.labelSmall?.copyWith(
                          color: AppColors.primaryDark,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 24),
                AppSectionCapsLabel(
                  AppLocalizations.of(context)!.calendarComments,
                  trailing: detail.comments.isNotEmpty
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.smMd,
                            vertical: AppSpacing.xxs,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.sageTint,
                            borderRadius: BorderRadius.circular(
                              AppMetrics.buttonRadius,
                            ),
                          ),
                          child: Text('${detail.comments.length}'),
                        )
                      : null,
                ),
                SizedBox(height: AppSpacing.sm),
                for (final c in detail.comments)
                  ListTile(
                    title: Text(personDisplayName(AppLocalizations.of(context)!, c.authorDisplayName)),
                    subtitle: Text(c.body),
                    trailing: (c.canEdit || c.canDelete)
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (c.canEdit)
                                AppIconButton(
                                  semanticsId: 'event_comment_edit',
                                  label: l10n.commentEditTitle,
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 20,
                                  ),
                                  onPressed: () => _editComment(c),
                                ),
                              if (c.canDelete)
                                AppIconButton(
                                  semanticsId: 'event_comment_delete',
                                  label: l10n.commentDeleteMenuLabel,
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 20,
                                  ),
                                  onPressed: () => _deleteComment(c),
                                ),
                            ],
                          )
                        : null,
                  ),
              ],
            ),
          ),
          DetailCommentComposer(
            controller: _comments,
            semanticsId: 'event_comment',
          ),
        ],
      ),
    );
  }
}
