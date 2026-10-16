import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/network/connectivity_service.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/features/account/data/notifications_repository.dart';
import 'package:lanonna/features/account/data/notifications_unread_signal.dart';
import 'package:lanonna/features/home/data/home_refresh_signal.dart';
import 'package:lanonna/features/home/data/home_repository.dart';
import 'package:lanonna/features/home/data/selected_baby_store.dart';
import 'package:lanonna/features/shell/presentation/shell_top_bar.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_notifications_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('offline shell title uses the last resolved baby name', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = SelectedBabyStore(prefs);
    await store.rememberResolvedBaby('baby-1', 'Parker');

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<HomeRepository>.value(
            value: HomeRepository(
              ApiClient(
                idTokenProvider: () async => 'token',
                isOffline: () => true,
              ),
            ),
          ),
          ChangeNotifierProvider<SelectedBabyStore>.value(value: store),
          Provider<HomeRefreshSignal>(
            create: (_) => HomeRefreshSignal(),
          ),
          ChangeNotifierProvider<ConnectivityService>.value(
            value: ConnectivityService.forTesting(isOnline: false),
          ),
          Provider<NotificationsRepository>(
            create: (_) => FakeNotificationsRepository(),
          ),
          ChangeNotifierProvider<NotificationsUnreadSignal>(
            create: (_) => NotificationsUnreadSignal(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: _TitleHarness()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Parker'), findsOneWidget);
    expect(find.text('La Nonna'), findsNothing);
  });
}

class _TitleHarness extends StatelessWidget {
  const _TitleHarness();

  @override
  Widget build(BuildContext context) => shellHomeTopBar(context);
}
