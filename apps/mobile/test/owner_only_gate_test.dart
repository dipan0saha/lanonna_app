import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/domain/baby_lifecycle.dart';
import 'package:lanonna/core/domain/baby_summary.dart';
import 'package:lanonna/core/router/owner_only_gate.dart';
import 'package:lanonna/features/home/data/home_repository.dart';
import 'package:lanonna/features/home/data/selected_baby_store.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _HomeRepository extends HomeRepository {
  _HomeRepository(this.role)
    : super(ApiClient(idTokenProvider: () async => 't'));

  final String? role;

  BabySummary? get _baby => role == null
      ? null
      : BabySummary(
          id: 'b1',
          name: 'Luna',
          lifecycle: BabyLifecycle.born,
          role: role!,
        );

  @override
  Future<BabySummary?> babyById(String babyId) async => _baby;

  @override
  Future<BabySummary?> resolveSelectedBaby(SelectedBabyStore store) async =>
      _baby;
}

Future<void> _pump(
  WidgetTester tester, {
  required String? role,
  required bool routeBaby,
  bool deepLink = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final router = GoRouter(
    initialLocation: deepLink ? '/owner-page' : '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => Scaffold(
          body: TextButton(
            onPressed: () => context.push('/owner-page'),
            child: const Text('Open'),
          ),
        ),
      ),
      GoRoute(
        path: '/fallback',
        builder: (_, _) => const Scaffold(body: Text('Fallback')),
      ),
      GoRoute(
        path: '/owner-page',
        builder: (_, _) => OwnerOnlyGate(
          babyId: routeBaby ? 'b1' : null,
          fallbackLocation: '/fallback',
          child: const Scaffold(body: Text('Owner form')),
        ),
      ),
    ],
  );
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<HomeRepository>.value(value: _HomeRepository(role)),
        ChangeNotifierProvider(create: (_) => SelectedBabyStore(prefs)),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (!deepLink) {
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }
}

void main() {
  for (final routeBaby in [true, false]) {
    final scope = routeBaby ? 'route baby' : 'selected baby';

    testWidgets('owner sees the owner-only page ($scope)', (tester) async {
      await _pump(tester, role: 'owner', routeBaby: routeBaby);
      expect(find.text('Owner form'), findsOneWidget);
    });

    testWidgets('follower is turned back with feedback ($scope)', (
      tester,
    ) async {
      await _pump(tester, role: 'follower', routeBaby: routeBaby);
      expect(find.text('Owner form'), findsNothing);
      expect(find.text('Open'), findsOneWidget);
      expect(find.text('Only owners can do that.'), findsOneWidget);
    });
  }

  testWidgets('follower deep link with nothing to pop goes to the fallback', (
    tester,
  ) async {
    await _pump(tester, role: 'follower', routeBaby: true, deepLink: true);
    expect(find.text('Owner form'), findsNothing);
    expect(find.text('Fallback'), findsOneWidget);
  });

  testWidgets('unresolved baby leaves the check to the screen', (
    tester,
  ) async {
    await _pump(tester, role: null, routeBaby: false);
    expect(find.text('Owner form'), findsOneWidget);
  });
}
