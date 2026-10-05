import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/features/home/presentation/widgets/home_section_header.dart';

double _titleLeft(WidgetTester tester, String upperTitle) {
  final finder = find.text(upperTitle);
  expect(finder, findsOneWidget);
  final box = tester.renderObject<RenderBox>(finder);
  return box.localToGlobal(Offset.zero).dx;
}

void main() {
  testWidgets('title-only and title with View all share left inset', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const HomeSectionHeader(title: 'RSVP Reminders'),
              HomeSectionHeader(
                title: 'Upcoming Events',
                action: TextButton(
                  onPressed: () {},
                  child: const Text('View all'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final rsvpLeft = _titleLeft(tester, 'RSVP REMINDERS');
    final upcomingLeft = _titleLeft(tester, 'UPCOMING EVENTS');
    expect(upcomingLeft, closeTo(rsvpLeft, 0.5));
  });
}
