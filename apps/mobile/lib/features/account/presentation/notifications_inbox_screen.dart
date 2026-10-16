import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_error_message.dart';
import '../../../core/router/deep_link_navigation.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_semantics.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/prototype_subpage_scaffold.dart';
import '../data/notifications_repository.dart';
import '../data/notifications_unread_signal.dart';
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
  var _markingAllRead = false;
  String? _loadError;

  bool get _hasUnread => _items.any((n) => n.readAt == null);

  void _notifyUnreadChanged() {
    context.read<NotificationsUnreadSignal>().notifyUnreadChanged();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final items = await context.read<NotificationsRepository>().listInbox();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = apiErrorMessage(e);
        _loading = false;
      });
    }
  }

  Future<void> _markAllRead() async {
    if (_markingAllRead || !_hasUnread) return;
    setState(() => _markingAllRead = true);
    try {
      await context.read<NotificationsRepository>().markAllRead();
      if (!mounted) return;
      _notifyUnreadChanged();
      await _load();
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.showAlert(context, apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _markingAllRead = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppSemantics.container(
      'notifications_inbox',
      PrototypeSubpageScaffold(
        title: 'Notifications',
        actions: _loading || _loadError != null || !_hasUnread
            ? null
            : [
                AppSemantics.button(
                  'notifications_mark_all_read',
                  TextButton(
                    onPressed: _markingAllRead ? null : _markAllRead,
                    child: Text(
                      'Mark all read',
                      style: TextStyle(
                        color: _markingAllRead
                            ? AppColors.muted
                            : AppColors.primaryDark,
                      ),
                    ),
                  ),
                  label: 'Mark all read',
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
                        onPressed: _load,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            : _items.isEmpty
            ? AppEmptyState(
                icon: Icons.notifications_none_outlined,
                title: 'No notifications yet',
                message: 'When family comments, RSVPs, or joins, you\'ll see it here.',
              )
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView.builder(
                  padding: AppMetrics.subpageScrollPadding,
                  itemCount: _items.length,
                  itemBuilder: (context, i) {
                    final n = _items[i];
                    final label = n.title.trim().isEmpty
                        ? 'Notification'
                        : n.title.trim();
                    return AppSemantics.button(
                      'notification_${n.id}',
                      InkWell(
                        onTap: () async {
                          if (n.readAt == null) {
                            await context
                                .read<NotificationsRepository>()
                                .markRead(n.id);
                            _notifyUnreadChanged();
                          }
                          if (n.deepLink != null && n.deepLink!.isNotEmpty) {
                            if (!context.mounted) return;
                            await navigateAppDeepLink(
                              context,
                              n.deepLink,
                              babyProfileId: n.babyProfileId,
                            );
                          }
                          await _load();
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
