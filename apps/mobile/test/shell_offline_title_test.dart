import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/network/connectivity_service.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/features/home/data/home_refresh_signal.dart';
import 'package:lanonna/features/home/data/home_repository.dart';
import 'package:lanonna/features/home/data/selected_baby_store.dart';
import 'package:lanonna/features/shell/presentation/shell_top_bar.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_notifications_repository.dart';
import 'package:lanonna/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpOfflineShell(WidgetTester tester, SelectedBabyStore store) async {
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
          Provider<HomeRefreshSignal>(create: (_) => HomeRefreshSignal()),
          ChangeNotifierProvider<ConnectivityService>.value(
            value: ConnectivityService.forTesting(isOnline: false),
          ),
          ...shellTopBarTestProviders(),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.light,
          home: const Scaffold(body: _TitleHarness()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('offline shell title uses the last resolved baby name', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = SelectedBabyStore(await SharedPreferences.getInstance());
    await store.rememberResolvedBaby('baby-1', 'Parker');

    await pumpOfflineShell(tester, store);

    expect(find.text('Parker'), findsOneWidget);
    expect(find.text('La Nonna'), findsNothing);
  });

  testWidgets('offline shell title shows the fallback for an unnamed baby', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = SelectedBabyStore(await SharedPreferences.getInstance());
    await store.rememberResolvedBaby('baby-1', null);

    await pumpOfflineShell(tester, store);

    expect(find.text('Baby'), findsOneWidget);
  });
}

class _TitleHarness extends StatelessWidget {
  const _TitleHarness();

  @override
  Widget build(BuildContext context) => shellHomeTopBar(context);
}
