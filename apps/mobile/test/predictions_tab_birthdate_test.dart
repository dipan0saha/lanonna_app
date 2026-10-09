import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/domain/baby_summary.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/features/fun/data/fun_repository.dart';
import 'package:lanonna/features/fun/data/models/fun_models.dart';
import 'package:lanonna/features/fun/presentation/predictions_tab.dart';
import 'package:provider/provider.dart';

class _RecordingFunRepository extends FunRepository {
  _RecordingFunRepository(this.payload)
      : super(ApiClient(idTokenProvider: () async => null));

  final PredictionsPayload payload;
  final List<DateTime> birthdateVotes = [];

  @override
  Future<PredictionsPayload> fetchPredictions(String babyId) async => payload;

  @override
  Future<void> setBirthdateVote(String babyId, DateTime date) async {
    birthdateVotes.add(date);
  }
}

void main() {
  const baby = BabySummary(
    id: 'baby-1',
    name: 'Parker',
    lifecycleStatus: 'expecting',
    role: 'follower',
    expectedBirthDate: '2027-02-01',
  );

  final emptyVotes = PredictionsPayload(
    maleVotes: 0,
    femaleVotes: 0,
    birthdateHistogram: const [],
    genderVoters: const [],
  );

  testWidgets('save guess disabled until calendar day selected', (tester) async {
    final repo = _RecordingFunRepository(emptyVotes);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Provider<FunRepository>.value(
            value: repo,
            child: const PredictionsTab(baby: baby),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final saveBtn = find.byKey(const Key('lockPredictionBtn'));
    await tester.scrollUntilVisible(
      saveBtn,
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(saveBtn, findsOneWidget);
    final button = tester.widget<FilledButton>(saveBtn);
    expect(button.onPressed, isNull);

    await tester.scrollUntilVisible(
      find.text('15'),
      80,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('15'));
    await tester.pumpAndSettle();

    final enabled = tester.widget<FilledButton>(saveBtn);
    expect(enabled.onPressed, isNotNull);

    await tester.tap(saveBtn);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repo.birthdateVotes, hasLength(1));
    expect(repo.birthdateVotes.single, DateTime(2027, 2, 15));
  });

  testWidgets('tapping save without selection does not call API', (tester) async {
    final repo = _RecordingFunRepository(emptyVotes);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Provider<FunRepository>.value(
            value: repo,
            child: const PredictionsTab(baby: baby),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(repo.birthdateVotes, isEmpty);
  });
}
