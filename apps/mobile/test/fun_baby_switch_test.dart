import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/domain/baby_summary.dart';
import 'package:lanonna/core/network/connectivity_service.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/features/account/data/notifications_repository.dart';
import 'package:lanonna/features/fun/data/fun_repository.dart';
import 'package:lanonna/features/fun/data/models/fun_models.dart';
import 'package:lanonna/features/fun/presentation/fun_screen.dart';
import 'package:lanonna/features/home/data/home_repository.dart';
import 'package:lanonna/features/home/data/home_refresh_signal.dart';
import 'package:lanonna/features/home/data/selected_baby_store.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_notifications_repository.dart';

class _SwitchHomeRepository extends HomeRepository {
  _SwitchHomeRepository(this._babies)
      : super(ApiClient(idTokenProvider: () async => null));

  final List<BabySummary> _babies;

  @override
  Future<List<BabySummary>> listBabies() async => _babies;

  @override
  Future<BabySummary?> resolveSelectedBaby(SelectedBabyStore store) async {
    final id = store.selectedBabyId;
    return _babies.firstWhere((b) => b.id == id, orElse: () => _babies.first);
  }
}

class _FakeFunRepository extends FunRepository {
  _FakeFunRepository() : super(ApiClient(idTokenProvider: () async => null));

  final predictionsByBaby = <String, PredictionsPayload>{};

  @override
  Future<PredictionsPayload> fetchPredictions(String babyId) async {
    return predictionsByBaby[babyId] ??
        const PredictionsPayload(
          maleVotes: 0,
          femaleVotes: 0,
          birthdateHistogram: [],
          genderVoters: [],
        );
  }

  @override
  Future<NamesPayload> fetchNames(String babyId) async {
    return const NamesPayload(suggestions: []);
  }
}

void main() {
  testWidgets('Fun tab reloads predictions when baby context changes', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = SelectedBabyStore(await SharedPreferences.getInstance());
    await store.setSelectedBabyId('baby-a');
    final babies = [
      const BabySummary(
        id: 'baby-a',
        name: 'Baby Parker',
        role: 'owner',
        lifecycleStatus: 'expecting',
      ),
      const BabySummary(
        id: 'baby-b',
        name: 'Lily Born',
        role: 'owner',
        lifecycleStatus: 'born',
      ),
    ];
    final homeRepo = _SwitchHomeRepository(babies);
    final funRepo = _FakeFunRepository();
    funRepo.predictionsByBaby['baby-a'] = const PredictionsPayload(
      maleVotes: 3,
      femaleVotes: 1,
      birthdateHistogram: [],
      genderVoters: [],
    );
    funRepo.predictionsByBaby['baby-b'] = const PredictionsPayload(
      maleVotes: 0,
      femaleVotes: 0,
      birthdateHistogram: [],
      genderVoters: [],
      predictionsClosed: true,
    );
    final homeRefresh = HomeRefreshSignal();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SelectedBabyStore>.value(value: store),
          Provider<HomeRepository>.value(value: homeRepo),
          Provider<FunRepository>.value(value: funRepo),
          Provider<HomeRefreshSignal>.value(value: homeRefresh),
          ChangeNotifierProvider<ConnectivityService>(
            create: (_) => ConnectivityService.forTesting(),
          ),
          Provider<NotificationsRepository>(
            create: (_) => FakeNotificationsRepository(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const FunScreen(),
        ),
      ),
    );

    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (find.text('Predictions').evaluate().isNotEmpty) break;
    }

    await tester.tap(find.text('Predictions'));
    await tester.pumpAndSettle();
    expect(find.text('4'), findsOneWidget);

    await store.setSelectedBabyId('baby-b');
    homeRefresh.notifyBabyContextChanged();
    await tester.pumpAndSettle();

    expect(find.text('Predictions closed — baby has arrived'), findsOneWidget);
    expect(find.text('4'), findsNothing);
  });
}
