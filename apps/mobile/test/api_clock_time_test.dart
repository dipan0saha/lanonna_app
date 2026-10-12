import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/time/app_date_time.dart';

void main() {
  test('API birth time 15:30 displays as 3:30 PM in en_US', () {
    final formatted = formatApiClockTime('15:30', 'en_US');
    expect(formatted.replaceAll(RegExp(r'\s+'), ' '), '3:30 PM');
  });

  test('blank or invalid clock times display as empty', () {
    expect(formatApiClockTime(null, 'en_US'), isEmpty);
    expect(formatApiClockTime('   ', 'en_US'), isEmpty);
    expect(formatApiClockTime('25:00', 'en_US'), isEmpty);
  });
}
