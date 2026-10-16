import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/network/connectivity_service.dart';
import '../../account/data/account_repository.dart';
import '../../account/data/notifications_repository.dart';
import '../../account/data/notifications_unread_signal.dart';
import '../../home/data/home_refresh_signal.dart';
import '../../home/data/home_repository.dart';
import '../../home/data/selected_baby_store.dart';
import '../../home/presentation/widgets/home_top_bar.dart';
import 'baby_switcher_sheet.dart';

Widget shellHomeTopBar(BuildContext context) {
  return const _ShellTopBarLoader();
}

T? _maybeRead<T>(BuildContext context) {
  try {
    return context.read<T>();
  } on ProviderNotFoundException {
    return null;
  }
}

class _ShellTopBarLoader extends StatefulWidget {
  const _ShellTopBarLoader();

  @override
  State<_ShellTopBarLoader> createState() => _ShellTopBarLoaderState();
}

class _ShellTopBarLoaderState extends State<_ShellTopBarLoader> {
  String _centerTitle = 'La Nonna';
  var _unreadCount = 0;
  String? _accountName;
  String? _accountAvatarUrl;
  HomeRefreshSignal? _babyRefresh;
  ConnectivityService? _connectivity;
  NotificationsUnreadSignal? _unreadSignal;
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
    final unreadSignal = _maybeRead<NotificationsUnreadSignal>(context);
    if (_unreadSignal != unreadSignal) {
      _unreadSignal?.removeListener(_onUnreadChanged);
      _unreadSignal = unreadSignal;
      unreadSignal?.addListener(_onUnreadChanged);
    }
  }

  @override
  void dispose() {
    _babyRefresh?.babyContext.removeListener(_onBabyContextChanged);
    _connectivity?.removeListener(_onConnectivityChanged);
    _unreadSignal?.removeListener(_onUnreadChanged);
    super.dispose();
  }

  void _onUnreadChanged() {
    if (mounted) _refresh();
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
      AccountPayload? account;
      try {
        account = await context.read<AccountRepository>().fetchAccount();
      } catch (_) {
        account = context.read<AccountRepository>().cachedAccount;
      }
      if (mounted) {
        setState(() {
          if (resolved != null) _centerTitle = resolved.name;
          _unreadCount = unread;
          _accountName = account?.displayName;
          _accountAvatarUrl = account?.avatarUrl;
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
      onAddBabyTap: () => context.push('/baby/create'),
      onBabySwitcherTap: () async {
        await showBabySwitcherSheet(context);
        await _refresh();
      },
      onSearchTap: () => context.push('/search'),
      onNotificationsTap: () async {
        await context.push('/notifications/inbox');
        await _refresh();
      },
      onAccountTap: () => context.push('/profile'),
      accountDisplayName: _accountName,
      accountAvatarUrl: _accountAvatarUrl,
    );
  }
}
