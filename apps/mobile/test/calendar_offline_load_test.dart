import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/domain/baby_summary.dart';
import 'package:lanonna/core/network/connectivity_service.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/features/calendar/data/calendar_repository.dart';
import 'package:lanonna/features/calendar/presentation/calendar_screen.dart';
import 'package:lanonna/features/home/data/home_refresh_signal.dart';
import 'package:lanonna/features/home/data/home_repository.dart';
import 'package:lanonna/features/home/data/selected_baby_store.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'support/fake_notifications_repository.dart';

class _OfflineHomeRepository extends HomeRepository {
  _OfflineHomeRepository() : super(ApiClient(idTokenProvider: () async => 't'));

  @override
  Future<BabySummary?> resolveSelectedBaby(SelectedBabyStore store) async {
    throw const SocketException('failed host lookup');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('offline calendar shows a load error, not an empty baby', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ...shellTopBarTestProviders(),
          Provider<HomeRepository>.value(value: _OfflineHomeRepository()),
          ChangeNotifierProvider<SelectedBabyStore>.value(
            value: SelectedBabyStore(prefs),
          ),
          Provider<HomeRefreshSignal>(create: (_) => HomeRefreshSignal()),
          ChangeNotifierProvider<ConnectivityService>.value(
            value: ConnectivityService.forTesting(isOnline: false),
          ),
          ChangeNotifierProvider<CalendarRepository>(
            create: (_) =>
                CalendarRepository(ApiClient(idTokenProvider: () async => 't')),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.light,
          home: const CalendarScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.textContaining('offline'), findsWidgets);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('No baby profile yet.'), findsNothing);
  });

  testWidgets('offline calendar does not wait on a hung request', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final httpClient = _HangingClient();
    final api = ApiClient(
      idTokenProvider: () async => 'token',
      httpClient: httpClient,
      isOffline: () => true,
      timeout: const Duration(seconds: 30),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ...shellTopBarTestProviders(),
          Provider<HomeRepository>.value(value: HomeRepository(api)),
          ChangeNotifierProvider<SelectedBabyStore>.value(
            value: SelectedBabyStore(prefs),
          ),
          Provider<HomeRefreshSignal>(create: (_) => HomeRefreshSignal()),
          ChangeNotifierProvider<ConnectivityService>.value(
            value: ConnectivityService.forTesting(isOnline: false),
          ),
          ChangeNotifierProvider<CalendarRepository>(
            create: (_) => CalendarRepository(api),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.light,
          home: const CalendarScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.textContaining('offline'), findsWidgets);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(httpClient.sends, 0);
  });
}

class _HangingClient extends http.BaseClient {
  int sends = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    sends += 1;
    return Completer<http.StreamedResponse>().future;
  }
}
