import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../account/data/notifications_repository.dart';
import '../../home/data/home_refresh_signal.dart';
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
  SelectedBabyStore? _babyStore;
  HomeRefreshSignal? _babyRefresh;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = context.read<SelectedBabyStore>();
    if (_babyStore != store) {
      _babyStore?.removeListener(_onBabyContextChanged);
      _babyStore = store;
      _babyStore!.addListener(_onBabyContextChanged);
    }
    final refresh = context.read<HomeRefreshSignal>();
    if (_babyRefresh != refresh) {
      _babyRefresh?.removeListener(_onBabyContextChanged);
      _babyRefresh = refresh;
      _babyRefresh!.addListener(_onBabyContextChanged);
    }
  }

  @override
  void dispose() {
    _babyStore?.removeListener(_onBabyContextChanged);
    _babyRefresh?.removeListener(_onBabyContextChanged);
    super.dispose();
  }

  void _onBabyContextChanged() {
    if (mounted) _refresh();
  }

  Future<void> _refresh() async {
    try {
      final store = context.read<SelectedBabyStore>();
      final resolved =
          await context.read<HomeRepository>().resolveSelectedBaby(store);
      if (!mounted) return;
      final unread = await context.read<NotificationsRepository>().unreadCount();
      if (mounted) {
        setState(() {
          if (resolved != null) _centerTitle = resolved.name;
          _unreadCount = unread;
        });
      }
    } catch (e) {
      debugPrint('shell_top_bar_refresh_failed: $e');
    }
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
