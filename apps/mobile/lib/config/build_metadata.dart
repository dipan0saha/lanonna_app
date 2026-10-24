import 'app_config.dart';

/// Build identity for Crashlytics custom keys and support triage.
///
/// Debug and dev builds without a stamp report `unknown`; a prod release
/// without one fails to compile ([prodBuildStampGuard]) and a prod debug run
/// fails at start-up (`ensureProdConfigReady`).
abstract final class BuildMetadata {
  static const String unknown = 'unknown';

  static String get gitSha {
    if (prodBuildStampGuard != 1) {
      throw StateError(prodBuildStampMissingMessage);
    }
    return buildGitShaFromEnvironment.isEmpty
        ? unknown
        : buildGitShaFromEnvironment;
  }

  static String get buildNumber {
    if (prodBuildStampGuard != 1) {
      throw StateError(prodBuildStampMissingMessage);
    }
    return buildNumberFromEnvironment.isEmpty
        ? unknown
        : buildNumberFromEnvironment;
  }

  static String get environment => AppConfig.environment;
}
