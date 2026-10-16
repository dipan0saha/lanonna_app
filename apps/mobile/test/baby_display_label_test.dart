import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/domain/baby_display_label.dart';

void main() {
  test('babyDisplayName uses the name as entered, never prefixed', () {
    expect(babyDisplayName('Baby Parker'), 'Baby Parker');
    expect(babyDisplayName('  Parker '), 'Parker');
    expect(babyDisplayName(''), 'your baby');
    expect(babyDisplayName(null), 'your baby');
  });
}
