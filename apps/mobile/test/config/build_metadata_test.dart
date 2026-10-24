import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/config/app_config.dart';
import 'package:lanonna/config/build_metadata.dart';

void main() {
  test('prod build stamp guard passes for non-prod builds', () {
    expect(prodBuildStampCheck, 1);
  });

  test('missing dart-defines resolve to unknown in non-prod builds', () {
    expect(BuildMetadata.gitSha, BuildMetadata.unknown);
    expect(BuildMetadata.buildNumber, BuildMetadata.unknown);
    expect(BuildMetadata.environment, 'dev');
  });
}
