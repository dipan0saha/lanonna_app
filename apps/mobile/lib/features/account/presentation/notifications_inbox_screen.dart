import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/router/deep_link_navigation.dart';
import '../../../core/widgets/app_semantics.dart';
import '../../../core/widgets/prototype_subpage_scaffold.dart';
import '../data/notifications_repository.dart';

class NotificationsInboxScreen extends StatefulWidget {
  const NotificationsInboxScreen({super.key});

  @override
  State<NotificationsInboxScreen> createState() => _NotificationsInboxScreenState();
}

class _NotificationsInboxScreenState extends State<NotificationsInboxScreen> {
  List<InboxNotification> _items = [];
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await context.read<NotificationsRepository>().listInbox();
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppSemantics.container(
      'notifications_inbox',
      PrototypeSubpageScaffold(
        title: 'Notifications',
        body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(child: Text('No notifications yet'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    itemCount: _items.length,
                    itemBuilder: (context, i) {
                      final n = _items[i];
                      return ListTile(
                        title: Text(n.title),
                        subtitle: Text(n.body),
                        trailing: n.readAt == null
                            ? const Icon(Icons.circle, size: 10)
                            : null,
                        onTap: () async {
                          if (n.readAt == null) {
                            await context
                                .read<NotificationsRepository>()
                                .markRead(n.id);
                          }
                          if (mounted && n.deepLink != null && n.deepLink!.isNotEmpty) {
                            await navigateAppDeepLink(
                              context,
                              n.deepLink,
                              babyProfileId: n.babyProfileId,
                            );
                          }
                          await _load();
                        },
                      );
                    },
                  ),
                ),
      ),
    );
  }
}
