import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/auth/auth_repository.dart';
import 'package:lanonna/core/domain/baby_summary.dart';
import 'package:lanonna/core/network/connectivity_service.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/features/account/data/notifications_repository.dart';
import 'package:lanonna/features/account/presentation/notifications_inbox_screen.dart';
import 'package:lanonna/features/announcement/data/announcement_repository.dart';
import 'package:lanonna/features/announcement/presentation/announcement_card_screen.dart';
import 'package:lanonna/features/calendar/data/calendar_repository.dart';
import 'package:lanonna/features/calendar/data/models/calendar_models.dart';
import 'package:lanonna/features/calendar/presentation/event_detail_screen.dart';
import 'package:lanonna/features/fun/data/fun_repository.dart';
import 'package:lanonna/features/fun/data/models/fun_models.dart';
import 'package:lanonna/features/fun/presentation/names_tab.dart';
import 'package:lanonna/features/fun/presentation/predictions_tab.dart';
import 'package:lanonna/features/home/data/home_refresh_signal.dart';
import 'package:lanonna/features/home/data/home_repository.dart';
import 'package:lanonna/features/home/data/selected_baby_store.dart';
import 'package:lanonna/features/onboarding/presentation/widgets/onboarding_fields.dart';
import 'package:lanonna/features/registry/data/models/registry_models.dart';
import 'package:lanonna/features/registry/data/registry_repository.dart';
import 'package:lanonna/features/registry/presentation/registry_screen.dart';
import 'package:lanonna/features/registry/presentation/widgets/registry_item_row.dart';
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

  testWidgets('registry edit, delete, and add item are labeled', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: RegistryNeededRow(
            item: RegistryItem(
              id: 'item-1',
              name: 'Crib',
              priority: 1,
              isPurchased: false,
            ),
            isOwner: true,
            currentUid: 'uid-1',
            onEdit: () {},
            onDelete: () {},
          ),
        ),
      ),
    );

    expect(find.byTooltip('Edit item'), findsOneWidget);
    expect(find.byTooltip('Delete item'), findsOneWidget);
  });

  testWidgets('registry add item button is labeled', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<HomeRepository>.value(value: _Home()),
          ChangeNotifierProvider<SelectedBabyStore>.value(
            value: SelectedBabyStore(prefs),
          ),
          Provider<HomeRefreshSignal>(
            create: (_) => HomeRefreshSignal(),
          ),
          ChangeNotifierProvider<ConnectivityService>.value(
            value: ConnectivityService.forTesting(),
          ),
          Provider<RegistryRepository>.value(value: _Registry()),
          Provider<AuthRepository>.value(value: _Auth()),
          Provider<NotificationsRepository>.value(value: _Inbox()),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const RegistryScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byTooltip('Add item'), findsOneWidget);
  });

  testWidgets('name love and remove are labeled', (tester) async {
    const baby = BabySummary(
      id: 'baby-1',
      name: 'Parker',
      lifecycleStatus: 'born',
      role: 'owner',
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Provider<FunRepository>.value(
            value: _Fun(
              names: NamesPayload(
                suggestions: [
                  NameSuggestion(
                    id: 'name-1',
                    suggestedName: 'Ada',
                    gender: 'female',
                    likeCount: 1,
                    viewerHasLiked: false,
                    isMine: true,
                    canDelete: true,
                    authorDisplayName: 'Alex',
                  ),
                ],
              ),
            ),
            child: const NamesTab(baby: baby),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Love Ada'), findsOneWidget);
    expect(find.byTooltip('Remove Ada'), findsOneWidget);
  });

  testWidgets('prediction month arrows are labeled', (tester) async {
    const baby = BabySummary(
      id: 'baby-1',
      name: 'Parker',
      lifecycleStatus: 'expecting',
      role: 'follower',
      expectedBirthDate: '2027-02-01',
    );
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Provider<FunRepository>.value(
            value: _Fun(
              predictions: PredictionsPayload(
                maleVotes: 0,
                femaleVotes: 0,
                birthdateHistogram: const [],
                genderVoters: const [],
              ),
            ),
            child: const PredictionsTab(baby: baby),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byTooltip('Previous month'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.byTooltip('Previous month'), findsOneWidget);
    expect(find.byTooltip('Next month'), findsOneWidget);
  });

  testWidgets('notification rows are labeled', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Provider<NotificationsRepository>.value(
          value: _Inbox(),
          child: const NotificationsInboxScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsIdentifier('notification_n1'), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsIdentifier('notification_n1')).label,
      contains('New photo'),
    );
  });

  testWidgets('password show and hide is labeled', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OnboardingPasswordField(
            controller: TextEditingController(),
            label: 'Password',
          ),
        ),
      ),
    );

    expect(find.byTooltip('Show password'), findsOneWidget);
  });
}

class _Auth extends AuthRepository {
  _Auth() : super(firebaseAuth: _FakeFirebaseAuth());

  @override
  User? get currentUser => null;
}

class _FakeFirebaseAuth extends Fake implements FirebaseAuth {}

class _Registry extends RegistryRepository {
  _Registry() : super(ApiClient(idTokenProvider: () async => 't'));

  @override
  Future<List<RegistryItem>> listItems(String babyId) async {
    return [
      RegistryItem(id: 'item-1', name: 'Crib', priority: 1, isPurchased: false),
    ];
  }

  @override
  Future<RegistryShippingAddress> getShippingAddress(String babyId) async {
    return const RegistryShippingAddress();
  }
}

class _Fun extends FunRepository {
  _Fun({this.names, this.predictions})
    : super(ApiClient(idTokenProvider: () async => 't'));

  final NamesPayload? names;
  final PredictionsPayload? predictions;

  @override
  Future<NamesPayload> fetchNames(String babyId) async => names!;

  @override
  Future<PredictionsPayload> fetchPredictions(String babyId) async =>
      predictions!;
}

class _Inbox extends NotificationsRepository {
  _Inbox() : super(ApiClient(idTokenProvider: () async => 't'));

  @override
  Future<int> unreadCount() async => 0;

  @override
  Future<List<InboxNotification>> listInbox() async {
    return [
      InboxNotification(
        id: 'n1',
        title: 'New photo',
        body: 'Alex added a photo',
      ),
    ];
  }
}
