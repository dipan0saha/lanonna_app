import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/features/registry/domain/registry_shipping_input.dart';

void main() {
  group('formatRegistryShippingRegion', () {
    test('empty and whitespace', () {
      expect(formatRegistryShippingRegion(''), '');
      expect(formatRegistryShippingRegion('   '), '');
    });

    test('short alphabetic codes uppercase on submit', () {
      expect(formatRegistryShippingRegion('nc'), 'NC');
      expect(formatRegistryShippingRegion('on'), 'ON');
      expect(formatRegistryShippingRegion(' il '), 'IL');
    });

    test('longer names stay title case', () {
      expect(formatRegistryShippingRegion('north carolina'), 'North Carolina');
      expect(formatRegistryShippingRegion('British Columbia'), 'British Columbia');
    });

    test('non pure-alpha short codes are not forced upper', () {
      expect(formatRegistryShippingRegion('N.C.'), 'N.C.');
    });
  });
}
