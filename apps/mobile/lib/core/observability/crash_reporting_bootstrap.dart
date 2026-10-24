import '../../config/app_config.dart';
import '../../config/build_metadata.dart';
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
  await _applyBuildMetadata(crashReporter);
  configureAppErrorReporting(reporter: crashReporter, enabled: enabled);
  _bindCrashReporterUserId(authRepository, crashReporter);
  return crashReporter;
}

Future<void> _applyBuildMetadata(CrashReporter reporter) async {
  await reporter.setCustomKey('build_git_sha', BuildMetadata.gitSha);
  await reporter.setCustomKey('build_number', BuildMetadata.buildNumber);
  await reporter.setCustomKey('build_env', BuildMetadata.environment);
}

void _bindCrashReporterUserId(
  AuthRepository authRepository,
  CrashReporter reporter,
) {
  authRepository.authStateChanges().listen((user) {
    reporter.setUserId(user?.uid);
  });
}
