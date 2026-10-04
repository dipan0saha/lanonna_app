import '../../firebase_options.dart';

/// Firebase Auth email action links (`/__/auth/action`) for the active Firebase project.
abstract final class AuthLinkConfig {
  static String get projectId => DefaultFirebaseOptions.android.projectId;

  static String get authActionHost => '$projectId.firebaseapp.com';

  static Uri get emailVerificationContinueUrl =>
      Uri.parse('https://$authActionHost/');

  static const androidPackageName = 'com.lanonna.lanonna';
  static const iOSBundleId = 'com.lanonna.lanonna';
}
