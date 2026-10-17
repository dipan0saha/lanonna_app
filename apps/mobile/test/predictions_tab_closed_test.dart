import 'package:flutter/material.dart';
import 'package:lanonna/core/domain/baby_gender.dart';
import 'package:lanonna/core/domain/baby_lifecycle.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/domain/baby_summary.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/features/fun/data/fun_repository.dart';
import 'package:lanonna/features/fun/data/models/fun_models.dart';
import 'package:lanonna/features/fun/presentation/predictions_tab.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class _RecordingFunRepository extends FunRepository {
  _RecordingFunRepository(this.payload)
    : super(ApiClient(idTokenProvider: () async => null));

  final PredictionsPayload payload;
  final List<BabyGender> genderVotes = [];
  final List<DateTime> birthdateVotes = [];

  @override
  Future<PredictionsPayload> fetchPredictions(String babyId) async => payload;

  @override
  Future<void> setGenderVote(String babyId, BabyGender gender) async {
    genderVotes.add(gender);
  }

  @override
  Future<void> setBirthdateVote(String babyId, DateTime date) async {
    birthdateVotes.add(date);
  }
}

Future<void> _pumpTab(
  WidgetTester tester, {
  required BabySummary baby,
  required _RecordingFunRepository repo,
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Provider<FunRepository>.value(
          value: repo,
          child: PredictionsTab(baby: baby),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  const born = BabySummary(
    id: 'baby-1',
    name: 'Parker',
    lifecycle: BabyLifecycle.born,
    role: 'follower',
    expectedBirthDate: '2026-08-01',
  );

  const expecting = BabySummary(
    id: 'baby-1',
    name: 'Parker',
    lifecycle: BabyLifecycle.expecting,
    role: 'follower',
    expectedBirthDate: '2027-02-01',
  );

  final closedWithVotes = PredictionsPayload(
    maleVotes: 2,
    femaleVotes: 1,
    viewerGenderVote: BabyGender.male,
    viewerBirthdateVote: '2026-08-01',
    birthdateHistogram: [BirthdateVoteCount(date: '2026-08-01', count: 1)],
    genderVoters: [GenderVoterRow(gender: BabyGender.male, displayName: 'Avery')],
    predictionsClosed: true,
  );

  testWidgets('born baby shows final results and hides voting controls', (
    tester,
  ) async {
    final repo = _RecordingFunRepository(closedWithVotes);
    await _pumpTab(tester, baby: born, repo: repo);

    expect(find.text('Predictions closed — baby has arrived'), findsOneWidget);
    expect(find.text('67% (2)'), findsOneWidget);
    expect(find.text('33% (1)'), findsOneWidget);
    expect(find.text('Your vote: Boy'), findsOneWidget);
    expect(find.textContaining('Your guess:'), findsOneWidget);
    expect(find.text('View who voted'), findsOneWidget);
    expect(find.text('Save guess'), findsNothing);
    expect(find.text('Update guess'), findsNothing);
    expect(find.text('Pick date…'), findsNothing);
    expect(find.byKey(const Key('lockPredictionBtn')), findsNothing);

    await tester.tap(find.text('Boy'));
    await tester.pumpAndSettle();
    expect(repo.genderVotes, isEmpty);
    expect(repo.birthdateVotes, isEmpty);
  });

  testWidgets(
    'closed flag hides voting when the local baby is still expecting',
    (tester) async {
      final repo = _RecordingFunRepository(
        PredictionsPayload(
          maleVotes: 0,
          femaleVotes: 0,
          birthdateHistogram: const [],
          genderVoters: const [],
          predictionsClosed: true,
        ),
      );
      await _pumpTab(tester, baby: expecting, repo: repo);

      expect(
        find.text('Predictions closed — baby has arrived'),
        findsOneWidget,
      );
      expect(find.text('No guesses yet'), findsOneWidget);
      expect(find.text('No guesses yet - be the first!'), findsNothing);
      expect(find.text('0% (0)'), findsNWidgets(2));
      expect(find.text('Save guess'), findsNothing);
      expect(find.text('Pick date…'), findsNothing);

      await tester.tap(find.text('Girl'));
      await tester.pumpAndSettle();
      expect(repo.genderVotes, isEmpty);
    },
  );
}
