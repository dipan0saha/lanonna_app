import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/domain/baby_summary.dart';
import 'package:lanonna/core/network/connectivity_service.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/features/fun/presentation/fun_screen.dart';
import 'package:lanonna/features/home/data/home_refresh_signal.dart';
import 'package:lanonna/features/home/data/home_repository.dart';
import 'package:lanonna/features/home/data/selected_baby_store.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_home_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('born baby shows fun wrapped empty state', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = SelectedBabyStore(prefs);
    final baby = const BabySummary(
      id: 'b1',
      name: 'Parker',
      lifecycleStatus: 'born',
      role: 'owner',
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<HomeRepository>(create: (_) => FakeHomeRepository(baby)),
          ChangeNotifierProvider<SelectedBabyStore>.value(value: store),
          Provider<HomeRefreshSignal>(create: (_) => HomeRefreshSignal()),
          ChangeNotifierProvider<ConnectivityService>(
            create: (_) => ConnectivityService.forTesting(),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const FunScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Family Fun is wrapped up'), findsOneWidget);
    expect(find.text('Go to Gallery'), findsOneWidget);
    expect(find.text('Names'), findsNothing);
  });
}
