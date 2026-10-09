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
      expect(formatPersonName('james'), 'James');
    });

    test('multi-word', () {
      expect(formatPersonName('  mary   jane '), 'Mary Jane');
      expect(formatPersonName('anne marie'), 'Anne Marie');
    });

    test('preserves internal capitals', () {
      expect(formatPersonName('McKenzie'), 'McKenzie');
      expect(formatPersonName('DeShawn'), 'DeShawn');
      expect(formatPersonName('QAFollowerName'), 'QAFollowerName');
      expect(formatPersonName('QAOwnerName'), 'QAOwnerName');
    });

    test('hyphen and apostrophe parts', () {
      expect(formatPersonName('mary-kate'), 'Mary-Kate');
      expect(formatPersonName("o'brien"), "O'Brien");
      expect(formatPersonName('Anne-Marie'), 'Anne-Marie');
    });

    test('already capitalized', () {
      expect(formatPersonName('Olivia'), 'Olivia');
    });

    test('all caps unchanged except leading letter rule', () {
      expect(formatPersonName('JAMES'), 'JAMES');
    });
  });

  group('applyPersonNameCapitalization', () {
    test('matches formatPersonName for collapsed input', () {
      expect(applyPersonNameCapitalization('McKenzie'), 'McKenzie');
    });
  });

  group('PersonNameInputFormatter', () {
    const formatter = PersonNameInputFormatter();

    test('capitalizes first letter while typing', () {
      const oldValue = TextEditingValue.empty;
      const newValue = TextEditingValue(
        text: 't',
        selection: TextSelection.collapsed(offset: 1),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);

      expect(result.text, 'T');
      expect(result.selection.baseOffset, 1);
    });

    test('preserves internal capitals while typing', () {
      const oldValue = TextEditingValue(
        text: 'Mc',
        selection: TextSelection.collapsed(offset: 2),
      );
      const newValue = TextEditingValue(
        text: 'McK',
        selection: TextSelection.collapsed(offset: 3),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);

      expect(result.text, 'McK');
    });

    test('lowercases-only word becomes Tristian on paste', () {
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
