import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/domain/baby_summary.dart';
import 'package:lanonna/core/network/connectivity_service.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/features/account/data/notifications_repository.dart';
import 'package:lanonna/features/home/data/home_refresh_signal.dart';
import 'package:lanonna/features/home/data/home_repository.dart';
import 'package:lanonna/features/home/data/home_summary_result.dart';
import 'package:lanonna/features/home/data/models/home_summary.dart';
import 'package:lanonna/features/home/data/selected_baby_store.dart';
import 'package:lanonna/features/home/home_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_notifications_repository.dart';

class _ConnectivityHomeRepository extends HomeRepository {
  _ConnectivityHomeRepository(this.connectivity)
      : super(ApiClient(idTokenProvider: () async => 't'));

  final ConnectivityService connectivity;

  @override
  Future<BabySummary?> resolveSelectedBaby(SelectedBabyStore store) async {
    if (!connectivity.isOnline) {
      throw const SocketException('failed host lookup');
    }
    return const BabySummary(
      id: 'baby-1',
      name: 'Parker',
      lifecycleStatus: 'expecting',
      role: 'owner',
    );
  }

  @override
  Future<HomeSummaryResult> fetchHomeSummary(String babyId) async {
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('offline home shows the load error and refreshes on reconnect', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final connectivity = ConnectivityService.forTesting(isOnline: false);
    final repo = _ConnectivityHomeRepository(connectivity);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<HomeRepository>.value(value: repo),
          ChangeNotifierProvider<SelectedBabyStore>.value(
            value: SelectedBabyStore(prefs),
          ),
          ChangeNotifierProvider<HomeRefreshSignal>(
            create: (_) => HomeRefreshSignal(),
          ),
          ChangeNotifierProvider<ConnectivityService>.value(
            value: connectivity,
          ),
          Provider<NotificationsRepository>(
            create: (_) => FakeNotificationsRepository(),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomeScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.textContaining('offline'), findsWidgets);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Add baby'), findsNothing);
    expect(
      find.text('Add your first baby profile to get started.'),
      findsNothing,
    );

    connectivity.debugSetOnline(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.textContaining('Waiting for'), findsOneWidget);
    expect(find.text('Add baby'), findsNothing);
    expect(find.text('Try again'), findsNothing);
  });
}
