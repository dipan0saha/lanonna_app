import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/input/person_name_input.dart';

void main() {
  group('formatPersonName', () {
    test('empty and whitespace', () {
      expect(formatPersonName(''), '');
      expect(formatPersonName('   '), '');
    });

    test('single word lowercase', () {
      expect(formatPersonName('tristian'), 'Tristian');
    });

    test('multi-word', () {
      expect(formatPersonName('  mary   jane '), 'Mary Jane');
    });

    test('already capitalized', () {
      expect(formatPersonName('Olivia'), 'Olivia');
    });
  });

  group('TitleCaseWordsInputFormatter', () {
    const formatter = TitleCaseWordsInputFormatter();

    test('capitalizes first letter while typing', () {
      const oldValue = TextEditingValue.empty;
      const newValue = TextEditingValue(text: 't', selection: TextSelection.collapsed(offset: 1));

      final result = formatter.formatEditUpdate(oldValue, newValue);

      expect(result.text, 'T');
      expect(result.selection.baseOffset, 1);
    });

    test('title-cases full word', () {
      const oldValue = TextEditingValue(
        text: 'Trist',
        selection: TextSelection.collapsed(offset: 5),
      );
      const newValue = TextEditingValue(
        text: 'tristian',
        selection: TextSelection.collapsed(offset: 8),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);

      expect(result.text, 'Tristian');
    });
  });
}
