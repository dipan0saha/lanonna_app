import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../api/api_client.dart';
import 'app_version_check.dart';
import 'app_version_gate.dart';

/// Runs the public force-update check once per process and exposes any block
/// to [AppVersionGate].
///
/// Started from [bootstrapLaNonnaApp] before the first frame, so
/// `/v1/app/version` overlaps signed-in startup prefetch instead of waiting
/// for the widget tree.
class AppVersionService extends ChangeNotifier {
  AppVersionService(this._client, {Future<String> Function()? installedVersion})
    : _readInstalledVersion = installedVersion ?? _platformVersion;

  final ApiClient _client;
  final Future<String> Function() _readInstalledVersion;
  Future<void>? _check;

  AppVersionRequirement? _block;
  String? _installedVersion;

  AppVersionRequirement? get blockRequirement => _block;
  String? get installedVersion => _installedVersion;

  /// Starts the check on the first call; later calls return the same future
  /// (never a second request). Never throws: an unreachable API or unreadable
  /// package info leaves the app usable, as before.
  Future<void> start() => _check ??= _run();

  Future<void> _run() async {
    try {
      final (installed, requirement) = await (
        _readInstalledVersion(),
        fetchAppVersionRequirement(_client),
      ).wait;
      if (requirement != null &&
          isAppVersionBelowMinimum(installed, requirement.minimumVersion)) {
        _block = requirement;
        _installedVersion = installed;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('app_version_check_failed: $e');
    }
  }

  static Future<String> _platformVersion() async =>
      (await PackageInfo.fromPlatform()).version;
}
