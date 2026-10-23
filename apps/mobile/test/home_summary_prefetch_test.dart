import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/api/api_exception.dart';
import 'package:lanonna/core/domain/baby_lifecycle.dart';
import 'package:lanonna/core/domain/baby_summary.dart';
import 'package:lanonna/core/network/connectivity_service.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/features/home/data/home_refresh_signal.dart';
import 'package:lanonna/features/home/data/home_repository.dart';
import 'package:lanonna/features/home/data/home_summary_result.dart';
import 'package:lanonna/features/home/data/models/home_summary.dart';
import 'package:lanonna/features/home/data/selected_baby_store.dart';
import 'package:lanonna/features/home/home_screen.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_notifications_repository.dart';

BabySummary _baby(String id) => BabySummary(
  id: id,
  name: 'Parker',
  lifecycle: BabyLifecycle.expecting,
  expectedBirthDate: DateTime.now()
      .add(const Duration(days: 33))
      .toIso8601String(),
  role: 'owner',
);

const _summary = HomeSummary(
  lifecycle: BabyLifecycle.expecting,
  nameSuggestionCount: 0,
  voteCount: 0,
  recentActivity: [],
  daysToDue: 33,
);

/// Records the order of Home's requests; the baby list answers only when
/// [babies] is completed.
class _RecordingHomeRepository extends HomeRepository {
  _RecordingHomeRepository({this.failSpeculative = false})
    : super(ApiClient(idTokenProvider: () async => null));

  final bool failSpeculative;
  final babies = Completer<List<BabySummary>>();
  final events = <String>[];

  @override
  Future<List<BabySummary>> listBabies() async {
    events.add('babies:start');
    final list = await babies.future;
    events.add('babies:done');
    return list;
  }

  @override
  Future<HomeSummaryResult> fetchHomeSummary(
    String babyId, {
    Duration? maxAge,
    bool speculative = false,
    bool allowStaleOnError = true,
  }) async {
    events.add('summary:$babyId${speculative ? ':speculative' : ''}');
    if (speculative && failSpeculative) {
      return HomeSummaryFailed(ApiException('http_500', statusCode: 500));
    }
    return HomeSummaryLoaded(_summary);
  }
}

Future<void> _pumpHome(
  WidgetTester tester,
  _RecordingHomeRepository repo,
  SelectedBabyStore store,
) async {
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
}

void main() {
  testWidgets(
    'the stored baby\'s summary loads together with the baby list',
    (tester) async {
      SharedPreferences.setMockInitialValues({'selected_baby_id': 'baby-1'});
      final store = SelectedBabyStore(await SharedPreferences.getInstance());
      final repo = _RecordingHomeRepository();

      await _pumpHome(tester, repo, store);
      expect(repo.events, ['summary:baby-1:speculative', 'babies:start']);

      repo.babies.complete([_baby('baby-1')]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // The list confirmed baby-1: its summary is used, not requested again.
      expect(repo.events, [
        'summary:baby-1:speculative',
        'babies:start',
        'babies:done',
      ]);
      expect(find.text('DAYS TO DUE DATE'), findsOneWidget);
    },
  );

  testWidgets('a stored baby the list no longer has is not shown', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'selected_baby_id': 'baby-old'});
    final store = SelectedBabyStore(await SharedPreferences.getInstance());
    final repo = _RecordingHomeRepository();

    await _pumpHome(tester, repo, store);
    repo.babies.complete([_baby('baby-1')]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(repo.events, [
      'summary:baby-old:speculative',
      'babies:start',
      'babies:done',
      'summary:baby-1',
    ]);
    expect(store.selectedBabyId, 'baby-1');
    expect(find.text('DAYS TO DUE DATE'), findsOneWidget);
  });

  testWidgets('a failed early summary is requested again the normal way', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'selected_baby_id': 'baby-1'});
    final store = SelectedBabyStore(await SharedPreferences.getInstance());
    final repo = _RecordingHomeRepository(failSpeculative: true);

    await _pumpHome(tester, repo, store);
    repo.babies.complete([_baby('baby-1')]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(repo.events.last, 'summary:baby-1');
    expect(find.text('DAYS TO DUE DATE'), findsOneWidget);
  });

  testWidgets('with no stored baby, Home waits for the list as before', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = SelectedBabyStore(await SharedPreferences.getInstance());
    final repo = _RecordingHomeRepository();

    await _pumpHome(tester, repo, store);
    expect(repo.events, ['babies:start']);

    repo.babies.complete([_baby('baby-1')]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(repo.events, ['babies:start', 'babies:done', 'summary:baby-1']);
  });

  test('a speculative summary does not run the membership-ended handler',
      () async {
    final api = _FlagRecordingApi();
    final repo = HomeRepository(api);

    await repo.fetchHomeSummary('baby-1', speculative: true);
    await repo.fetchHomeSummary('baby-1');

    expect(api.notifyFlags, [false, true]);
  });
}

class _FlagRecordingApi extends ApiClient {
  _FlagRecordingApi() : super(idTokenProvider: () async => 'token');

  final notifyFlags = <bool>[];

  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    bool notifyMembershipEnded = true,
  }) async {
    notifyFlags.add(notifyMembershipEnded);
    return {
      'lifecycle_status': 'expecting',
      'name_suggestion_count': 0,
      'vote_count': 0,
      'recent_activity': <Object>[],
    };
  }
}
