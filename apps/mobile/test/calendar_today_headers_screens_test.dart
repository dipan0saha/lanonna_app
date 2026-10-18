import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/domain/baby_lifecycle.dart';
import 'package:lanonna/core/domain/baby_summary.dart';
import 'package:lanonna/core/network/connectivity_service.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/features/calendar/data/calendar_repository.dart';
import 'package:lanonna/features/calendar/data/models/calendar_models.dart';
import 'package:lanonna/features/calendar/presentation/calendar_screen.dart';
import 'package:lanonna/features/calendar/presentation/calendar_upcoming_screen.dart';
import 'package:lanonna/features/home/data/home_refresh_signal.dart';
import 'package:lanonna/features/home/data/home_repository.dart';
import 'package:lanonna/features/home/data/selected_baby_store.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lanonna/l10n/app_localizations.dart';

import 'support/fake_calendar_repository.dart';
import 'support/fake_home_repository.dart';
import 'support/fake_notifications_repository.dart';

void main() {
  final baby = BabySummary(
    id: 'baby-1',
    name: 'Test Baby',
    role: 'owner',
    lifecycle: BabyLifecycle.expecting,
  );

  late FakeCalendarRepository calRepo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    calRepo = FakeCalendarRepository();
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day, 9);
    final tomorrow = todayStart.add(const Duration(days: 1));
    calRepo.monthEvents = [
      CalendarEvent(id: 'today', title: 'Gender reveal', startsAt: todayStart),
    ];
    calRepo.upcomingEvents = [
      CalendarEvent(id: 'today', title: 'Gender reveal', startsAt: todayStart),
      CalendarEvent(id: 'later', title: 'Shower', startsAt: tomorrow),
    ];
  });

  Future<void> pumpCalendarTab(WidgetTester tester) async {
    final prefs = await SharedPreferences.getInstance();
    final store = SelectedBabyStore(prefs);
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SelectedBabyStore>.value(value: store),
          ChangeNotifierProvider<CalendarRepository>.value(value: calRepo),
          Provider<HomeRefreshSignal>(create: (_) => HomeRefreshSignal()),
          ChangeNotifierProvider<ConnectivityService>(
            create: (_) => ConnectivityService.forTesting(),
          ),
          Provider<HomeRepository>(create: (_) => FakeHomeRepository(baby)),
          ...shellTopBarTestProviders(),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.light,
          home: const CalendarScreen(),
        ),
      ),
    );
    await tester.pump();
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (find.text('TODAY').evaluate().isNotEmpty) break;
    }
  }

  Future<void> pumpUpcomingScreen(WidgetTester tester) async {
    final prefs = await SharedPreferences.getInstance();
    final store = SelectedBabyStore(prefs);
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SelectedBabyStore>.value(value: store),
          ChangeNotifierProvider<CalendarRepository>.value(value: calRepo),
          Provider<HomeRefreshSignal>(create: (_) => HomeRefreshSignal()),
          ChangeNotifierProvider<ConnectivityService>(
            create: (_) => ConnectivityService.forTesting(),
          ),
          Provider<HomeRepository>(create: (_) => FakeHomeRepository(baby)),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.light,
          home: const CalendarUpcomingScreen(),
        ),
      ),
    );
    await tester.pump();
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (find.text('TODAY').evaluate().isNotEmpty) break;
    }
  }

  testWidgets('Calendar tab shows Today and Upcoming headers', (tester) async {
    await pumpCalendarTab(tester);
    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('UPCOMING'), findsOneWidget);
    expect(find.text('Gender reveal'), findsOneWidget);
  });

  testWidgets('view-all upcoming screen shows Today and Upcoming headers', (
    tester,
  ) async {
    await pumpUpcomingScreen(tester);
    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('UPCOMING'), findsOneWidget);
    expect(find.text('Gender reveal'), findsOneWidget);
    expect(find.text('Shower'), findsOneWidget);
  });
}
