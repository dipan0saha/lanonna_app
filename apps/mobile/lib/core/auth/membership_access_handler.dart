import 'package:flutter/material.dart';
import 'package:lanonna/l10n/app_localizations.dart';

import '../../features/account/domain/member_lifecycle_messages.dart';
import '../../features/home/data/home_refresh_signal.dart';
import '../../features/home/data/home_repository.dart';
import '../../features/home/data/selected_baby_store.dart';
import '../api/api_exception.dart';
import '../router/app_router.dart';

var _handlingMembershipEnded = false;

/// Refreshes baby list/selection when the API reports ended membership.
Future<void> handleMembershipEnded({
  required HomeRepository homeRepository,
  required SelectedBabyStore store,
  required HomeRefreshSignal signal,
  ApiException? exception,
}) async {
  if (_handlingMembershipEnded) return;
  _handlingMembershipEnded = true;
  try {
    await homeRepository.resolveSelectedBaby(store);
    signal.notifyBabyContextChanged();

    final context = appRootNavigatorKey.currentContext;
    if (context != null && context.mounted && exception != null) {
      final l10n = AppLocalizations.of(context);
      if (l10n != null) {
        final message = memberLifecycleErrorMessage(l10n, exception);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    }
  } finally {
    _handlingMembershipEnded = false;
  }
}
