import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/features/calendar/data/models/calendar_models.dart';
import 'package:lanonna/features/calendar/domain/calendar_event_lists.dart';
import 'package:lanonna/features/calendar/presentation/widgets/calendar_today_upcoming_sections.dart';
import 'package:lanonna/l10n/app_localizations.dart';

void main() {
  testWidgets('shows Today and Upcoming section headers', (tester) async {
    final buckets = CalendarEventBuckets(
      today: [
        CalendarEvent(
          id: 't1',
          title: 'Today event',
          startsAt: DateTime(2026, 10, 12, 9),
        ),
      ],
      upcoming: [
        CalendarEvent(
          id: 'u1',
          title: 'Later event',
          startsAt: DateTime(2026, 10, 14, 10),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light,
        home: Scaffold(
          body: CalendarTodayUpcomingSections(buckets: buckets),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('UPCOMING'), findsOneWidget);
    expect(find.text('Today event'), findsOneWidget);
    expect(find.text('Later event'), findsOneWidget);
  });

  testWidgets('hides Today header when today bucket is empty', (tester) async {
    final buckets = CalendarEventBuckets(
      today: const [],
      upcoming: [
        CalendarEvent(
          id: 'u1',
          title: 'Future only',
          startsAt: DateTime(2026, 10, 14, 10),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light,
        home: Scaffold(
          body: CalendarTodayUpcomingSections(buckets: buckets),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('TODAY'), findsNothing);
    expect(find.text('UPCOMING'), findsOneWidget);
    expect(find.text('Future only'), findsOneWidget);
  });
}
