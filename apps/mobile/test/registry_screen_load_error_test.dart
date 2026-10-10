import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/domain/baby_summary.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Registry shows error with retry when baby load fails', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = SelectedBabyStore(prefs);
    final connectivity = ConnectivityService.forTesting(isOnline: false);
    final registryRepo = RegistryRepository(ApiClient(idTokenProvider: () async => 't'));

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<HomeRepository>.value(value: _FailingHomeRepository()),
          ChangeNotifierProvider<SelectedBabyStore>.value(value: store),
          ChangeNotifierProvider<HomeRefreshSignal>(create: (_) => HomeRefreshSignal()),
          ChangeNotifierProvider<ConnectivityService>.value(value: connectivity),
          Provider<RegistryRepository>.value(value: registryRepo),
          Provider<AuthRepository>.value(value: _FakeAuthRepository()),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const RegistryScreen()),
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
