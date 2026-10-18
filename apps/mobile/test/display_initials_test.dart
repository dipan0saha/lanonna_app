import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/presentation/display_initials.dart';
import 'package:lanonna/core/widgets/avatar_initials.dart';

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

  test('the display name wins over the fallback', () {
    expect(displayInitials('Priya', fallbackText: 'zed@test.com'), 'P');
  });

  test('returns null when nothing is known (no placeholder word)', () {
    expect(displayInitials(null), isNull);
    expect(displayInitials('  ', fallbackText: ' '), isNull);
  });

  test('keeps whole characters (accents, emoji)', () {
    expect(displayInitials('élodie roux'), 'ÉR');
    expect(displayInitials('👶🏽 Nonna'), '👶🏽N');
  });

  group('AvatarInitials', () {
    Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Center(child: child)),
      ),
    );

    testWidgets('shows the initials of the display name', (tester) async {
      await pump(
        tester,
        const AvatarInitials(
          name: 'Dana Lee',
          fallbackText: 'x@y.z',
          style: null,
        ),
      );
      expect(find.text('DL'), findsOneWidget);
    });

    testWidgets(
      'shows the neutral glyph, not a letter, when nothing is known',
      (tester) async {
        await pump(tester, const AvatarInitials(name: null, style: null));
        expect(find.byIcon(Icons.person_outline), findsOneWidget);
        expect(find.byType(Text), findsNothing);
      },
    );
  });
}
