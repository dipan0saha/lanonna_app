import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/network/connectivity_service.dart';
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
  HomeRefreshSignal? _babyRefresh;
  ConnectivityService? _connectivity;
  var _wasOffline = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final refresh = context.read<HomeRefreshSignal>();
    if (_babyRefresh != refresh) {
      _babyRefresh?.babyContext.removeListener(_onBabyContextChanged);
      _babyRefresh = refresh;
      _babyRefresh!.babyContext.addListener(_onBabyContextChanged);
    }
    final connectivity = context.read<ConnectivityService>();
    if (_connectivity != connectivity) {
      _connectivity?.removeListener(_onConnectivityChanged);
      _connectivity = connectivity;
      _wasOffline = !connectivity.isOnline;
      _connectivity!.addListener(_onConnectivityChanged);
    }
  }

  @override
  void dispose() {
    _babyRefresh?.babyContext.removeListener(_onBabyContextChanged);
    _connectivity?.removeListener(_onConnectivityChanged);
    super.dispose();
  }

  void _onConnectivityChanged() {
    if (!mounted) return;
    final online = _connectivity?.isOnline ?? true;
    if (online && _wasOffline) {
      _wasOffline = false;
      _refresh();
    } else if (!online) {
      _wasOffline = true;
    }
  }

  void _onBabyContextChanged() {
    if (mounted) _refresh();
  }

  Future<void> _refresh() async {
    try {
      final store = context.read<SelectedBabyStore>();
      final resolved = await context.read<HomeRepository>().resolveSelectedBaby(
        store,
      );
      if (!mounted) return;
      final unread = await context
          .read<NotificationsRepository>()
          .unreadCount();
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

  String get _title {
    if (_centerTitle != 'La Nonna') return _centerTitle;
    final cached = context.read<SelectedBabyStore>().selectedBabyName;
    if (cached != null && cached.isNotEmpty) return cached;
    return _centerTitle;
  }

  @override
  Widget build(BuildContext context) {
    return HomeTopBar(
      centerTitle: _title,
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
