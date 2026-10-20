import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/config/prod_config_guard.dart';

void main() {
  test('detects __PROD_ placeholders', () {
    expect(isProdPlaceholderValue('__PROD_API_BASE_URL__'), isTrue);
    expect(isProdPlaceholderValue('https://api.example.com'), isFalse);
    expect(isProdPlaceholderValue(''), isTrue);
  });
}
