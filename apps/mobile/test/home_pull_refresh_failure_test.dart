import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/domain/baby_lifecycle.dart';
import 'package:lanonna/core/network/connectivity_service.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/features/home/data/home_refresh_signal.dart';
import 'package:lanonna/features/home/data/home_repository.dart';
import 'package:lanonna/features/home/data/selected_baby_store.dart';
import 'package:lanonna/features/home/home_screen.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_notifications_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('pull-to-refresh failure shows snackbar and keeps summary', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'selected_baby_id': 'baby-1'});
    final prefs = await SharedPreferences.getInstance();
    final store = SelectedBabyStore(prefs);
    final api = _HomePullRefreshApi();
    final repo = HomeRepository(api);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<HomeRepository>.value(value: repo),
          ChangeNotifierProvider<SelectedBabyStore>.value(value: store),
          Provider<HomeRefreshSignal>(create: (_) => HomeRefreshSignal()),
          ChangeNotifierProvider<ConnectivityService>(
            create: (_) => ConnectivityService.forTesting(isOnline: true),
          ),
          ...shellTopBarTestProviders(),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home_section_list')), findsOneWidget);

    api.failHomeSummary = true;
    await tester.drag(
      find.byKey(const Key('home_section_list')),
      const Offset(0, 320),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(tester.element(find.byType(HomeScreen)))!;
    expect(find.text(l10n.errorOffline), findsOneWidget);
    expect(find.byKey(const Key('home_section_list')), findsOneWidget);
  });
}

class _HomePullRefreshApi extends ApiClient {
  _HomePullRefreshApi() : super(idTokenProvider: () async => 'token');

  var failHomeSummary = false;

  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    bool notifyMembershipEnded = true,
  }) async {
    if (path.startsWith('/v1/babies') && !path.contains('home-summary')) {
      return {
        'items': [
          {
            'id': 'baby-1',
            'name': 'Luna',
            'role': 'follower',
            'lifecycle_status': 'expecting',
          },
        ],
        'offset': 0,
        'limit': 100,
        'has_more': false,
      };
    }
    if (path.endsWith('/home-summary')) {
      if (failHomeSummary) {
        throw const SocketException('failed host lookup');
      }
      return {
        'lifecycle_status': 'expecting',
        'family_insight': {
          'name_suggestion_count': 0,
          'vote_count': 0,
          'gender_totals': {'male': 0, 'female': 0},
        },
        'teasers': {'recent_photos': [], 'upcoming_events': []},
        'recent_activity': [],
      };
    }
    throw UnimplementedError(path);
  }
}
