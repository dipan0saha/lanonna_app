import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/domain/baby_lifecycle.dart';
import 'package:lanonna/core/domain/baby_summary.dart';
import 'package:lanonna/features/registry/data/models/registry_models.dart';
import 'package:lanonna/core/network/connectivity_service.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/features/home/data/home_refresh_signal.dart';
import 'package:lanonna/features/home/data/home_repository.dart';
import 'package:lanonna/features/home/data/selected_baby_store.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lanonna/core/auth/auth_repository.dart';
import 'package:lanonna/features/registry/data/registry_repository.dart';
import 'package:lanonna/features/registry/presentation/registry_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'support/fake_notifications_repository.dart';

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository() : super(firebaseAuth: _FakeFirebaseAuth());

  @override
  User? get currentUser => null;
}

class _FakeFirebaseAuth extends Fake implements FirebaseAuth {}

class _FailingHomeRepository extends HomeRepository {
  _FailingHomeRepository() : super(ApiClient(idTokenProvider: () async => 't'));

  @override
  Future<BabySummary?> resolveSelectedBaby(SelectedBabyStore store) async {
    throw const SocketException('failed host lookup');
  }
}

/// Online for Luna; offline (throws) once the selection moves on.
class _OfflineAfterLunaHomeRepository extends HomeRepository {
  _OfflineAfterLunaHomeRepository()
    : super(ApiClient(idTokenProvider: () async => 't'));

  @override
  Future<BabySummary?> resolveSelectedBaby(SelectedBabyStore store) async {
    if (store.selectedBabyId != 'luna') {
      throw const SocketException('failed host lookup');
    }
    return const BabySummary(
      id: 'luna',
      name: 'Luna',
      lifecycle: BabyLifecycle.expecting,
      role: 'owner',
    );
  }
}

class _LunaRegistryRepository extends RegistryRepository {
  _LunaRegistryRepository() : super(ApiClient(idTokenProvider: () async => 't'));

  @override
  Future<List<RegistryItem>> listItems(String babyId) async => [
    RegistryItem(
      id: 'i1',
      name: 'Luna bottle',
      priority: 1,
      isPurchased: false,
    ),
  ];

  @override
  Future<RegistryShippingAddress> getShippingAddress(String babyId) async =>
      const RegistryShippingAddress();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'offline switch to another baby blocks instead of showing the old baby',
    (tester) async {
      SharedPreferences.setMockInitialValues({'selected_baby_id': 'luna'});
      final store = SelectedBabyStore(await SharedPreferences.getInstance());
      final refresh = HomeRefreshSignal();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ...shellTopBarTestProviders(),
            Provider<HomeRepository>.value(
              value: _OfflineAfterLunaHomeRepository(),
            ),
            ChangeNotifierProvider<SelectedBabyStore>.value(value: store),
            Provider<HomeRefreshSignal>.value(value: refresh),
            ChangeNotifierProvider<ConnectivityService>.value(
              value: ConnectivityService.forTesting(isOnline: true),
            ),
            ChangeNotifierProvider<RegistryRepository>.value(
              value: _LunaRegistryRepository(),
            ),
            Provider<AuthRepository>.value(value: _FakeAuthRepository()),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.light,
            home: const RegistryScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Luna bottle'), findsOneWidget);

      await store.setSelectedBabyId('milo');
      refresh.notifyBabyContextChanged();
      await tester.pump();
      expect(find.text('Luna bottle'), findsNothing);
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Luna bottle'), findsNothing);
      expect(find.text('Try again'), findsOneWidget);
    },
  );

  testWidgets('Registry shows error with retry when baby load fails', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = SelectedBabyStore(prefs);
    final connectivity = ConnectivityService.forTesting(isOnline: false);
    final registryRepo = RegistryRepository(
      ApiClient(idTokenProvider: () async => 't'),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ...shellTopBarTestProviders(),
          Provider<HomeRepository>.value(value: _FailingHomeRepository()),
          ChangeNotifierProvider<SelectedBabyStore>.value(value: store),
          Provider<HomeRefreshSignal>(create: (_) => HomeRefreshSignal()),
          ChangeNotifierProvider<ConnectivityService>.value(
            value: connectivity,
          ),
          ChangeNotifierProvider<RegistryRepository>.value(value: registryRepo),
          Provider<AuthRepository>.value(value: _FakeAuthRepository()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.light,
          home: const RegistryScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('offline'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('No baby profile yet.'), findsNothing);
  });
}
