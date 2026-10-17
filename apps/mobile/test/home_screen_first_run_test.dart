import 'package:flutter/material.dart';
import 'package:lanonna/core/domain/baby_lifecycle.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/domain/activity_event_type.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/network/connectivity_service.dart';
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

import 'support/fake_notifications_repository.dart';
import 'package:lanonna/l10n/app_localizations.dart';

void main() {
  testWidgets('owner expecting home shows countdown and family insight', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'selected_baby_id': 'baby-1'});

    final repo = _FakeHomeRepository();
    final store = SelectedBabyStore(await SharedPreferences.getInstance());

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<HomeRepository>.value(value: repo),
          ChangeNotifierProvider<SelectedBabyStore>.value(value: store),
          Provider<HomeRefreshSignal>(create: (_) => HomeRefreshSignal()),
          ChangeNotifierProvider<ConnectivityService>(
            create: (_) => ConnectivityService.forTesting(),
          ),
          ...shellTopBarTestProviders(),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,

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

  testWidgets('owner born home shows recent activity not invite', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'selected_baby_id': 'baby-2'});

    final repo = _FakeHomeRepository();
    final store = SelectedBabyStore(await SharedPreferences.getInstance());

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<HomeRepository>.value(value: repo),
          ChangeNotifierProvider<SelectedBabyStore>.value(value: store),
          Provider<HomeRefreshSignal>(create: (_) => HomeRefreshSignal()),
          ChangeNotifierProvider<ConnectivityService>(
            create: (_) => ConnectivityService.forTesting(),
          ),
          ...shellTopBarTestProviders(),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,

          theme: AppTheme.light,
          home: const HomeScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('RECENT ACTIVITY'), findsOneWidget);
    expect(find.text('Invite'), findsNothing);
    expect(find.text('🎉'), findsOneWidget);
    expect(find.textContaining('is here!'), findsOneWidget);
  });

  testWidgets('owner born home shows empty recent activity placeholder', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'selected_baby_id': 'baby-born-empty',
    });

    final repo = _FakeHomeRepository();
    final store = SelectedBabyStore(await SharedPreferences.getInstance());

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<HomeRepository>.value(value: repo),
          ChangeNotifierProvider<SelectedBabyStore>.value(value: store),
          Provider<HomeRefreshSignal>(create: (_) => HomeRefreshSignal()),
          ChangeNotifierProvider<ConnectivityService>(
            create: (_) => ConnectivityService.forTesting(),
          ),
          ...shellTopBarTestProviders(),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,

          theme: AppTheme.light,
          home: const HomeScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('RECENT ACTIVITY'), findsOneWidget);
    expect(
      find.textContaining('Nothing yet. Once family starts commenting'),
      findsOneWidget,
    );
    expect(find.text('View all'), findsNothing);
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
        lifecycle: BabyLifecycle.expecting,
        expectedBirthDate: DateTime.now()
            .add(const Duration(days: 33))
            .toIso8601String(),
        role: 'owner',
      ),
      BabySummary(
        id: 'baby-2',
        name: 'Parker',
        lifecycle: BabyLifecycle.born,
        actualBirthDate: DateTime.now().toIso8601String(),
        role: 'owner',
      ),
      BabySummary(
        id: 'baby-born-empty',
        name: 'Liam',
        lifecycle: BabyLifecycle.born,
        actualBirthDate: DateTime.now().toIso8601String(),
        role: 'owner',
      ),
    ];
  }

  @override
  Future<HomeSummaryResult> fetchHomeSummary(String babyId) async {
    if (babyId == 'baby-2') {
      return HomeSummaryLoaded(
        const HomeSummary(
          lifecycle: BabyLifecycle.born,
          nameSuggestionCount: 0,
          voteCount: 0,
          recentActivity: [
            HomeActivityItem(
              id: 'a1',
              eventType: ActivityEventType.photoShared,
              summary: 'A new photo was shared',
              createdAt: '2026-10-01T12:00:00Z',
            ),
          ],
          birthWelcome: BirthWelcomeSummary(
            babyName: 'Parker',
            daysSinceBirth: 0,
          ),
        ),
      );
    }
    if (babyId == 'baby-born-empty') {
      return HomeSummaryLoaded(
        const HomeSummary(
          lifecycle: BabyLifecycle.born,
          nameSuggestionCount: 0,
          voteCount: 0,
          recentActivity: [],
          birthWelcome: BirthWelcomeSummary(
            babyName: 'Liam',
            daysSinceBirth: 1,
          ),
        ),
      );
    }
    return HomeSummaryLoaded(
      HomeSummary(
        lifecycle: BabyLifecycle.expecting,
        nameSuggestionCount: 0,
        voteCount: 0,
        recentActivity: const [],
        daysToDue: 33,
      ),
    );
  }
}
