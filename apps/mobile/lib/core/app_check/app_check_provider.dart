import '../../config/app_config.dart';

/// Whether this build should use Firebase App Check **debug** providers.
///
/// Non-prod flavors (`APP_ENV` ≠ `prod`) use the debug provider so sideloaded
/// dev/staging APKs and local iOS builds can register a debug token in the
/// Firebase project. Prod always uses Play Integrity / App Attest and must never
/// fall back to the debug provider.
bool appCheckUsesDebugProvider({String environment = AppConfig.environment}) {
  return environment != 'prod';
}
