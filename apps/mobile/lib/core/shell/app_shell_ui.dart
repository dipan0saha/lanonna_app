import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// [MaterialApp] scaffold messenger. Snackbars from shell-level handlers
/// (App Links, push taps) must use this, not a [State] context above the app.
final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// UI scope below [MaterialApp] for handlers that run outside route widgets.
abstract final class AppShellUi {
  /// Frames to wait for the shell to mount (cold-start links run before the
  /// first frame) before the message is dropped.
  static const int maxWaitFrames = 5;

  /// Runs [action] with the root messenger and localizations once
  /// [MaterialApp] has mounted. Waits at most [maxWaitFrames] frames, so a
  /// shell that never mounts cannot keep scheduling frames.
  static void whenReady(
    void Function(ScaffoldMessengerState messenger, AppLocalizations l10n)
    action,
  ) {
    unawaited(_runWhenReady(action));
  }

  static Future<void> _runWhenReady(
    void Function(ScaffoldMessengerState messenger, AppLocalizations l10n)
    action,
  ) async {
    for (var frame = 0; ; frame++) {
      final messenger = rootScaffoldMessengerKey.currentState;
      final l10n = messenger == null || !messenger.mounted
          ? null
          : AppLocalizations.of(messenger.context);
      if (messenger != null && l10n != null) {
        action(messenger, l10n);
        return;
      }
      if (frame >= maxWaitFrames) {
        debugPrint('app_shell_ui_not_ready: message dropped');
        return;
      }
      await WidgetsBinding.instance.endOfFrame;
    }
  }
}
