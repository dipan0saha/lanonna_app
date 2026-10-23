import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

import '../../config/app_config.dart';
import 'app_check_token_source.dart';

/// Activates App Check and returns the token source for the API client.
///
/// The provider follows `APP_ENV` only: prod uses Play Integrity / App Attest,
/// every other flavor the debug provider (its token is registered in that
/// Firebase project; Android pins it via `BuildConfig.APP_CHECK_DEBUG_TOKEN`,
/// which Gradle leaves empty for every prod build type).
///
/// Activation only installs the provider; it makes no network call. Callers
/// await [AppCheckTokenSource.activated] alongside the rest of start-up.
AppCheckTokenSource startFirebaseAppCheck() {
  const debugProvider = AppConfig.environment != 'prod';
  final source = AppCheckTokenSource(
    activation: FirebaseAppCheck.instance.activate(
      androidProvider:
          debugProvider ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      appleProvider:
          debugProvider ? AppleProvider.debug : AppleProvider.appAttest,
    ),
    fetchToken: () => FirebaseAppCheck.instance.getToken(),
    tokenChanges: FirebaseAppCheck.instance.onTokenChange,
  );
  if (debugProvider) {
    unawaited(_logAppCheckDebugToken(source));
  }
  return source;
}

Future<void> _logAppCheckDebugToken(AppCheckTokenSource source) async {
  // Native SDK logs the registerable debug UUID (logcat: DebugAppCheckProvider).
  for (var attempt = 0; attempt < 6; attempt++) {
    final token = await source.token();
    if (token != null) {
      debugPrint('Firebase App Check ready for API (non-prod debug provider).');
      return;
    }
    if (attempt >= 5) {
      debugPrint(
        'App Check not ready. Register debug UUID (or set '
        'APP_CHECK_DEBUG_TOKEN in maestro/local.env and rebuild): '
        'bash apps/mobile/maestro/scripts/register-app-check-debug.sh',
      );
    }
    await Future<void>.delayed(const Duration(seconds: 2));
  }
}
