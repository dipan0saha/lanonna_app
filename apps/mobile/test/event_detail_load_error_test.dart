import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/api/api_exception.dart';
import 'package:lanonna/core/domain/baby_lifecycle.dart';
import 'package:lanonna/core/domain/baby_summary.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/features/calendar/data/calendar_repository.dart';
import 'package:lanonna/features/calendar/data/models/calendar_models.dart';
import 'package:lanonna/features/calendar/presentation/event_detail_screen.dart';
import 'package:lanonna/features/home/data/home_repository.dart';
import 'package:lanonna/features/home/data/selected_baby_store.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_calendar_repository.dart';
import 'support/fake_home_repository.dart';

EventDetail _event() => EventDetail(
  id: 'ev-1',
  title: 'Baby shower',
  description: null,
  startsAt: DateTime.utc(2026, 6, 1, 16),
  endsAt: null,
  location: null,
  videoCallUrl: null,
  coverPhotoId: null,
  coverPhotoDisplayUrl: null,
  rsvpSummary: RsvpSummary(going: 0, maybe: 0, cantGo: 0),
  viewerRsvp: null,
  rsvpAttendees: [],
  comments: [],
);

Future<void> _pump(WidgetTester tester, CalendarRepository repo) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SelectedBabyStore(prefs)),
        ChangeNotifierProvider<CalendarRepository>.value(value: repo),
        Provider<HomeRepository>(
          create: (_) => FakeHomeRepository(
            BabySummary(
              id: 'baby-1',
              name: 'Test Baby',
              role: 'follower',
              lifecycle: BabyLifecycle.expecting,
            ),
          ),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const EventDetailScreen(eventId: 'ev-1'),
      ),
    ),
  );
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  testWidgets('a non-404 load failure shows Try again, then loads', (
    tester,
  ) async {
    var fail = true;
    final repo = FakeCalendarRepository(
      detailByFetch: () {
        if (fail) throw ApiException('unavailable', statusCode: 503);
        return _event();
      },
    );
    await _pump(tester, repo);

    expect(find.text('Event not found'), findsNothing);
    expect(find.byKey(const Key('load_error_retry')), findsOneWidget);

    fail = false;
    await tester.tap(find.byKey(const Key('load_error_retry')));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.text('Baby shower'), findsOneWidget);
  });

  testWidgets('a 404 says the event is not found', (tester) async {
    final repo = FakeCalendarRepository(
      detailByFetch: () => throw ApiException('gone', statusCode: 404),
    );
    await _pump(tester, repo);

    expect(find.byKey(const Key('load_error_retry')), findsNothing);
    expect(find.text('Event not found'), findsOneWidget);
  });
}
