import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/domain/baby_lifecycle.dart';
import 'package:lanonna/core/domain/baby_summary.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/features/home/data/home_repository.dart';
import 'package:go_router/go_router.dart';
import 'package:lanonna/features/home/data/selected_baby_store.dart';
import 'package:lanonna/features/home/domain/app_routes.dart';
import 'package:lanonna/features/shell/presentation/shell_top_bar.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoOwnerHomeRepository extends HomeRepository {
  _NoOwnerHomeRepository() : super(ApiClient(idTokenProvider: () async => null));

  @override
  Future<BabySummary?> resolveOwnerBaby(SelectedBabyStore store) async =>
      null;
}

class _OwnerHomeRepository extends HomeRepository {
  _OwnerHomeRepository() : super(ApiClient(idTokenProvider: () async => null));

  @override
  Future<BabySummary?> resolveOwnerBaby(SelectedBabyStore store) async {
    return const BabySummary(
      id: 'baby-1',
      name: 'Parker',
      role: 'owner',
      lifecycle: BabyLifecycle.expecting,
    );
  }
}

void main() {
  testWidgets('invite without owner baby shows add-baby dialog', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = SelectedBabyStore(await SharedPreferences.getInstance());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MultiProvider(
          providers: [
            Provider<HomeRepository>.value(value: _NoOwnerHomeRepository()),
            ChangeNotifierProvider<SelectedBabyStore>.value(value: store),
          ],
          child: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => onShellInviteFamilyTap(context),
                child: const Text('Invite'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Invite'));
    await tester.pumpAndSettle();

    expect(find.text('Add a baby profile first'), findsOneWidget);
    expect(
      find.textContaining('Invites are sent from a baby profile you own'),
      findsOneWidget,
    );
  });

  testWidgets('invite with owner baby navigates to batch invite', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = SelectedBabyStore(await SharedPreferences.getInstance());
    final homeRepo = _OwnerHomeRepository();

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => MultiProvider(
            providers: [
              Provider<HomeRepository>.value(value: homeRepo),
              ChangeNotifierProvider<SelectedBabyStore>.value(value: store),
            ],
            child: Builder(
              builder: (inner) => Scaffold(
                body: TextButton(
                  onPressed: () => onShellInviteFamilyTap(inner),
                  child: const Text('Invite'),
                ),
              ),
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.inviteFamily,
          builder: (context, state) =>
              const Scaffold(body: Text('Batch invite')),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );

    await tester.tap(find.text('Invite'));
    await tester.pumpAndSettle();

    expect(find.text('Add a baby profile first'), findsNothing);
    expect(find.text('Batch invite'), findsOneWidget);
  });
}
