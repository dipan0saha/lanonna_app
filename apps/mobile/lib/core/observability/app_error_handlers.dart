import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'crash_reporter.dart';

bool _handlersInstalled = false;

/// Installs global Flutter / platform error hooks that forward to [reporter].
///
/// When [enabled] is false, leaves default framework behavior and does not
/// install duplicate handlers.
void configureAppErrorReporting({
  required CrashReporter reporter,
  required bool enabled,
}) {
  if (!enabled || _handlersInstalled) return;
  _handlersInstalled = true;

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    reporter.recordFlutterFatalError(details);
  };

  final previousPlatformOnError = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    reporter.recordError(error, stack, fatal: true);
    if (previousPlatformOnError != null) {
      return previousPlatformOnError(error, stack);
    }
    return true;
  };
}

/// Test-only reset so unit tests can re-install handlers.
@visibleForTesting
void resetAppErrorHandlersForTest() {
  _handlersInstalled = false;
}
