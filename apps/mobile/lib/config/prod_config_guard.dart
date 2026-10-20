import 'app_config.dart';

/// Prefix for values in [flavors/prod.json] that must be replaced before prod ship.
const String prodConfigPlaceholderPrefix = '__PROD_';

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
  if (errors.isEmpty) return;

  throw StateError(
    'Prod build still has placeholder values for ${errors.join(', ')}. '
    'Edit flavors/prod.json (and run flutterfire configure for Firebase) '
    'before shipping a prod binary.',
  );
}
