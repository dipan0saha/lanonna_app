import 'dart:async';

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

  final suggested = <String>[];

  /// Completed by the test, so the request spans frames like a real network
  /// call (the form rebuilds with the typed text before the reply).
  Completer<void>? pendingSuggest;

  @override
  Future<NamesPayload> fetchNames(String babyId) async =>
      NamesPayload(suggestions: const []);

  @override
  Future<void> suggestName(
    String babyId,
    String name,
    BabyGender gender,
  ) async {
    suggested.add(name);
    final pending = pendingSuggest;
    if (pending != null) await pending.future;
  }
}

void main() {
  testWidgets('a successful suggest clears the field without a required error, '
      'and the next empty submit still validates', (tester) async {
    const baby = BabySummary(
      id: 'baby-1',
      name: 'Parker',
      lifecycle: BabyLifecycle.expecting,
      role: 'owner',
    );
    final repo = _SuggestFunRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Provider<FunRepository>.value(
            value: repo,
            child: const NamesTab(baby: baby),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'Ada');
    repo.pendingSuggest = Completer<void>();
    await tester.tap(find.text('Add'));
    // Frames while the request is in flight (#402: the form rebuilt with
    // 'Ada' as the field's initialValue, and reset() restored it).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(repo.suggested, ['Ada']);
    repo.pendingSuggest!.complete();
    repo.pendingSuggest = null;
    await tester.pumpAndSettle();

    expect(repo.suggested, ['Ada']);
    final field = tester.widget<TextFormField>(find.byType(TextFormField));
    expect(field.controller!.text, isEmpty);
    expect(find.text('Ada'), findsNothing);
    expect(find.text('Name is required'), findsNothing);

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(find.text('Name is required'), findsOneWidget);
    expect(repo.suggested, ['Ada']);
  });
}
