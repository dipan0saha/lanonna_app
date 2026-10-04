import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/features/calendar/presentation/calendar_display.dart';

void main() {
  test('eventLocalStart converts UTC to local', () {
    final utc = DateTime.utc(2026, 10, 5, 4, 0);
    final local = eventLocalStart(utc);
    expect(local.isUtc, isFalse);
  });

  test('eventOnLocalMonthDay uses local calendar month', () {
    final utc = DateTime.utc(2026, 10, 15, 12, 0);
    expect(eventOnLocalMonthDay(utc, DateTime(2026, 9, 1)), isFalse);
    expect(eventOnLocalMonthDay(utc, DateTime(2026, 10, 1)), isTrue);
  });

  test('eventLocalDayOfMonth returns local day', () {
    final utc = DateTime.utc(2026, 3, 1, 3, 0);
    expect(eventLocalDayOfMonth(utc), eventLocalStart(utc).day);
  });
}
