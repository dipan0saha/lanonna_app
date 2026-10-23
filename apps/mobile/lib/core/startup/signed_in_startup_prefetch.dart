import 'package:flutter/foundation.dart';

import '../../features/account/data/account_repository.dart';
import '../../features/account/data/notifications_repository.dart';
import '../../features/home/data/home_repository.dart';
import '../../features/home/data/selected_baby_store.dart';
import '../../features/onboarding/presentation/app_session.dart';

/// Starts the signed-in cold-start API reads as soon as the object graph
/// exists, in parallel with the public version check
/// ([AppVersionService.start]). Call only when a user is signed in.
///
/// This is the only cold-start owner of the onboarding-status refresh. The
/// UI readers that mount later reuse the results instead of requesting again:
/// account and baby list are cached, the unread count and the home summary
/// are read with a freshness window ([ShellChromeSync], [HomeScreen]), and a
/// speculative home summary still in flight is joined.
///
/// Never throws; the returned future completes when every read has settled
/// (bootstrap does not wait for it).
Future<void> startSignedInStartupPrefetch({
  required AppSession session,
  required HomeRepository homeRepository,
  required SelectedBabyStore selectedBabyStore,
  required AccountRepository accountRepository,
  required NotificationsRepository notificationsRepository,
}) async {
  final storedBabyId = selectedBabyStore.selectedBabyId;
  // Home is only speculated for a session that may open it: a cached status
  // that says otherwise (no baby left, onboarding still open) routes the
  // cold start elsewhere, so no Home read is started for it (#409).
  session.restoreCachedStatus();
  final cached = session.status;
  final mayOpenHome = cached == null || cached.canAccessMainApp;
  await Future.wait<void>([
    _logged('onboarding_status', session.refreshFromApi),
    _logged('account', accountRepository.ensureAccountLoaded),
    _logged('unread', notificationsRepository.refreshUnreadCount),
    if (storedBabyId != null && mayOpenHome)
      _logged(
        'home_summary',
        () => homeRepository.fetchHomeSummary(storedBabyId, speculative: true),
      ),
    _logged(
      'baby_resolve',
      () => homeRepository.resolveSelectedBaby(selectedBabyStore),
    ),
  ]);
}

Future<void> _logged(String what, Future<Object?> Function() read) async {
  try {
    await read();
  } catch (e) {
    debugPrint('startup_${what}_prefetch_failed: $e');
  }
}
