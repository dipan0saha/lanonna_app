import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/config/app_config.dart';

void main() {
  test('prod always enables Crashlytics collection', () {
    expect(
      resolveCrashlyticsCollectionEnabled(
        appEnv: 'prod',
        crashlyticsEnabledDefine: 'false',
        releaseOrProfile: true,
      ),
      isTrue,
    );
  });

  test('dev honors CRASHLYTICS_ENABLED when set', () {
    expect(
      resolveCrashlyticsCollectionEnabled(
        appEnv: 'dev',
        crashlyticsEnabledDefine: 'false',
        releaseOrProfile: true,
      ),
      isFalse,
    );
    expect(
      resolveCrashlyticsCollectionEnabled(
        appEnv: 'dev',
        crashlyticsEnabledDefine: 'true',
        releaseOrProfile: false,
      ),
      isTrue,
    );
  });

  test('dev release defaults Crashlytics on when define omitted', () {
    expect(
      resolveCrashlyticsCollectionEnabled(
        appEnv: 'dev',
        crashlyticsEnabledDefine: '',
        releaseOrProfile: true,
      ),
      isTrue,
    );
    expect(
      resolveCrashlyticsCollectionEnabled(
        appEnv: 'dev',
        crashlyticsEnabledDefine: '',
        releaseOrProfile: false,
      ),
      isFalse,
    );
  });
}
