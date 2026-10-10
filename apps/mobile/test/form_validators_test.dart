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

  test('optional http url validators', () {
    expect(validateOptionalHttpUrl(''), isNull);
    expect(validateOptionalHttpUrl('not-a-url'), isNotNull);
    expect(validateOptionalHttpUrl('https://example.com'), isNull);
    expect(
      normalizeOptionalHttpUrl('amazon.com/x'),
      'https://amazon.com/x',
    );
  });

  test('registry item and fun name validators', () {
    expect(validateRegistryItemName('  '), isNotNull);
    expect(validateRegistryItemName('Crib'), isNull);
    expect(validateFunNameSuggestion(''), isNotNull);
    expect(validateFunNameSuggestion('Ada'), isNull);
  });

  test('registry shipping validators', () {
    expect(validateRegistryShippingLine1('  '), isNotNull);
    expect(validateRegistryShippingLine1(' Main '), isNull);
    expect(validateCountryCode(null), isNotNull);
    expect(validateCountryCode('US'), isNull);
  });

  test('onboarding profile validators', () {
    expect(validateTermsAccepted(false), isNotNull);
    expect(validateTermsAccepted(true), isNull);
    expect(validateOnboardingRelationshipToBaby(null), isNotNull);
    expect(validateOnboardingRelationshipToBaby('Mother'), isNull);
    expect(validateOnboardingProfileDisplayName('Ada', 'Lovelace'), isNull);
    expect(
      validateOnboardingProfileDisplayName('x' * 50, 'y' * 51),
      'Display name is too long',
    );
  });
}
