import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/domain/baby_lifecycle.dart';
import 'package:lanonna/core/domain/baby_summary.dart';
import 'package:lanonna/features/account/data/account_repository.dart';
import 'package:lanonna/features/baby/presentation/delete_baby_profile_flow.dart';
import 'package:lanonna/features/home/data/home_refresh_signal.dart';
import 'package:lanonna/features/home/data/home_repository.dart';
import 'package:lanonna/features/home/data/selected_baby_store.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Accounts extends AccountRepository {
  _Accounts() : super(ApiClient(idTokenProvider: () async => 't'));

  String? deletedId;

  @override
  Future<void> deleteBabyProfile(String babyId) async {
    deletedId = babyId;
  }
}

class _Home extends HomeRepository {
  _Home() : super(ApiClient(idTokenProvider: () async => 't'));

  var resolves = 0;

  @override
  Future<BabySummary?> resolveSelectedBaby(SelectedBabyStore store) async {
    resolves++;
    return null;
  }
}

void main() {
  test('canDeleteProfile is only for a sole owner', () {
    BabySummary b(String role, bool canLeave) => BabySummary(
      id: 'b',
      name: 'B',
      role: role,
      lifecycle: BabyLifecycle.expecting,
      canLeave: canLeave,
    );
    expect(b('owner', false).canDeleteProfile, isTrue);
    expect(b('owner', true).canDeleteProfile, isFalse);
    expect(b('follower', true).canDeleteProfile, isFalse);
  });

  testWidgets('delete flow shows two confirmations then deletes', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = SelectedBabyStore(await SharedPreferences.getInstance());
    final accounts = _Accounts();
    final home = _Home();
    final refresh = HomeRefreshSignal();
    final baby = BabySummary(
      id: 'baby-1',
      name: 'Lorenzo',
      role: 'owner',
      lifecycle: BabyLifecycle.expecting,
      canLeave: false,
    );

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () =>
                    deleteBabyProfileWithConfirmation(context, baby),
                child: const Text('start'),
              ),
            ),
          ),
        ),
        GoRoute(path: '/home', builder: (_, _) => const Text('home')),
      ],
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AccountRepository>.value(value: accounts),
          Provider<HomeRepository>.value(value: home),
          ChangeNotifierProvider<SelectedBabyStore>.value(value: store),
          Provider<HomeRefreshSignal>.value(value: refresh),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('start'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this baby profile?'), findsOneWidget);

    await tester.tap(find.text('Delete profile'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Delete Lorenzo permanently?'), findsOneWidget);

    await tester.tap(find.text('Delete profile').last);
    await tester.pumpAndSettle();

    expect(accounts.deletedId, 'baby-1');
    expect(home.resolves, 1);
    expect(find.text('home'), findsOneWidget);
  });
}
