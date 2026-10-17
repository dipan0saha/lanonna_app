import 'package:flutter/material.dart';
import 'package:lanonna/core/domain/baby_lifecycle.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/api/api_exception.dart';
import 'package:lanonna/features/home/data/home_repository.dart';
import 'package:lanonna/features/home/data/selected_baby_store.dart';
import 'package:lanonna/features/registry/data/models/registry_models.dart';
import 'package:lanonna/features/registry/data/registry_repository.dart';
import 'package:lanonna/features/registry/presentation/registry_ai_suggestions_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lanonna/core/domain/baby_summary.dart';

import 'support/fake_home_repository.dart';

void main() {
  testWidgets('registry AI suggestions shows snackbar when list fails', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'selected_baby_id': 'baby-1'});

    final homeRepo = FakeHomeRepository(
      const BabySummary(
        id: 'baby-1',
        name: 'Test',
        lifecycle: BabyLifecycle.expecting,
        role: 'owner',
      ),
    );
    final regRepo = _FailingRegistryRepository();
    final store = SelectedBabyStore(await SharedPreferences.getInstance());

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<HomeRepository>.value(value: homeRepo),
          Provider<RegistryRepository>.value(value: regRepo),
          ChangeNotifierProvider<SelectedBabyStore>.value(value: store),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: RegistryAiSuggestionsScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();

    expect(find.textContaining('Could not load suggestions'), findsOneWidget);
    expect(find.textContaining('network down'), findsOneWidget);
  });
}

class _FailingRegistryRepository extends RegistryRepository {
  _FailingRegistryRepository()
    : super(ApiClient(idTokenProvider: () async => 't'));

  @override
  Future<List<RegistryItem>> listItems(String babyId) async {
    throw ApiException('network down');
  }
}
