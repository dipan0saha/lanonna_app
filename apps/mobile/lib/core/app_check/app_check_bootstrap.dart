import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

/// Activates App Check (debug providers in debug builds).
Future<void> activateFirebaseAppCheck() async {
  await FirebaseAppCheck.instance.activate(
    androidProvider:
        kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
    appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
  );
  if (kDebugMode) {
    try {
      final token = await FirebaseAppCheck.instance.getToken();
      if (token != null) {
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
