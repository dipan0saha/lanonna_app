import 'package:flutter/foundation.dart';

import 'app_config.dart';

const String _buildGitShaFromEnvironment = String.fromEnvironment(
  'BUILD_GIT_SHA',
);

const String _buildNumberFromEnvironment = String.fromEnvironment(
  'BUILD_NUMBER',
);

const bool _releaseOrProfile =
    bool.fromEnvironment('dart.vm.product') ||
    bool.fromEnvironment('dart.vm.profile');

const String _appEnvFromEnvironment = String.fromEnvironment(
  'APP_ENV',
  defaultValue: 'dev',
);

const bool _isProdEnvironment = _appEnvFromEnvironment == 'prod';

/// Prod release/profile must ship with an explicit git SHA and build number.
const bool _prodReleaseMissingBuildStamp =
    _releaseOrProfile &&
    _isProdEnvironment &&
    (_buildGitShaFromEnvironment.isEmpty ||
        _buildNumberFromEnvironment.isEmpty);

const String prodBuildStampMissingMessage =
    'Prod release builds must pass BUILD_GIT_SHA and BUILD_NUMBER via --dart-define '
    '(see apps/mobile/scripts/build_stamp.sh)';

// dart format off
const int prodBuildStampGuard =
    1 ~/ (_prodReleaseMissingBuildStamp ? 0 : 1); // Prod release builds must pass BUILD_GIT_SHA and BUILD_NUMBER via --dart-define (see apps/mobile/scripts/build_stamp.sh)
// dart format on

/// Build identity for Crashlytics and support triage.
abstract final class BuildMetadata {
  static String get gitSha {
    if (prodBuildStampGuard != 1) {
      throw StateError(prodBuildStampMissingMessage);
    }
    final raw = _buildGitShaFromEnvironment;
    return raw.isEmpty ? 'unknown' : raw;
  }

  static String get buildNumber {
    if (prodBuildStampGuard != 1) {
      throw StateError(prodBuildStampMissingMessage);
    }
    final raw = _buildNumberFromEnvironment;
    return raw.isEmpty ? 'unknown' : raw;
  }

  static String get environment => AppConfig.environment;
}

/// Referenced so release/profile compilation evaluates the prod stamp guard.
@visibleForTesting
const Object prodBuildStampCheck = prodBuildStampGuard;
