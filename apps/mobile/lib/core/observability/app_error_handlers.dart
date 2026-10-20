import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'crash_reporter.dart';

bool _handlersInstalled = false;
FlutterExceptionHandler? _previousFlutterOnError;
ErrorCallback? _previousPlatformOnError;

/// Chains global Flutter / platform error hooks to [reporter].
///
/// The handlers already installed (the framework default that prints the
/// error, or any app/test handler) keep running; the reporter is added in
/// front of them, never instead of them. When [enabled] is false nothing is
/// installed.
void configureAppErrorReporting({
  required CrashReporter reporter,
  required bool enabled,
}) {
  if (!enabled || _handlersInstalled) return;
  _handlersInstalled = true;

  final previousFlutterOnError = FlutterError.onError;
  _previousFlutterOnError = previousFlutterOnError;
  FlutterError.onError = (FlutterErrorDetails details) {
    reporter.recordFlutterFatalError(details);
    if (previousFlutterOnError != null) {
      previousFlutterOnError(details);
    } else {
      FlutterError.presentError(details);
    }
  };

  final previousPlatformOnError = PlatformDispatcher.instance.onError;
  _previousPlatformOnError = previousPlatformOnError;
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    reporter.recordError(error, stack, fatal: true);
    if (previousPlatformOnError != null) {
      return previousPlatformOnError(error, stack);
    }
    // No earlier handler: keep the error visible in logs, then mark handled
    // so the engine does not print it a second time.
    FlutterError.presentError(
      FlutterErrorDetails(exception: error, stack: stack, library: 'platform'),
    );
    return true;
  };
}

/// Test-only: restores the handlers that were active before installation.
@visibleForTesting
void resetAppErrorHandlersForTest() {
  if (_handlersInstalled) {
    FlutterError.onError = _previousFlutterOnError;
    PlatformDispatcher.instance.onError = _previousPlatformOnError;
  }
  _previousFlutterOnError = null;
  _previousPlatformOnError = null;
  _handlersInstalled = false;
}
