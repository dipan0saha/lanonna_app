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

    test('personName title-cases', () {
      expect(
        AppTextInputPolicy.normalizeForSubmit(
          AppTextInputKind.personName,
          'tristian',
        ),
        'Tristian',
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
