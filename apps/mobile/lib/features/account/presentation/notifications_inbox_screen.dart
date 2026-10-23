import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_error_message.dart';
import '../../../core/presentation/tab_load_failure.dart';
import '../../../core/router/deep_link_navigation.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_semantics.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/prototype_subpage_scaffold.dart';
import '../data/notifications_repository.dart';
import 'widgets/inbox_notification_row.dart';

class NotificationsInboxScreen extends StatefulWidget {
  const NotificationsInboxScreen({super.key});

  @override
  State<NotificationsInboxScreen> createState() =>
      _NotificationsInboxScreenState();
}

class _NotificationsInboxScreenState extends State<NotificationsInboxScreen> {
  List<InboxNotification> _items = [];
  var _loading = true;
  var _hasLoaded = false;
  var _markingAllRead = false;
  var _loadingMore = false;
  var _hasMore = false;
  String? _loadError;
  final _scrollController = ScrollController();

  bool get _hasUnread => _items.any((n) => n.readAt == null);

  NotificationsRepository get _repo => context.read<NotificationsRepository>();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _repo.addListener(_onInboxRepoChanged);
    unawaited(_openInbox());
  }

  @override
  void dispose() {
    _repo.removeListener(_onInboxRepoChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _onInboxRepoChanged() {
    if (!mounted) return;
    _syncFromRepo();
  }

  void _syncFromRepo() {
    final window = _repo.peekInbox();
    if (window == null) return;
    setState(() {
      _items = window.items;
      _hasMore = window.hasMore;
      _loading = false;
      _hasLoaded = true;
    });
  }

  Future<void> _openInbox() async {
    final cached = _repo.peekInbox();
    if (cached != null && cached.items.isNotEmpty) {
      setState(() {
        _items = cached.items;
        _hasMore = cached.hasMore;
        _loading = false;
        _hasLoaded = true;
        _loadError = null;
      });
      unawaited(_revalidateInBackground());
      return;
    }
    await _loadFirstPage();
  }

  Future<void> _revalidateInBackground() async {
    try {
      await _repo.revalidateInbox();
    } catch (e) {
      if (!mounted || !_hasLoaded) return;
      AppSnackBar.showAlert(context, apiErrorMessage(AppLocalizations.of(context)!, e));
    }
  }

  /// The spinner shows only for the first load; reloads after mark-all,
  /// returning from a notification or pull-to-refresh keep the list and its
  /// scroll position, and a failed reload is a snackbar.
  Future<void> _loadFirstPage({bool forceRefresh = false}) async {
    if (!_hasLoaded) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    try {
      final window = await _repo.ensureInboxFirstPage(forceRefresh: forceRefresh);
      if (!mounted) return;
      setState(() {
        _items = window.items;
        _hasMore = window.hasMore;
        _loading = false;
        _hasLoaded = true;
      });
    } catch (e) {
      if (!mounted) return;
      reportTabLoadFailure(
        context,
        e,
        hasPayload: _hasLoaded,
        onBlockingError: (message) => setState(() {
          _loadError = message;
          _loading = false;
        }),
      );
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _loading) return;
    setState(() => _loadingMore = true);
    try {
      await _repo.extendInbox();
    } catch (e) {
      if (mounted) {
        AppSnackBar.showAlert(context, apiErrorMessage(AppLocalizations.of(context)!, e));
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 240) {
      unawaited(_loadMore());
    }
  }

  Future<void> _markAllRead() async {
    if (_markingAllRead || !_hasUnread) return;
    setState(() => _markingAllRead = true);
    try {
      await _repo.markAllRead();
      if (!mounted) return;
      _syncFromRepo();
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.showAlert(context, apiErrorMessage(AppLocalizations.of(context)!, e));
    } finally {
      if (mounted) setState(() => _markingAllRead = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AppSemantics.container(
      'notifications_inbox',
      PrototypeSubpageScaffold(
        title: l10n.notificationsInboxTitle,
        actions: _loading || _loadError != null || !_hasUnread
            ? null
            : [
                AppSemantics.button(
                  'notifications_mark_all_read',
                  TextButton(
                    onPressed: _markingAllRead ? null : _markAllRead,
                    child: Text(
                      l10n.notificationsMarkAllRead,
                      style: TextStyle(
                        color: _markingAllRead
                            ? AppColors.muted
                            : AppColors.primaryDark,
                      ),
                    ),
                  ),
                  label: l10n.notificationsMarkAllRead,
                ),
              ],
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null
            ? Center(
                child: Padding(
                  padding: AppMetrics.subpageScrollPadding,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_loadError!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => _loadFirstPage(forceRefresh: true),
                        child: Text(l10n.actionRetry),
                      ),
                    ],
                  ),
                ),
              )
            : _items.isEmpty
            ? AppEmptyState(
                icon: Icons.notifications_none_outlined,
                title: l10n.notificationsInboxEmptyTitle,
                message: l10n.notificationsInboxEmptyMessage,
              )
            : RefreshIndicator(
                onRefresh: () => _loadFirstPage(forceRefresh: true),
                child: ListView.builder(
                  controller: _scrollController,
                  padding: AppMetrics.subpageScrollPadding,
                  itemCount: _items.length + (_loadingMore ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i >= _items.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final n = _items[i];
                    final label = n.title.trim().isEmpty
                        ? l10n.inboxNotificationFallbackTitle
                        : n.title.trim();
                    return AppSemantics.button(
                      'notification_${n.id}',
                      InkWell(
                        onTap: () async {
                          if (n.readAt == null) {
                            try {
                              await _repo.markRead(n.id);
                            } catch (e) {
                              if (!context.mounted) return;
                              AppSnackBar.showAlert(
                                context,
                                apiErrorMessage(l10n, e),
                              );
                            }
                          }
                          if (n.deepLink != null && n.deepLink!.isNotEmpty) {
                            if (!context.mounted) return;
                            await navigateAppDeepLink(
                              context,
                              n.deepLink,
                              babyProfileId: n.babyProfileId,
                            );
                          }
                        },
                        child: InboxNotificationRow(notification: n),
                      ),
                      label: label,
                    );
                  },
                ),
              ),
      ),
    );
  }
}
