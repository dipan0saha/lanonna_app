import 'package:flutter/foundation.dart';

/// Crash and fatal error reporting (Crashlytics in production builds).
abstract class CrashReporter {
  Future<void> setCollectionEnabled(bool enabled);

  Future<void> setUserId(String? userId);

  Future<void> setCustomKey(String key, String value);

  Future<void> recordFlutterFatalError(FlutterErrorDetails details);

  Future<void> recordError(
    Object error,
    StackTrace stack, {
    bool fatal = false,
  });
}

/// No Firebase dependency — used in tests and when collection is disabled.
class NoOpCrashReporter implements CrashReporter {
  bool collectionEnabled = false;
  String? userId;
  final List<FlutterErrorDetails> flutterErrors = [];
  final List<(Object, StackTrace, bool)> errors = [];

  @override
  Future<void> setCollectionEnabled(bool enabled) async {
    collectionEnabled = enabled;
  }

  @override
  Future<void> setUserId(String? userId) async {
    this.userId = userId;
  }

  @override
  Future<void> setCustomKey(String key, String value) async {}

  @override
  Future<void> recordFlutterFatalError(FlutterErrorDetails details) async {
    flutterErrors.add(details);
  }

  @override
  Future<void> recordError(
    Object error,
    StackTrace stack, {
    bool fatal = false,
  }) async {
    errors.add((error, stack, fatal));
  }
}
