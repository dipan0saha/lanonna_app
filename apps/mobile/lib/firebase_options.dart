// Generated-style config from Firebase console apps (lanonna-dev).
// Re-run `flutterfire configure` after installing Ruby gem `xcodeproj` to regenerate.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Web is not configured for La Nonna yet.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError('macOS is not configured for La Nonna yet.');
      case TargetPlatform.windows:
        throw UnsupportedError('Windows is not configured for La Nonna yet.');
      case TargetPlatform.linux:
        throw UnsupportedError('Linux is not configured for La Nonna yet.');
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAlc5_AlllDc7lNj2Uj3UJ61NK04iIS5-Y',
    appId: '1:1008830071001:android:0144f51dbc29e9a94abec8',
    messagingSenderId: '1008830071001',
    projectId: 'lanonna-dev',
    storageBucket: 'lanonna-dev.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBqfG8QLMc9Tm1LOJcDkhv3PdvwWEy7oaw',
    appId: '1:1008830071001:ios:300a85e14edae2214abec8',
    messagingSenderId: '1008830071001',
    projectId: 'lanonna-dev',
    storageBucket: 'lanonna-dev.firebasestorage.app',
    iosBundleId: 'com.lanonna.lanonna',
  );
}
