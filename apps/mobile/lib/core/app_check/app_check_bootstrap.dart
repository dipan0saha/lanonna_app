import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

bool _useDebugAppCheckProvider() =>
    kDebugMode || bool.fromEnvironment('MAESTRO_SEMANTICS');

/// Activates App Check (debug providers in debug / Maestro builds).
Future<void> activateFirebaseAppCheck() async {
  final debugProvider = _useDebugAppCheckProvider();
  await FirebaseAppCheck.instance.activate(
    androidProvider:
        debugProvider ? AndroidProvider.debug : AndroidProvider.playIntegrity,
    appleProvider:
        debugProvider ? AppleProvider.debug : AppleProvider.appAttest,
  );
  if (debugProvider) {
    unawaited(_logAppCheckDebugToken());
  }
}

Future<void> _logAppCheckDebugToken() async {
  // Native SDK logs the registerable debug UUID (logcat: DebugAppCheckProvider).
  for (var attempt = 0; attempt < 6; attempt++) {
    try {
      final token = await FirebaseAppCheck.instance.getToken();
      if (token != null && token.isNotEmpty) {
        debugPrint('Firebase App Check ready for API (debug build).');
        return;
      }
    } catch (e) {
      if (attempt >= 5) {
        debugPrint(
          'App Check not ready: $e. Register the emulator debug UUID: '
          'bash apps/mobile/maestro/scripts/register-app-check-debug.sh',
        );
      }
    }
    await Future<void>.delayed(const Duration(seconds: 2));
  }
}

Future<String?> appCheckTokenForApi() async {
  try {
    return await FirebaseAppCheck.instance.getToken();
  } catch (_) {
    return null;
  }
}
