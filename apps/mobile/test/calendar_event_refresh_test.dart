import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/domain/baby_summary.dart';
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

class _FakeNotificationsRepository extends NotificationsRepository {
  _FakeNotificationsRepository() : super(ApiClient(idTokenProvider: () async => null));

  @override
  Future<int> unreadCount() async => 0;
}

class _FakeHomeRepository extends HomeRepository {
  _FakeHomeRepository(this.baby) : super(ApiClient(idTokenProvider: () async => null));

  final BabySummary baby;

  @override
  Future<BabySummary?> resolveSelectedBaby(SelectedBabyStore store) async => baby;
}

class _FakeCalendarRepository extends CalendarRepository {
  _FakeCalendarRepository() : super(ApiClient(idTokenProvider: () async => null));

  int listCalls = 0;
  List<CalendarEvent> upcomingEvents = const [];

  @override
  Future<List<CalendarEvent>> listEvents(
    String babyId, {
    String? month,
    bool upcoming = false,
  }) async {
    listCalls++;
    return upcomingEvents;
  }
}

void main() {
  testWidgets('CalendarRepository notifyListeners reloads upcoming list', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final prefs = await SharedPreferences.getInstance();
    final store = SelectedBabyStore(prefs);
    final calRepo = _FakeCalendarRepository();
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
          ChangeNotifierProvider<HomeRefreshSignal>(create: (_) => HomeRefreshSignal()),
          Provider<HomeRepository>(create: (_) => _FakeHomeRepository(baby)),
          Provider<NotificationsRepository>(
            create: (_) => _FakeNotificationsRepository(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const CalendarScreen(),
        ),
      ),
    );
    await tester.pump();
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (find.text('No events yet').evaluate().isNotEmpty) break;
    }
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Calendar'), findsOneWidget);
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
