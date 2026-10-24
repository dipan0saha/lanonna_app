import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/config/build_metadata.dart';

void main() {
  test('prod build stamp guard is wired for compilation', () {
    expect(prodBuildStampCheck, 1);
  });

  test('missing dart-defines resolve to unknown in non-prod builds', () {
    expect(BuildMetadata.gitSha, 'unknown');
    expect(BuildMetadata.buildNumber, 'unknown');
  });
}
