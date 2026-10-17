import 'dart:io';
import 'package:lanonna/core/domain/baby_lifecycle.dart';

import 'package:flutter/material.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/domain/baby_summary.dart';
import 'package:lanonna/core/network/connectivity_service.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/features/home/data/home_refresh_signal.dart';
import 'package:lanonna/features/home/data/home_repository.dart';
import 'package:lanonna/features/home/data/selected_baby_store.dart';
import 'package:lanonna/features/search/data/search_repository.dart';
import 'package:lanonna/features/search/presentation/global_search_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _BabyHomeRepository extends HomeRepository {
  _BabyHomeRepository() : super(ApiClient(idTokenProvider: () async => 't'));

  @override
  Future<BabySummary?> resolveSelectedBaby(SelectedBabyStore store) async {
    return const BabySummary(
      id: 'baby-1',
      name: 'Parker',
      lifecycle: BabyLifecycle.born,
      role: 'owner',
    );
  }
}

class _SearchRepository extends SearchRepository {
  _SearchRepository() : super(ApiClient(idTokenProvider: () async => 't'));

  var calls = 0;

  @override
  Future<SearchResults> search({
    required String babyId,
    required String query,
  }) async {
    calls += 1;
    throw const SocketException('failed host lookup');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('search surfaces a failed query instead of the empty hint', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final search = _SearchRepository();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<HomeRepository>.value(value: _BabyHomeRepository()),
          ChangeNotifierProvider<SelectedBabyStore>.value(
            value: SelectedBabyStore(prefs),
          ),
          Provider<HomeRefreshSignal>(create: (_) => HomeRefreshSignal()),
          ChangeNotifierProvider<ConnectivityService>(
            create: (_) => ConnectivityService.forTesting(),
          ),
          Provider<SearchRepository>.value(value: search),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.light,
          home: const GlobalSearchScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    await tester.enterText(find.byType(TextField), 'park');
    await tester.pump(const Duration(milliseconds: 100));
    expect(search.calls, 0);

    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();

    expect(search.calls, 1);
    expect(find.text('Type to search'), findsNothing);
    expect(find.textContaining('offline'), findsWidgets);
    expect(find.text('Try again'), findsOneWidget);
  });
}
