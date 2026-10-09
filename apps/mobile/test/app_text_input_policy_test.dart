import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/input/app_text_input_kind.dart';

void main() {
  group('AppTextInputPolicy.normalizeForSubmit', () {
    test('none trims only', () {
      expect(
        AppTextInputPolicy.normalizeForSubmit(AppTextInputKind.none, '  a  '),
        'a',
      );
    });

    test('personName capitalizes without flattening casing', () {
      expect(
        AppTextInputPolicy.normalizeForSubmit(
          AppTextInputKind.personName,
          'tristian',
        ),
        'Tristian',
      );
      expect(
        AppTextInputPolicy.normalizeForSubmit(
          AppTextInputKind.personName,
          'McKenzie',
        ),
        'McKenzie',
      );
      expect(
        AppTextInputPolicy.normalizeForSubmit(
          AppTextInputKind.personName,
          'QAFollowerName',
        ),
        'QAFollowerName',
      );
      expect(
        AppTextInputPolicy.normalizeForSubmit(
          AppTextInputKind.personName,
          'mary-kate',
        ),
        'Mary-Kate',
      );
    });

    test('prose sentence-cases', () {
      expect(
        AppTextInputPolicy.normalizeForSubmit(
          AppTextInputKind.prose,
          'jajaja',
        ),
        'Jajaja',
      );
    });
  });
}
