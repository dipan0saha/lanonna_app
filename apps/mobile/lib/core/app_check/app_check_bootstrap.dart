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
    try {
      final token = await FirebaseAppCheck.instance.getToken();
      if (token != null) {
        // `print` so Maestro release builds still emit the token in logcat.
        debugPrint(
          'Firebase App Check debug token (register in Firebase Console → App Check): $token',
        );
      }
    } catch (e) {
      debugPrint('App Check token not ready yet: $e');
    }
  }
}

Future<String?> appCheckTokenForApi() async {
  try {
    return await FirebaseAppCheck.instance.getToken();
  } catch (_) {
    return null;
  }
}
