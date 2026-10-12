import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/domain/baby_summary.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/features/announcement/data/announcement_repository.dart';
import 'package:lanonna/features/announcement/presentation/announcement_card_screen.dart';
import 'package:lanonna/features/calendar/data/calendar_repository.dart';
import 'package:lanonna/features/calendar/data/models/calendar_models.dart';
import 'package:lanonna/features/calendar/presentation/event_detail_screen.dart';
import 'package:lanonna/features/home/data/home_repository.dart';
import 'package:lanonna/features/home/data/selected_baby_store.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Home extends HomeRepository {
  _Home() : super(ApiClient(idTokenProvider: () async => 't'));

  static const baby = BabySummary(
    id: 'baby-1',
    name: 'Parker',
    lifecycleStatus: 'born',
    role: 'owner',
  );

  @override
  Future<BabySummary?> resolveSelectedBaby(SelectedBabyStore store) async =>
      baby;

  @override
  Future<BabySummary?> babyById(String babyId) async => baby;
}

class _Calendar extends CalendarRepository {
  _Calendar() : super(ApiClient(idTokenProvider: () async => 't'));

  @override
  Future<EventDetail> fetchEvent(String babyId, String eventId) async {
    return EventDetail(
      id: eventId,
      title: 'Lunch',
      startsAt: DateTime.utc(2026, 10, 2, 15),
      rsvpSummary: RsvpSummary(going: 0, maybe: 0, cantGo: 0),
      rsvpAttendees: const [],
      comments: [
        EventComment(
          id: 'c1',
          body: 'See you',
          authorDisplayName: 'Alex',
          isMine: true,
          canEdit: true,
          canDelete: true,
        ),
      ],
    );
  }
}

class _Announcements extends AnnouncementRepository {
  _Announcements() : super(ApiClient(idTokenProvider: () async => 't'));

  @override
  Future<AnnouncementDetail?> fetch(String babyId) async {
    return AnnouncementDetail(
      id: 'ann-1',
      firstName: 'Parker',
      squishCount: 0,
      commentCount: 0,
      comments: const [],
    );
  }
}

Future<void> _pump(
  WidgetTester tester,
  Widget home,
  List<SingleChildWidget> extras,
) async {
  await tester.binding.setSurfaceSize(const Size(800, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<HomeRepository>.value(value: _Home()),
        ChangeNotifierProvider<SelectedBabyStore>.value(
          value: SelectedBabyStore(prefs),
        ),
        ...extras,
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('event edit, delete, and comment actions are labeled', (
    tester,
  ) async {
    await _pump(tester, const EventDetailScreen(eventId: 'event-1'), [
      ChangeNotifierProvider<CalendarRepository>(create: (_) => _Calendar()),
    ]);

    expect(find.byTooltip('Edit event'), findsOneWidget);
    expect(find.byTooltip('Delete event'), findsOneWidget);
    expect(find.byTooltip('Edit comment'), findsOneWidget);
    expect(find.byTooltip('Delete comment'), findsOneWidget);
  });

  testWidgets('keepsake share and edit are labeled', (tester) async {
    await _pump(tester, const AnnouncementCardScreen(babyId: 'baby-1'), [
      Provider<AnnouncementRepository>.value(value: _Announcements()),
    ]);

    expect(find.byTooltip('Share announcement'), findsOneWidget);
    expect(find.byTooltip('Edit announcement'), findsOneWidget);
  });
}
