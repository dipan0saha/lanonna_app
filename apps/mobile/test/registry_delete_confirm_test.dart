import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/auth/auth_repository.dart';
import 'package:lanonna/core/domain/baby_lifecycle.dart';
import 'package:lanonna/core/domain/baby_summary.dart';
import 'package:lanonna/core/network/connectivity_service.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/features/account/data/account_repository.dart';
import 'package:lanonna/features/home/data/home_refresh_signal.dart';
import 'package:lanonna/features/home/data/home_repository.dart';
import 'package:lanonna/features/home/data/selected_baby_store.dart';
import 'package:lanonna/features/registry/data/models/registry_models.dart';
import 'package:lanonna/features/registry/data/registry_repository.dart';
import 'package:lanonna/features/registry/presentation/registry_screen.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/fake_notifications_repository.dart';

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository() : super(firebaseAuth: _FakeFirebaseAuth());

  @override
  User? get currentUser => null;
}

class _FakeFirebaseAuth extends Fake implements FirebaseAuth {}

class _FakeHomeRepository extends HomeRepository {
  _FakeHomeRepository() : super(ApiClient(idTokenProvider: () async => 't'));

  static const baby = BabySummary(
    id: 'baby-1',
    name: 'Parker',
    lifecycle: BabyLifecycle.born,
    role: 'owner',
  );

  @override
  Future<BabySummary?> resolveSelectedBaby(SelectedBabyStore store) async =>
      baby;
}

class _FakeRegistryRepository extends RegistryRepository {
  _FakeRegistryRepository() : super(ApiClient(idTokenProvider: () async => 't'));

  int deleteCalls = 0;

  @override
  Future<List<RegistryItem>> listItems(String babyId) async {
    return [
      RegistryItem(
        id: 'item-1',
        name: 'Crib',
        priority: 1,
        isPurchased: false,
      ),
    ];
  }

  @override
  Future<RegistryShippingAddress> getShippingAddress(String babyId) async {
    return const RegistryShippingAddress();
  }

  @override
  Future<void> deleteItem(String babyId, String itemId) async {
    deleteCalls++;
  }
}

Future<void> _pumpRegistryScreen(
  WidgetTester tester,
  _FakeRegistryRepository registry,
) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.binding.setSurfaceSize(const Size(800, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ...shellTopBarTestProviders(),
        Provider<HomeRepository>.value(value: _FakeHomeRepository()),
        ChangeNotifierProvider<SelectedBabyStore>.value(
          value: SelectedBabyStore(prefs),
        ),
        Provider<HomeRefreshSignal>(create: (_) => HomeRefreshSignal()),
        ChangeNotifierProvider<ConnectivityService>.value(
          value: ConnectivityService.forTesting(),
        ),
        Provider<RegistryRepository>.value(value: registry),
        Provider<AuthRepository>.value(value: _FakeAuthRepository()),
        Provider<AccountRepository>(
          create: (_) => FakeShellAccountRepository(),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light,
        home: const RegistryScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('cancel on registry delete confirm does not delete', (
    tester,
  ) async {
    final registry = _FakeRegistryRepository();
    await _pumpRegistryScreen(tester, registry);

    await tester.tap(find.byTooltip('Delete item'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this item?'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(registry.deleteCalls, 0);
  });

  testWidgets('confirm on registry delete confirm deletes item', (
    tester,
  ) async {
    final registry = _FakeRegistryRepository();
    await _pumpRegistryScreen(tester, registry);

    await tester.tap(find.byTooltip('Delete item'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(registry.deleteCalls, 1);
  });

  testWidgets('barrier tap on registry delete confirm does not delete', (
    tester,
  ) async {
    final registry = _FakeRegistryRepository();
    await _pumpRegistryScreen(tester, registry);

    await tester.tap(find.byTooltip('Delete item'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this item?'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.text('Delete this item?'), findsNothing);
    expect(registry.deleteCalls, 0);
  });
}
