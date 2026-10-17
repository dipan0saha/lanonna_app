import 'package:flutter/material.dart';
import 'package:lanonna/core/domain/baby_lifecycle.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/domain/baby_summary.dart';
import 'package:lanonna/core/network/connectivity_service.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/features/fun/presentation/fun_screen.dart';
import 'package:lanonna/features/home/data/home_refresh_signal.dart';
import 'package:lanonna/features/home/data/home_repository.dart';
import 'package:lanonna/features/home/data/selected_baby_store.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/features/fun/data/fun_repository.dart';
import 'package:lanonna/features/fun/data/models/fun_models.dart';

import 'support/fake_home_repository.dart';
import 'support/fake_notifications_repository.dart';

class _FakeFunRepository extends FunRepository {
  _FakeFunRepository() : super(ApiClient(idTokenProvider: () async => null));

  @override
  Future<NamesPayload> fetchNames(String babyId) async => NamesPayload(
    suggestions: [
      NameSuggestion(
        id: 'n1',
        suggestedName: 'Luca',
        gender: 'male',
        likeCount: 2,
        viewerHasLiked: false,
        isMine: true,
        canDelete: true,
        authorDisplayName: 'Owner',
      ),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('born baby keeps Fun visible but read-only', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = SelectedBabyStore(prefs);
    final baby = const BabySummary(
      id: 'b1',
      name: 'Parker',
      lifecycle: BabyLifecycle.born,
      role: 'owner',
      namesClosed: true,
      predictionsClosed: true,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ...shellTopBarTestProviders(),
          Provider<HomeRepository>(create: (_) => FakeHomeRepository(baby)),
          Provider<FunRepository>(create: (_) => _FakeFunRepository()),
          ChangeNotifierProvider<SelectedBabyStore>.value(value: store),
          Provider<HomeRefreshSignal>(create: (_) => HomeRefreshSignal()),
          ChangeNotifierProvider<ConnectivityService>(
            create: (_) => ConnectivityService.forTesting(),
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
    await tester.pumpAndSettle();

    expect(find.text('Names'), findsOneWidget);
    expect(find.text('Predictions'), findsOneWidget);
    expect(
      find.text('Name ideas are closed — baby has arrived.'),
      findsOneWidget,
    );
    expect(find.text('Luca'), findsOneWidget);
    // No suggest form, like or delete controls after birth.
    expect(find.byType(TextFormField), findsNothing);
    expect(
      find.bySemanticsLabel(RegExp('Love Luca|Unlike Luca')),
      findsNothing,
    );
    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });
}
