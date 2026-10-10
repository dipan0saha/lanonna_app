import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_error_message.dart';
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
  String? _loadError;

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

  @override
  Widget build(BuildContext context) {
    return AppSemantics.container(
      'notifications_inbox',
      PrototypeSubpageScaffold(
        title: 'Notifications',
        body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
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
                      );
                    },
                  ),
                ),
      ),
    );
  }
}
