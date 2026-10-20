// Barrel for integration tests and tooling that import `firebase_options.dart`.
// Runtime code should call [resolveFirebaseOptions].

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

import 'firebase/firebase_options_dev.dart';
import 'firebase/firebase_options_resolver.dart';

export 'firebase/firebase_options_resolver.dart' show resolveFirebaseOptions;

/// Legacy name — dev options when `APP_ENV` is not `prod`.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => resolveFirebaseOptions();

  static const FirebaseOptions android = DevFirebaseOptions.android;
  static const FirebaseOptions ios = DevFirebaseOptions.ios;
}
