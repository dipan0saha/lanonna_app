import 'package:flutter/foundation.dart';

/// Dev Cloud Run API used when a debug build omits `API_BASE_URL`.
const String devApiBaseUrl = 'https://api-r27szgit5q-uc.a.run.app';

/// Compiler-facing message when a release or profile build has no API URL.
const String releaseApiBaseUrlMissingMessage =
    'Release builds must set API_BASE_URL via --dart-define-from-file=flavors/dev.json';

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

const bool _releaseOrProfile =
    bool.fromEnvironment('dart.vm.product') ||
    bool.fromEnvironment('dart.vm.profile');

/// True when a release or profile build omitted `API_BASE_URL`.
///
/// An `assert` is not enough: release and profile compilation disables
/// asserts, so a const assert would be skipped and [devApiBaseUrl] would ship.
const bool _releaseMissingApiBaseUrl =
    _releaseOrProfile && _apiBaseUrlFromEnvironment == '';

const String _resolvedApiBaseUrl = _apiBaseUrlFromEnvironment != ''
    ? _apiBaseUrlFromEnvironment
    : devApiBaseUrl;

/// Compile-time failure for a release/profile build with no API URL.
///
/// Integer division by zero is a constant-evaluation error in every build
/// mode, including release where asserts are stripped. The compiler prints
/// this line, which includes [releaseApiBaseUrlMissingMessage].
// dart format off
const int releaseApiBaseUrlGuard = 1 ~/ (_releaseMissingApiBaseUrl ? 0 : 1); // Release builds must set API_BASE_URL via --dart-define-from-file=flavors/dev.json
// dart format on

/// Runtime config (dev defaults; override with --dart-define / flavors).
class AppConfig {
  const AppConfig._();

  /// True when this build passed a non-empty `API_BASE_URL`.
  ///
  /// Const so it observes `--dart-define-from-file`. Do not replace with a
  /// non-const `bool.hasEnvironment` call.
  static const bool apiBaseUrlConfigured =
      String.fromEnvironment('API_BASE_URL') != '';

  static String get apiBaseUrl {
    // Referenced so release compilation always evaluates [releaseApiBaseUrlGuard].
    if (releaseApiBaseUrlGuard != 1) {
      throw StateError(releaseApiBaseUrlMissingMessage);
    }
    return _resolvedApiBaseUrl;
  }

  static const String environment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'dev',
  );

  static const String supportEmail = String.fromEnvironment(
    'SUPPORT_EMAIL',
    defaultValue: 'hello@lanonna.app',
  );
}

/// Referenced so release/profile compilation always evaluates [releaseApiBaseUrlGuard].
@visibleForTesting
const Object releaseApiBaseUrlCheck = releaseApiBaseUrlGuard;
