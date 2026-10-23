import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:lanonna/core/validation/form_validators.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  test('validateEmail rejects invalid', () {
    expect(validateEmail(l10n, ''), isNotNull);
    expect(validateEmail(l10n, 'bad'), isNotNull);
    expect(validateEmail(l10n, 'a@b.com'), isNull);
  });

  test('validatePassword requires length and symbol or digit', () {
    expect(validatePassword(l10n, 'short'), isNotNull);
    expect(validatePassword(l10n, 'longenough'), isNotNull);
    expect(validatePassword(l10n, 'longenough1'), isNull);
  });

  test('optional http url validators', () {
    expect(validateOptionalHttpUrl(l10n, ''), isNull);
    expect(validateOptionalHttpUrl(l10n, 'not-a-url'), isNotNull);
    expect(validateOptionalHttpUrl(l10n, 'https://example.com'), isNull);
    expect(normalizeOptionalHttpUrl('amazon.com/x'), 'https://amazon.com/x');
    // Same rule as the API: https on a real host, in every environment.
    for (final link in [
      'http://example.com',
      'http://localhost/shop',
      'https://localhost/shop',
      'localhost:8080',
    ]) {
      expect(validateOptionalHttpUrl(l10n, link), isNotNull, reason: link);
    }
  });

  test('registry item and fun name validators', () {
    expect(validateRegistryItemName(l10n, '  '), isNotNull);
    expect(validateRegistryItemName(l10n, 'Crib'), isNull);
    expect(validateFunNameSuggestion(l10n, ''), isNotNull);
    expect(validateFunNameSuggestion(l10n, 'Ada'), isNull);
  });

  test('registry shipping validators', () {
    expect(validateRegistryShippingLine1(l10n, '  '), isNotNull);
    expect(validateRegistryShippingLine1(l10n, ' Main '), isNull);
    expect(validateCountryCode(l10n, null), isNotNull);
    expect(validateCountryCode(l10n, 'US'), isNull);
  });

  test('optional phone matches the profile API rules', () {
    expect(validateOptionalPhone(l10n, ''), isNull);
    expect(validateOptionalPhone(l10n, '   '), isNull);
    expect(validateOptionalPhone(l10n, 'abc'), l10n.validationPhoneInvalid);
    expect(validateOptionalPhone(l10n, '123'), l10n.validationPhoneInvalid);
    expect(validateOptionalPhone(l10n, '5550100'), isNull);
    expect(validateOptionalPhone(l10n, '+1 (555) 010-1234'), isNull);
    expect(validateOptionalPhone(l10n, '555-0100'), isNull);
    expect(validateOptionalPhone(l10n, '+123+4567'), l10n.validationPhoneInvalid);
  });

  test('onboarding profile validators', () {
    expect(validateTermsAccepted(l10n, false), isNotNull);
    expect(validateTermsAccepted(l10n, true), isNull);
    expect(validateOnboardingRelationshipToBaby(l10n, null), isNotNull);
    expect(validateOnboardingRelationshipToBaby(l10n, 'Mother'), isNull);
    expect(validateOnboardingProfileDisplayName(l10n, 'Ada', 'Lovelace'), isNull);
    expect(
      validateOnboardingProfileDisplayName(l10n, 'x' * 50, 'y' * 51),
      'Display name is too long',
    );
  });
}
