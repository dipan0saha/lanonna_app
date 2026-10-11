import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/presentation/display_initials.dart';

void main() {
  test('uses the first letters of the first two words', () {
    expect(displayInitials('Sarah Parker'), 'SP');
    expect(displayInitials('  maria  del  carmen '), 'MD');
  });

  test('uses a single initial for one word', () {
    expect(displayInitials('Alex'), 'A');
  });

  test('falls back to fallbackText when the name is blank', () {
    expect(displayInitials(null, fallbackText: 'sam@test.com'), 'S');
    expect(displayInitials('   ', fallbackText: 'sam@test.com'), 'S');
  });

  test('returns the empty fallback when everything is blank', () {
    expect(displayInitials(null), '?');
    expect(displayInitials('  ', fallbackText: ' '), '?');
    expect(displayInitials(null, emptyFallback: 'A'), 'A');
  });
}
