import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/input/prose_sentence_input.dart';

void main() {
  group('formatProseSentence', () {
    test('empty and whitespace', () {
      expect(formatProseSentence(''), '');
      expect(formatProseSentence('   '), '');
    });

    test('single word lowercase', () {
      expect(formatProseSentence('jajaja'), 'Jajaja');
    });

    test('leading whitespace trimmed', () {
      expect(formatProseSentence('  hello'), 'Hello');
    });

    test('after sentence terminator', () {
      expect(formatProseSentence('hi. there'), 'Hi. There');
      expect(formatProseSentence('wow! yes'), 'Wow! Yes');
      expect(formatProseSentence('really? ok'), 'Really? Ok');
    });

    test('multiline', () {
      expect(formatProseSentence('line one\nline two'), 'Line one\nLine two');
    });

    test('preserves mid-word caps', () {
      expect(formatProseSentence('iPhone'), 'IPhone');
    });
  });

  group('SentenceCaseInputFormatter', () {
    const formatter = SentenceCaseInputFormatter();

    test('capitalizes first letter while typing', () {
      const oldValue = TextEditingValue.empty;
      const newValue = TextEditingValue(
        text: 'j',
        selection: TextSelection.collapsed(offset: 1),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);

      expect(result.text, 'J');
    });

    test('capitalizes after period', () {
      const oldValue = TextEditingValue(
        text: 'Hi. t',
        selection: TextSelection.collapsed(offset: 5),
      );
      const newValue = TextEditingValue(
        text: 'Hi. there',
        selection: TextSelection.collapsed(offset: 9),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);

      expect(result.text, 'Hi. There');
    });
  });
}
