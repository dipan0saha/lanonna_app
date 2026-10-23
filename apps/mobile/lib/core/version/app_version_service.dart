import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../api/api_client.dart';
import '../data/single_flight.dart';
import 'app_version_check.dart';
import 'app_version_gate.dart';

/// Runs the public force-update check once per process and exposes any block.
///
/// Started from [bootstrapLaNonnaApp] so `/v1/app/version` overlaps signed-in
/// startup prefetch instead of being the only early network call from the UI
/// tree.
class AppVersionService extends ChangeNotifier {
  AppVersionService({this.timeout = appVersionCheckTimeout});

  final Duration timeout;
  final _check = SingleFlight<void>();

  AppVersionRequirement? _block;
  String? _installedVersion;

  AppVersionRequirement? get blockRequirement => _block;
  String? get installedVersion => _installedVersion;

  /// Starts the check if needed; concurrent callers share one request.
  Future<void> ensureStarted(ApiClient client) {
    return _check.run(() => _run(client));
  }

  Future<void> _run(ApiClient client) async {
    final info = await PackageInfo.fromPlatform();
    final installed = info.version;
    final requirement = await fetchAppVersionRequirement(
      client,
      timeout: timeout,
    );
    if (requirement != null &&
        isAppVersionBelowMinimum(installed, requirement.minimumVersion)) {
      _block = requirement;
      _installedVersion = installed;
      notifyListeners();
    }
  }
}
