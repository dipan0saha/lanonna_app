import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/domain/baby_gender.dart';
import 'package:lanonna/core/domain/baby_lifecycle.dart';
import 'package:lanonna/core/domain/baby_summary.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/features/fun/data/fun_repository.dart';
import 'package:lanonna/features/fun/data/models/fun_models.dart';
import 'package:lanonna/features/fun/presentation/names_tab.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class _SuggestFunRepository extends FunRepository {
  _SuggestFunRepository() : super(ApiClient(idTokenProvider: () async => null));

  @override
  Future<NamesPayload> fetchNames(String babyId) async =>
      const NamesPayload(suggestions: []);

  @override
  Future<void> suggestName(
    String babyId,
    String name,
    BabyGender gender,
  ) async {}
}

void main() {
  testWidgets('NamesTab clears validation after successful suggest', (
    tester,
  ) async {
    const baby = BabySummary(
      id: 'baby-1',
      name: 'Parker',
      lifecycle: BabyLifecycle.expecting,
      role: 'owner',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Provider<FunRepository>.value(
            value: _SuggestFunRepository(),
            child: const NamesTab(baby: baby),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'Ada');
    await tester.tap(find.text('Add'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Name is required'), findsNothing);
  });
}
