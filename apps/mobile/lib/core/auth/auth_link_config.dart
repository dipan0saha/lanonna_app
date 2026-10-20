import '../../config/app_config.dart';

/// Firebase Auth email action links (`/__/auth/action`) for the active Firebase project.
abstract final class AuthLinkConfig {
  static String get authActionHost => AppConfig.appLinkHost;

  static Uri get emailVerificationContinueUrl =>
      Uri.parse('https://$authActionHost/email-verified');

  static const androidPackageName = 'com.lanonna.lanonna';
  static const iOSBundleId = 'com.lanonna.lanonna';
}
