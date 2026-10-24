import 'app_config.dart';
import 'build_metadata.dart';

/// Prefix for values in [flavors/prod.json] that must be replaced before prod ship.
const String prodConfigPlaceholderPrefix = '__PROD_';

/// Exact placeholder values shipped in flavors/prod.json. Kept as literals so
/// the compile-time guard in app_config.dart can compare them in a const
/// expression (String.startsWith is not allowed in const context). A test
/// keeps this list in sync with flavors/prod.json.
const String prodApiBaseUrlPlaceholder = '__PROD_API_BASE_URL__';
const String prodAppLinkHostPlaceholder = '__PROD_APP_LINK_HOST__';
const String prodGoogleSignInClientIdPlaceholder =
    '__PROD_GOOGLE_SIGN_IN_SERVER_CLIENT_ID__';

/// Returns true when [value] is still an unreplaced prod placeholder.
bool isProdPlaceholderValue(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return true;
  return trimmed.startsWith(prodConfigPlaceholderPrefix);
}

/// Runtime guard: prod builds must not start with placeholder dart-defines.
void ensureProdConfigReady() {
  if (AppConfig.environment != 'prod') return;

  final errors = <String>[];
  if (isProdPlaceholderValue(AppConfig.apiBaseUrl)) {
    errors.add('API_BASE_URL');
  }
  if (isProdPlaceholderValue(AppConfig.appLinkHost)) {
    errors.add('APP_LINK_HOST');
  }
  const googleClientId = String.fromEnvironment(
    'GOOGLE_SIGN_IN_SERVER_CLIENT_ID',
  );
  if (isProdPlaceholderValue(googleClientId)) {
    errors.add('GOOGLE_SIGN_IN_SERVER_CLIENT_ID');
  }
  if (BuildMetadata.gitSha == BuildMetadata.unknown) {
    errors.add('BUILD_GIT_SHA');
  }
  if (BuildMetadata.buildNumber == BuildMetadata.unknown) {
    errors.add('BUILD_NUMBER');
  }
  if (errors.isEmpty) return;

  throw StateError(
    'Prod build is missing config for ${errors.join(', ')}. '
    'Replace the __PROD_ placeholders in flavors/prod.json (and run '
    'flutterfire configure for Firebase), and build with '
    'apps/mobile/scripts/flutter_build_apk.sh for the build stamp.',
  );
}
