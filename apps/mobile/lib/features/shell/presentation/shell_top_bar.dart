import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../account/data/notifications_repository.dart';
import '../../home/data/home_repository.dart';
import '../../home/data/selected_baby_store.dart';
import '../../home/presentation/widgets/home_top_bar.dart';
import 'baby_switcher_sheet.dart';

Widget shellHomeTopBar(BuildContext context) {
  return const _ShellTopBarLoader();
}

class _ShellTopBarLoader extends StatefulWidget {
  const _ShellTopBarLoader();

  @override
  State<_ShellTopBarLoader> createState() => _ShellTopBarLoaderState();
}

class _ShellTopBarLoaderState extends State<_ShellTopBarLoader> {
  String _centerTitle = 'La Nonna';
  var _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final store = context.read<SelectedBabyStore>();
      final babies = await context.read<HomeRepository>().listBabies();
      final selectedId = store.selectedBabyId;
      final baby = selectedId != null
          ? babies.where((b) => b.id == selectedId).firstOrNull
          : null;
      final resolved = baby ?? (babies.isNotEmpty ? babies.first : null);
      final unread = await context.read<NotificationsRepository>().unreadCount();
      if (mounted) {
        setState(() {
          if (resolved != null) _centerTitle = resolved.name;
          _unreadCount = unread;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return HomeTopBar(
      centerTitle: _centerTitle,
      showUnreadDot: _unreadCount > 0,
      onProfileTap: () async {
        await showBabySwitcherSheet(context);
        await _refresh();
      },
      onSearchTap: () => context.push('/search'),
      onNotificationsTap: () async {
        await context.push('/notifications/inbox');
        await _refresh();
      },
    );
  }
}
