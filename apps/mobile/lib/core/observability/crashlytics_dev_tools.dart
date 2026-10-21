import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import '../../config/app_config.dart';

const bool _testCrashOnStart = bool.fromEnvironment(
  'CRASHLYTICS_TEST_CRASH_ON_START',
);

/// Schedules a native test crash after start-up when
/// [CRASHLYTICS_TEST_CRASH_ON_START] is set (dev/non-prod, collection on).
void scheduleCrashlyticsTestCrashOnStartIfRequested() {
  if (!_testCrashOnStart) return;
  if (AppConfig.environment == 'prod') return;
  if (!AppConfig.crashlyticsCollectionEnabled) return;
  Future<void>.delayed(const Duration(seconds: 3), () {
    FirebaseCrashlytics.instance.crash();
  });
}

/// Force a fatal crash for Firebase Crashlytics console verification (dev only).
void sendCrashlyticsTestCrash() {
  if (AppConfig.environment == 'prod') return;
  if (!AppConfig.crashlyticsCollectionEnabled) return;
  FirebaseCrashlytics.instance.crash();
}

bool get showCrashlyticsDevToolsInSettings =>
    AppConfig.environment == 'dev' && AppConfig.crashlyticsCollectionEnabled;
