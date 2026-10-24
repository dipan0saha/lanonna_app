import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../router/app_router.dart';

/// [MaterialApp] scaffold messenger — snackbars from shell-level handlers
/// (deep links, push taps) must use this, not a [State] context above the app.
final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// UI scope below [MaterialApp] for handlers that run outside route widgets.
abstract final class AppShellUi {
  static ScaffoldMessengerState? get messenger =>
      rootScaffoldMessengerKey.currentState;

  static AppLocalizations? localizations {
    final context = appRootNavigatorKey.currentContext;
    if (context == null) return null;
    return AppLocalizations.of(context);
  }

  /// Runs [action] once [localizations] and [messenger] are available.
  static void whenReady(void Function(AppLocalizations l10n) action) {
    void attempt() {
      final l10n = localizations;
      if (l10n != null) {
        action(l10n);
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
    }

    attempt();
  }
}
