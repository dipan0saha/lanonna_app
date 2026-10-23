import 'package:flutter/material.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/domain/baby_lifecycle.dart';
import 'package:lanonna/core/domain/baby_summary.dart';
import 'package:lanonna/core/network/connectivity_service.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/features/calendar/data/calendar_repository.dart';
import 'package:lanonna/features/calendar/presentation/calendar_screen.dart';
import 'package:lanonna/features/home/data/home_repository.dart';
import 'package:lanonna/features/home/data/home_refresh_signal.dart';
import 'package:lanonna/features/home/data/selected_baby_store.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lanonna/l10n/app_localizations.dart';

import 'support/fake_home_repository.dart';
import 'support/fake_notifications_repository.dart';

void main() {
  testWidgets('calendar initial load issues one HTTP request per events key', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final prefs = await SharedPreferences.getInstance();
    final store = SelectedBabyStore(prefs);
    final api = _CountingEventsApi();
    final calRepo = CalendarRepository(api);
    final baby = BabySummary(
      id: 'baby-1',
      name: 'Test Baby',
      role: 'owner',
      lifecycle: BabyLifecycle.expecting,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SelectedBabyStore>.value(value: store),
          ChangeNotifierProvider<CalendarRepository>.value(value: calRepo),
          Provider<HomeRefreshSignal>(create: (_) => HomeRefreshSignal()),
          ChangeNotifierProvider<ConnectivityService>(
            create: (_) => ConnectivityService.forTesting(),
          ),
          Provider<HomeRepository>(create: (_) => FakeHomeRepository(baby)),
          ...shellTopBarTestProviders(),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.light,
          home: const CalendarScreen(),
        ),
      ),
    );
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
    }

    expect(api.paths.where((p) => p.contains('/events')).length, 2);
    expect(api.paths.where((p) => p.contains('upcoming=true')).length, 1);
    expect(
      api.paths.where((p) => p.contains('starts_from=')).length,
      1,
    );
  });
}

class _CountingEventsApi extends ApiClient {
  _CountingEventsApi() : super(idTokenProvider: () async => 'token');

  final paths = <String>[];

  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    bool notifyMembershipEnded = true,
  }) async {
    paths.add(path);
    return {
      'items': <Map<String, dynamic>>[],
      'offset': 0,
      'limit': 50,
      'has_more': false,
    };
  }
}
