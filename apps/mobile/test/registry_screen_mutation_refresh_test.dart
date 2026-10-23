import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/auth/auth_repository.dart';
import 'package:lanonna/core/domain/baby_lifecycle.dart';
import 'package:lanonna/core/domain/baby_summary.dart';
import 'package:lanonna/core/network/connectivity_service.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/features/home/data/home_refresh_signal.dart';
import 'package:lanonna/features/home/data/home_repository.dart';
import 'package:lanonna/features/home/data/selected_baby_store.dart';
import 'package:lanonna/features/registry/data/models/registry_models.dart';
import 'package:lanonna/features/registry/data/registry_repository.dart';
import 'package:lanonna/features/registry/domain/registry_routes.dart';
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

/// Real mutation methods over a stubbed HTTP client, so the test exercises
/// the repository's own change notifications.
class _CountingRegistryRepository extends RegistryRepository {
  _CountingRegistryRepository()
    : super(
        ApiClient(
          idTokenProvider: () async => 't',
          httpClient: MockClient(
            (request) async => http.Response(
              jsonEncode({'id': 'item-1', 'name': 'Bottle', 'priority': 2}),
              200,
              headers: {'content-type': 'application/json'},
            ),
          ),
        ),
      );

  int listItemsCalls = 0;
  final items = <RegistryItem>[
    RegistryItem(
      id: 'item-1',
      name: 'Bottle',
      priority: 2,
      isPurchased: false,
    ),
  ];

  @override
  Future<List<RegistryItem>> listItems(String babyId) async {
    listItemsCalls++;
    return List<RegistryItem>.from(items);
  }

  @override
  Future<RegistryShippingAddress> getShippingAddress(String babyId) async {
    return const RegistryShippingAddress();
  }
}

void main() {
  testWidgets('Registry reloads after a mutation made on another screen', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final registry = _CountingRegistryRepository();
    // Stand-ins for the item form: save through the repository, then pop
    // with no result.
    Widget savingForm(Future<void> Function(RegistryRepository) save) {
      return Builder(
        builder: (context) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            await save(context.read<RegistryRepository>());
            if (context.mounted) context.pop();
          });
          return const Scaffold(body: SizedBox());
        },
      );
    }

    final router = GoRouter(
      routes: [
        GoRoute(
          path: RegistryRoutes.registry,
          builder: (context, state) => const RegistryScreen(),
        ),
        GoRoute(
          path: RegistryRoutes.createItem,
          builder: (context, state) => savingForm(
            (repo) => repo.createItem('baby-1', name: 'Bib', priority: 3),
          ),
        ),
        GoRoute(
          path: '/registry/item/:itemId/edit',
          builder: (context, state) => savingForm(
            (repo) => repo.updateItem('baby-1', 'item-1', name: 'Bottle 2'),
          ),
        ),
      ],
      initialLocation: RegistryRoutes.registry,
    );

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
          ChangeNotifierProvider<RegistryRepository>.value(value: registry),
          Provider<AuthRepository>.value(value: _FakeAuthRepository()),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (find.text('Bottle').evaluate().isNotEmpty) break;
    }
    expect(registry.listItemsCalls, 1);

    await tester.tap(find.byTooltip('Add item'));
    await tester.pumpAndSettle();
    expect(registry.listItemsCalls, 2);

    await tester.tap(find.bySemanticsIdentifier('registry_item_edit_item-1'));
    await tester.pumpAndSettle();
    expect(registry.listItemsCalls, 3);

    // A change from outside the tab (e.g. Home's Add registry item, or AI
    // suggestions) reloads it too.
    await registry.deleteItem('baby-1', 'item-1');
    await tester.pumpAndSettle();
    expect(registry.listItemsCalls, 4);
  });
}
