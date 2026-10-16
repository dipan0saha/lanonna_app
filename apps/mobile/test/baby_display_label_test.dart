import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/domain/baby_display_label.dart';

void main() {
  test('babyNotificationLabel avoids duplicate Baby prefix', () {
    expect(babyNotificationLabel('Baby Parker'), 'Baby Parker');
    expect(babyNotificationLabel('baby parker'), 'baby parker');
    expect(babyNotificationLabel('Parker'), 'Baby Parker');
    expect(babyNotificationLabel(''), 'your baby');
  });
}
