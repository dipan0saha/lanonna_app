import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/domain/baby_summary.dart';
import 'package:lanonna/core/presentation/detail_screen_load.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/features/calendar/data/calendar_repository.dart';
import 'package:lanonna/features/calendar/data/models/calendar_models.dart';
import 'package:lanonna/features/calendar/presentation/event_detail_screen.dart';
import 'package:lanonna/features/home/data/home_repository.dart';
import 'package:lanonna/features/home/data/selected_baby_store.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeHomeRepository extends HomeRepository {
  _FakeHomeRepository(this.baby) : super(ApiClient(idTokenProvider: () async => null));

  final BabySummary baby;

  @override
  Future<BabySummary?> resolveSelectedBaby(SelectedBabyStore store) async => baby;
}

class _FakeCalendarRepository extends CalendarRepository {
  _FakeCalendarRepository(this._detailByFetch)
      : super(ApiClient(idTokenProvider: () async => null));

  final EventDetail Function() _detailByFetch;
  int fetchCalls = 0;

  @override
  Future<EventDetail> fetchEvent(String babyId, String eventId) async {
    fetchCalls++;
    return _detailByFetch();
  }
}

EventDetail _eventDetail({required String title}) {
  return EventDetail(
    id: 'ev-1',
    title: title,
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
}

void main() {
  test('silent refresh keeps content visible while reloading', () {
    expect(
      shouldShowDetailFullScreenLoader(
        hasContent: true,
        initialLoadInFlight: true,
      ),
      isFalse,
    );
  });

  testWidgets('CalendarRepository notifyListeners refreshes event detail title',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    var title = 'Before edit';
    final calRepo = _FakeCalendarRepository(() => _eventDetail(title: title));
    final baby = BabySummary(
      id: 'baby-1',
      name: 'Test Baby',
      role: 'owner',
      lifecycleStatus: 'expecting',
    );
    final prefs = await SharedPreferences.getInstance();
    final store = SelectedBabyStore(prefs);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SelectedBabyStore>.value(value: store),
          ChangeNotifierProvider<CalendarRepository>.value(value: calRepo),
          Provider<HomeRepository>(create: (_) => _FakeHomeRepository(baby)),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const EventDetailScreen(eventId: 'ev-1'),
        ),
      ),
    );
    await tester.pump();
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (find.text('Before edit').evaluate().isNotEmpty) break;
    }
    expect(find.text('Before edit'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    title = 'After edit';
    calRepo.notifyListeners();
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (find.text('After edit').evaluate().isNotEmpty) break;
    }

    expect(find.text('After edit'), findsOneWidget);
    expect(calRepo.fetchCalls, greaterThan(1));
  });
}
