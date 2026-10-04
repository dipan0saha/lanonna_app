import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/version/app_version_check.dart';

void main() {
  test('isAppVersionBelowMinimum compares semver triples', () {
    expect(isAppVersionBelowMinimum('0.9.9', '1.0.0'), isTrue);
    expect(isAppVersionBelowMinimum('1.0.0', '1.0.0'), isFalse);
    expect(isAppVersionBelowMinimum('1.0.1+5', '1.0.0'), isFalse);
    expect(isAppVersionBelowMinimum('1.1', '1.0.9'), isFalse);
  });
}
