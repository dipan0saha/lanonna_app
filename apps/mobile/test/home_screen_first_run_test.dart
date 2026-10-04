import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/features/home/data/home_refresh_signal.dart';
import 'package:lanonna/features/home/data/home_repository.dart';
import 'package:lanonna/features/home/data/home_summary_result.dart';
import 'package:lanonna/features/home/data/models/home_summary.dart';
import 'package:lanonna/features/home/data/selected_baby_store.dart';
import 'package:lanonna/features/home/home_screen.dart';
import 'package:lanonna/core/domain/baby_summary.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('owner expecting home shows countdown and family insight', (tester) async {
    SharedPreferences.setMockInitialValues({'selected_baby_id': 'baby-1'});

    final repo = _FakeHomeRepository();
    final store = SelectedBabyStore(await SharedPreferences.getInstance());

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<HomeRepository>.value(value: repo),
          ChangeNotifierProvider<SelectedBabyStore>.value(value: store),
          ChangeNotifierProvider<HomeRefreshSignal>(
            create: (_) => HomeRefreshSignal(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const HomeScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('Waiting for'), findsOneWidget);
    expect(find.text('DAYS TO DUE DATE'), findsOneWidget);
    expect(find.text('FAMILY INSIGHT'), findsOneWidget);
    expect(find.text('Invite'), findsOneWidget);
    expect(find.text('Announce Arrival'), findsOneWidget);
  });

  testWidgets('owner born home shows recent activity not invite', (tester) async {
    SharedPreferences.setMockInitialValues({'selected_baby_id': 'baby-2'});

    final repo = _FakeHomeRepository();
    final store = SelectedBabyStore(await SharedPreferences.getInstance());

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<HomeRepository>.value(value: repo),
          ChangeNotifierProvider<SelectedBabyStore>.value(value: store),
          ChangeNotifierProvider<HomeRefreshSignal>(
            create: (_) => HomeRefreshSignal(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const HomeScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('ACTIVITY RECAP'), findsOneWidget);
    expect(find.text('Invite'), findsNothing);
    expect(find.textContaining('is here!'), findsOneWidget);
  });
}

class _FakeHomeRepository extends HomeRepository {
  _FakeHomeRepository() : super(ApiClient(idTokenProvider: () async => null));

  @override
  Future<List<BabySummary>> listBabies() async {
    return [
      BabySummary(
        id: 'baby-1',
        name: 'Parker',
        lifecycleStatus: 'expecting',
        expectedBirthDate:
            DateTime.now().add(const Duration(days: 33)).toIso8601String(),
        role: 'owner',
      ),
      BabySummary(
        id: 'baby-2',
        name: 'Parker',
        lifecycleStatus: 'born',
        actualBirthDate: DateTime.now().toIso8601String(),
        role: 'owner',
      ),
    ];
  }

  @override
  Future<HomeSummaryResult> fetchHomeSummary(String babyId) async {
    if (babyId == 'baby-2') {
      return HomeSummaryLoaded(const HomeSummary(
        lifecycleStatus: 'born',
        nameSuggestionCount: 0,
        voteCount: 0,
        recentActivity: [
          HomeActivityItem(
            id: 'a1',
            eventType: 'photo_shared',
            summary: 'A new photo was shared',
            createdAt: '2026-10-01T12:00:00Z',
          ),
        ],
        birthWelcome: BirthWelcomeSummary(
          babyName: 'Parker',
          daysSinceBirth: 0,
        ),
      ));
    }
    return HomeSummaryLoaded(
      HomeSummary(
        lifecycleStatus: 'expecting',
        nameSuggestionCount: 0,
        voteCount: 0,
        recentActivity: const [],
        daysToDue: 33,
      ),
    );
  }
}
