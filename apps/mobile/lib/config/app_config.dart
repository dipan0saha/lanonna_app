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

/// Const-evaluated so a missing release/profile URL fails compilation.
///
/// `bool.hasEnvironment` is only reliable as `const`. A non-const call is
/// false in AOT release builds even when `--dart-define-from-file` set the
/// value, which crashed the splash screen (issue #44).
class _ApiBaseUrl {
  const _ApiBaseUrl(String fromEnvironment, bool releaseOrProfile)
    : assert(
        !releaseOrProfile || fromEnvironment != '',
        releaseApiBaseUrlMissingMessage,
      ),
      url = fromEnvironment != '' ? fromEnvironment : devApiBaseUrl;

  final String url;
}

const _apiBaseUrl = _ApiBaseUrl(
  String.fromEnvironment('API_BASE_URL'),
  bool.fromEnvironment('dart.vm.product') ||
      bool.fromEnvironment('dart.vm.profile'),
);

/// Runtime config (dev defaults; override with --dart-define / flavors).
class AppConfig {
  const AppConfig._();

  /// True when this build passed a non-empty `API_BASE_URL`.
  ///
  /// Const so it observes `--dart-define-from-file`. Do not replace with a
  /// non-const `bool.hasEnvironment` call.
  static const bool apiBaseUrlConfigured =
      String.fromEnvironment('API_BASE_URL') != '';

  static String get apiBaseUrl => _apiBaseUrl.url;

  static const String environment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'dev',
  );

  static const String supportEmail = String.fromEnvironment(
    'SUPPORT_EMAIL',
    defaultValue: 'hello@lanonna.app',
  );
}

/// Referenced so release/profile compilation always evaluates [_apiBaseUrl].
@visibleForTesting
const Object releaseApiBaseUrlCheck = _apiBaseUrl;
