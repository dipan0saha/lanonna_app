import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

import 'app_check_token_source.dart';

bool _useDebugAppCheckProvider() =>
    kDebugMode || bool.fromEnvironment('MAESTRO_SEMANTICS');

/// Activates App Check (debug providers in debug / Maestro builds) and returns
/// the token source for the API client.
///
/// Activation only installs the provider; it makes no network call. Callers
/// await [AppCheckTokenSource.activated] alongside the rest of start-up.
AppCheckTokenSource startFirebaseAppCheck() {
  final debugProvider = _useDebugAppCheckProvider();
  final source = AppCheckTokenSource(
    activation: FirebaseAppCheck.instance.activate(
      androidProvider:
          debugProvider ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      appleProvider:
          debugProvider ? AppleProvider.debug : AppleProvider.appAttest,
    ),
    fetchToken: () => FirebaseAppCheck.instance.getToken(),
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
      debugPrint('Firebase App Check ready for API (debug build).');
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
