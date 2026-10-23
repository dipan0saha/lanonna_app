import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/version/app_version_service.dart';

class _VersionApi extends ApiClient {
  _VersionApi(this.minimum) : super(idTokenProvider: () async => null);

  final String? minimum;
  var requests = 0;

  @override
  Future<Map<String, dynamic>> getJsonPublic(
    String path, {
    Duration? timeout,
  }) async {
    requests++;
    final minimum = this.minimum;
    if (minimum == null) throw Exception('offline');
    return {
      'minimum_version': minimum,
      'store_url': 'https://example.com/store',
    };
  }
}

void main() {
  test('below the minimum: blocks and notifies once', () async {
    final api = _VersionApi('99.0.0');
    final service = AppVersionService(
      api,
      installedVersion: () async => '1.0.0',
    );
    var notified = 0;
    service.addListener(() => notified++);

    await service.start();

    expect(service.blockRequirement?.minimumVersion, '99.0.0');
    expect(service.installedVersion, '1.0.0');
    expect(notified, 1);
  });

  test('checks once per process however often it is started', () async {
    final api = _VersionApi('99.0.0');
    final service = AppVersionService(
      api,
      installedVersion: () async => '1.0.0',
    );

    await Future.wait([service.start(), service.start()]);
    await service.start();

    expect(api.requests, 1);
  });

  test('at or above the minimum: no block', () async {
    final service = AppVersionService(
      _VersionApi('1.0.0'),
      installedVersion: () async => '1.0.0',
    );
    await service.start();
    expect(service.blockRequirement, isNull);
  });

  test('unreachable API or unreadable version: no block, no throw', () async {
    final offline = AppVersionService(
      _VersionApi(null),
      installedVersion: () async => '1.0.0',
    );
    await offline.start();
    expect(offline.blockRequirement, isNull);

    final noPackageInfo = AppVersionService(
      _VersionApi('99.0.0'),
      installedVersion: () async => throw Exception('no package info'),
    );
    await noPackageInfo.start();
    expect(noPackageInfo.blockRequirement, isNull);
  });
}
