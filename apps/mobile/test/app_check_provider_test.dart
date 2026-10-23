import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/app_check/app_check_provider.dart';

void main() {
  group('appCheckUsesDebugProvider', () {
    test('dev and staging use the debug provider', () {
      expect(appCheckUsesDebugProvider(environment: 'dev'), isTrue);
      expect(appCheckUsesDebugProvider(environment: 'staging'), isTrue);
    });

    test('prod uses attestation providers only', () {
      expect(appCheckUsesDebugProvider(environment: 'prod'), isFalse);
    });
  });
}
