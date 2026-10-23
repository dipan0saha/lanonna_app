import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../account/data/account_repository.dart';
import '../../account/data/notifications_repository.dart';
import '../../home/data/home_repository.dart';
import '../../home/data/selected_baby_store.dart';
import '../../home/presentation/baby_context_reload.dart';

/// Keeps the shell top bar's shared state current, once for the whole shell
/// (not once per tab): the selected baby's title, the unread count and the
/// account avatar. Refreshes on start, baby-context changes and when the
/// connection comes back.
class ShellChromeSync extends StatefulWidget {
  const ShellChromeSync({super.key, required this.child});

  final Widget child;

  @override
  State<ShellChromeSync> createState() => _ShellChromeSyncState();
}

class _ShellChromeSyncState extends State<ShellChromeSync>
    with BabyContextReload {
  @override
  void initState() {
    super.initState();
    // The cold-start prefetch may already have the unread count.
    unawaited(_sync(unreadMaxAge: NotificationsRepository.unreadFreshFor));
    unawaited(_loadAccount());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    registerBabyContextListeners();
  }

  @override
  void dispose() {
    disposeBabyContextListeners();
    super.dispose();
  }

  @override
  void onBabyContextReload() => unawaited(_sync());

  Future<void> _sync({Duration? unreadMaxAge}) async {
    final homeRepo = context.read<HomeRepository>();
    final store = context.read<SelectedBabyStore>();
    final notificationsRepo = context.read<NotificationsRepository>();
    await Future.wait([
      // Resolving persists the selected baby's name for the title.
      homeRepo.resolveSelectedBaby(store).then<void>(
        (_) {},
        onError: (Object e) => debugPrint('shell_title_resolve_failed: $e'),
      ),
      notificationsRepo.refreshUnreadCount(maxAge: unreadMaxAge).catchError(
        (Object e) => debugPrint('shell_unread_refresh_failed: $e'),
      ),
    ]);
  }

  Future<void> _loadAccount() async {
    try {
      await context.read<AccountRepository>().ensureAccountLoaded();
    } catch (e) {
      // Avatar falls back to initials; any account screen retries the load.
      debugPrint('shell_account_load_failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
