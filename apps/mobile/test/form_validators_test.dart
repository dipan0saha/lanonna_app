import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/validation/form_validators.dart';

void main() {
  test('validateEmail rejects invalid', () {
    expect(validateEmail(''), isNotNull);
    expect(validateEmail('bad'), isNotNull);
    expect(validateEmail('a@b.com'), isNull);
  });

  test('validatePassword requires length and symbol or digit', () {
    expect(validatePassword('short'), isNotNull);
    expect(validatePassword('longenough'), isNotNull);
    expect(validatePassword('longenough1'), isNull);
  });
}
