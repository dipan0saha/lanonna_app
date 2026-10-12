import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/config/app_config.dart';

void main() {
  test('debug build without API_BASE_URL uses the dev origin', () {
    expect(
      resolveApiBaseUrl(fromEnvironment: '', releaseOrProfile: false),
      devApiBaseUrl,
    );
    expect(devApiBaseUrl, startsWith('https://'));
  });

  test('explicit API_BASE_URL wins in debug and release', () {
    const url = 'https://api.example.test';
    expect(
      resolveApiBaseUrl(fromEnvironment: url, releaseOrProfile: false),
      url,
    );
    expect(
      resolveApiBaseUrl(fromEnvironment: url, releaseOrProfile: true),
      url,
    );
  });

  test('release or profile without API_BASE_URL fails with the build message', () {
    expect(
      () => resolveApiBaseUrl(fromEnvironment: '', releaseOrProfile: true),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          releaseApiBaseUrlMissingMessage,
        ),
      ),
    );
  });

  test('AppConfig compiles with a non-empty https origin', () {
    // Touches the const release check so an empty release/profile define
    // fails this library at compile time (see _ApiBaseUrl).
    expect(releaseApiBaseUrlCheck, isNotNull);
    expect(AppConfig.apiBaseUrl, isNotEmpty);
    expect(AppConfig.apiBaseUrl, startsWith('https://'));
    expect(AppConfig.apiBaseUrlConfigured, isA<bool>());
  });
}
