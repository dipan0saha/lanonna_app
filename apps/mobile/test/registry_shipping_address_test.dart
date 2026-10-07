import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/features/registry/data/models/registry_models.dart';

void main() {
  test('RegistryShippingAddress fromJson and isEmpty', () {
    final empty = RegistryShippingAddress.fromJson({});
    expect(empty.isEmpty, isTrue);
    expect(empty.formatted, isNull);

    final full = RegistryShippingAddress.fromJson({
      'line1': '123 Main St',
      'city': 'Austin',
      'postal_code': '78701',
      'country_code': 'US',
      'formatted': '123 Main St\nAustin, 78701\nUS',
    });
    expect(full.isEmpty, isFalse);
    expect(full.line1, '123 Main St');
    expect(full.postalCode, '78701');
  });

  test('toPatchJson trims empty strings to null', () {
    final patch = RegistryShippingAddress(
      line1: ' 123 ',
      city: 'Austin',
      postalCode: '78701',
      countryCode: 'US',
    ).toPatchJson();
    expect(patch['line1'], '123');
    expect(patch['line2'], isNull);
  });

  test('clearPatchJson nulls all fields', () {
    final patch = RegistryShippingAddress.clearPatchJson();
    expect(patch.values.every((v) => v == null), isTrue);
  });
}
