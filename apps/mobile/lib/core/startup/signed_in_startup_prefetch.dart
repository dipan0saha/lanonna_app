import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../features/account/data/account_repository.dart';
import '../../features/account/data/notifications_repository.dart';
import '../../features/home/data/home_repository.dart';
import '../../features/home/data/selected_baby_store.dart';
import '../../features/onboarding/presentation/app_session.dart';

/// Kicks off signed-in cold-start API reads as soon as the object graph exists,
/// in parallel with the public version check.
///
/// UI layers ([LaNonnaApp], [ShellChromeSync], [HomeScreen]) may call the same
/// repository methods later; their [SingleFlight] caches dedupe in-flight work.
void startSignedInStartupPrefetch({
  required AppSession session,
  required HomeRepository homeRepository,
  required SelectedBabyStore selectedBabyStore,
  required AccountRepository accountRepository,
  required NotificationsRepository notificationsRepository,
}) {
  unawaited(session.refreshFromApi());
  unawaited(
    accountRepository.ensureAccountLoaded().catchError(
      (Object e) => debugPrint('startup_account_prefetch_failed: $e'),
    ),
  );
  unawaited(
    notificationsRepository.refreshUnreadCount().catchError(
      (Object e) => debugPrint('startup_unread_prefetch_failed: $e'),
    ),
  );
  final storedBabyId = selectedBabyStore.selectedBabyId;
  if (storedBabyId != null) {
    unawaited(
      homeRepository.fetchHomeSummary(storedBabyId, speculative: true),
    );
  }
  unawaited(
    homeRepository.resolveSelectedBaby(selectedBabyStore).catchError(
      (Object e) => debugPrint('startup_baby_resolve_prefetch_failed: $e'),
    ),
  );
}
