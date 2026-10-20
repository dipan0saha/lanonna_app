import '../../config/app_config.dart';
import '../auth/auth_repository.dart';
import 'app_error_handlers.dart';
import 'crash_reporter.dart';
import 'firebase_crash_reporter.dart';

/// Wires Crashlytics collection, global error handlers, and opaque user ids.
Future<CrashReporter> startCrashReporting({
  required AuthRepository authRepository,
  CrashReporter? reporter,
}) async {
  final crashReporter = reporter ?? createFirebaseCrashReporter();
  final enabled = AppConfig.crashlyticsCollectionEnabled;
  await crashReporter.setCollectionEnabled(enabled);
  configureAppErrorReporting(reporter: crashReporter, enabled: enabled);
  _bindCrashReporterUserId(authRepository, crashReporter);
  return crashReporter;
}

void _bindCrashReporterUserId(
  AuthRepository authRepository,
  CrashReporter reporter,
) {
  authRepository.authStateChanges().listen((user) {
    reporter.setUserId(user?.uid);
  });
}
