import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/domain/baby_summary.dart';
import 'package:lanonna/core/network/connectivity_service.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/features/calendar/data/calendar_repository.dart';
import 'package:lanonna/features/calendar/data/models/calendar_models.dart';
import 'package:lanonna/features/account/data/notifications_repository.dart';
import 'package:lanonna/features/home/data/home_repository.dart';
import 'package:lanonna/features/home/data/home_refresh_signal.dart';
import 'package:lanonna/features/home/data/selected_baby_store.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lanonna/features/calendar/presentation/calendar_screen.dart';

import 'support/fake_calendar_repository.dart';
import 'support/fake_home_repository.dart';
import 'support/fake_notifications_repository.dart';

void main() {
  testWidgets('CalendarRepository notifyListeners reloads upcoming list', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final prefs = await SharedPreferences.getInstance();
    final store = SelectedBabyStore(prefs);
    final calRepo = FakeCalendarRepository();
    final baby = BabySummary(
      id: 'baby-1',
      name: 'Test Baby',
      role: 'owner',
      lifecycleStatus: 'expecting',
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SelectedBabyStore>.value(value: store),
          ChangeNotifierProvider<CalendarRepository>.value(value: calRepo),
          ChangeNotifierProvider<HomeRefreshSignal>(
            create: (_) => HomeRefreshSignal(),
          ),
          ChangeNotifierProvider<ConnectivityService>(
            create: (_) => ConnectivityService.forTesting(),
          ),
          Provider<HomeRepository>(create: (_) => FakeHomeRepository(baby)),
          Provider<NotificationsRepository>(
            create: (_) => FakeNotificationsRepository(),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const CalendarScreen()),
      ),
    );
    await tester.pump();
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (find.text('No events yet').evaluate().isNotEmpty) break;
    }
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Calendar'), findsOneWidget);
    expect(find.byTooltip('Previous month'), findsOneWidget);
    expect(find.byTooltip('Next month'), findsOneWidget);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pump();
    expect(find.text('No events yet'), findsOneWidget);

    calRepo.upcomingEvents = [
      CalendarEvent(
        id: 'ev-1',
        title: 'Refresh Test Event',
        startsAt: DateTime.now().add(const Duration(hours: 2)),
      ),
    ];
    calRepo.notifyListeners();
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (find.text('Refresh Test Event').evaluate().isNotEmpty) break;
    }

    expect(find.text('Refresh Test Event'), findsOneWidget);
    expect(calRepo.listCalls, greaterThan(1));
  });
}
