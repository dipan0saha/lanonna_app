import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/config/app_config.dart';

void main() {
  test('dev API base URL is set', () {
    expect(AppConfig.apiBaseUrl, isNotEmpty);
    expect(AppConfig.apiBaseUrl, startsWith('https://'));
  });
}
