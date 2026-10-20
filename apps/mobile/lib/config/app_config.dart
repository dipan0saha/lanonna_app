import 'package:flutter/foundation.dart';

import 'prod_config_guard.dart';

/// Dev Cloud Run API used when a debug build omits `API_BASE_URL`.
const String devApiBaseUrl = 'https://api-r27szgit5q-uc.a.run.app';

/// Dev Firebase Hosting origin for App Links when `APP_LINK_HOST` is omitted.
const String devAppLinkHost = 'lanonna-dev.firebaseapp.com';

/// Compiler-facing message when a release or profile build has no API URL.
const String releaseApiBaseUrlMissingMessage =
    'Release builds must set API_BASE_URL via --dart-define-from-file=flavors/dev.json';

/// Compiler-facing message when a prod release still has placeholder defines.
const String prodPlaceholderConfigMessage =
    'Prod release builds must replace all __PROD_ placeholders in flavors/prod.json';

/// Resolves the API origin from a dart-define value.
///
/// Release and profile builds must pass a non-empty `API_BASE_URL`
/// (`--dart-define` or `--dart-define-from-file`). Debug builds fall back to
/// [devDefault]. An empty value in release/profile throws [StateError] with
/// [releaseApiBaseUrlMissingMessage].
String resolveApiBaseUrl({
  required String fromEnvironment,
  required bool releaseOrProfile,
  String devDefault = devApiBaseUrl,
}) {
  if (releaseOrProfile && fromEnvironment.isEmpty) {
    throw StateError(releaseApiBaseUrlMissingMessage);
  }
  if (fromEnvironment.isEmpty) return devDefault;
  return fromEnvironment;
}

const String _apiBaseUrlFromEnvironment = String.fromEnvironment(
  'API_BASE_URL',
);

const String _appLinkHostFromEnvironment = String.fromEnvironment(
  'APP_LINK_HOST',
  defaultValue: devAppLinkHost,
);

const String _crashlyticsEnabledFromEnvironment = String.fromEnvironment(
  'CRASHLYTICS_ENABLED',
);

const String _googleSignInClientIdFromEnvironment = String.fromEnvironment(
  'GOOGLE_SIGN_IN_SERVER_CLIENT_ID',
);

const bool _releaseOrProfile =
    bool.fromEnvironment('dart.vm.product') ||
    bool.fromEnvironment('dart.vm.profile');

const String _appEnvFromEnvironment = String.fromEnvironment(
  'APP_ENV',
  defaultValue: 'dev',
);

const bool _isProdEnvironment = _appEnvFromEnvironment == 'prod';

/// True when a release or profile build omitted `API_BASE_URL`.
const bool _releaseMissingApiBaseUrl =
    _releaseOrProfile && _apiBaseUrlFromEnvironment == '';

/// Prod release/profile with a placeholder, a missing value, or a dev
/// fallback (no silent dev defaults in prod).
const bool _prodReleaseHasPlaceholderConfig =
    _releaseOrProfile &&
    _isProdEnvironment &&
    (_apiBaseUrlFromEnvironment == '' ||
        _apiBaseUrlFromEnvironment == prodApiBaseUrlPlaceholder ||
        _apiBaseUrlFromEnvironment == devApiBaseUrl ||
        _appLinkHostFromEnvironment == prodAppLinkHostPlaceholder ||
        _appLinkHostFromEnvironment == devAppLinkHost ||
        _googleSignInClientIdFromEnvironment == '' ||
        _googleSignInClientIdFromEnvironment ==
            prodGoogleSignInClientIdPlaceholder);

const String _resolvedApiBaseUrl = _apiBaseUrlFromEnvironment != ''
    ? _apiBaseUrlFromEnvironment
    : devApiBaseUrl;

/// Whether Crashlytics collection should be enabled for this build.
bool resolveCrashlyticsCollectionEnabled({
  required String appEnv,
  required String crashlyticsEnabledDefine,
  required bool releaseOrProfile,
}) {
  if (appEnv == 'prod') return true;
  if (crashlyticsEnabledDefine.isNotEmpty) {
    return crashlyticsEnabledDefine == 'true';
  }
  return releaseOrProfile;
}

/// Compile-time failure for a release/profile build with no API URL.
// dart format off
const int releaseApiBaseUrlGuard = 1 ~/ (_releaseMissingApiBaseUrl ? 0 : 1); // Release builds must set API_BASE_URL via --dart-define-from-file=flavors/dev.json
const int prodPlaceholderConfigGuard = 1 ~/ (_prodReleaseHasPlaceholderConfig ? 0 : 1); // Prod release builds must replace all __PROD_ placeholders in flavors/prod.json
// dart format on

/// Runtime config (dev defaults; override with --dart-define / flavors).
class AppConfig {
  const AppConfig._();

  /// True when this build passed a non-empty `API_BASE_URL`.
  static const bool apiBaseUrlConfigured =
      String.fromEnvironment('API_BASE_URL') != '';

  static String get apiBaseUrl {
    if (releaseApiBaseUrlGuard != 1) {
      throw StateError(releaseApiBaseUrlMissingMessage);
    }
    if (prodPlaceholderConfigGuard != 1) {
      throw StateError(prodPlaceholderConfigMessage);
    }
    return _resolvedApiBaseUrl;
  }

  static const String environment = _appEnvFromEnvironment;

  static const String appLinkHost = _appLinkHostFromEnvironment;

  static const String supportEmail = String.fromEnvironment(
    'SUPPORT_EMAIL',
    defaultValue: 'hello@lanonna.app',
  );

  static bool get crashlyticsCollectionEnabled =>
      resolveCrashlyticsCollectionEnabled(
        appEnv: environment,
        crashlyticsEnabledDefine: _crashlyticsEnabledFromEnvironment,
        releaseOrProfile: _releaseOrProfile,
      );
}

/// Referenced so release/profile compilation always evaluates build guards.
@visibleForTesting
const Object releaseApiBaseUrlCheck = releaseApiBaseUrlGuard;

@visibleForTesting
const Object prodPlaceholderConfigCheck = prodPlaceholderConfigGuard;
