import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/api/api_exception.dart';
import 'package:lanonna/core/domain/baby_gender.dart';
import 'package:lanonna/core/domain/baby_lifecycle.dart';
import 'package:lanonna/core/domain/baby_summary.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/features/fun/data/fun_repository.dart';
import 'package:lanonna/features/fun/data/models/fun_models.dart';
import 'package:lanonna/features/fun/presentation/names_tab.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

NameSuggestion _name(
  String id,
  BabyGender gender, {
  int likes = 0,
  bool liked = false,
}) => NameSuggestion(
  id: id,
  suggestedName: id,
  gender: gender,
  likeCount: likes,
  viewerHasLiked: liked,
  isMine: false,
  canDelete: false,
  authorDisplayName: 'Sarah',
);

class _Fun extends FunRepository {
  _Fun(this.payload) : super(ApiClient(idTokenProvider: () async => null));

  NamesPayload payload;
  var fetches = 0;
  Completer<bool>? like;

  @override
  Future<NamesPayload> fetchNames(String babyId) async {
    fetches++;
    return payload;
  }

  @override
  Future<bool> toggleLike(String babyId, String suggestionId) =>
      like!.future;
}

void main() {
  group('NamesPayload.withLikeToggled', () {
    test('likes, unlikes and moves the like within one gender', () {
      final payload = NamesPayload(
        suggestions: [
          _name('Leo', BabyGender.male, likes: 2, liked: true),
          _name('Max', BabyGender.male, likes: 1),
          _name('Ava', BabyGender.female, likes: 1, liked: true),
        ],
        viewerLikedMaleId: 'Leo',
        viewerLikedFemaleId: 'Ava',
      );
      final moved = payload.withLikeToggled('Max');
      expect(moved.suggestions.map((s) => s.likeCount), [1, 2, 1]);
      expect(moved.suggestions.map((s) => s.viewerHasLiked), [false, true, true]);
      expect(moved.viewerLikedMaleId, 'Max');
      expect(moved.viewerLikedFemaleId, 'Ava');

      final unliked = moved.withLikeToggled('Max');
      expect(unliked.suggestions[1].likeCount, 1);
      expect(unliked.suggestions[1].viewerHasLiked, isFalse);
      expect(unliked.viewerLikedMaleId, isNull);
    });
  });

  group('PredictionsPayload.withGenderVote', () {
    PredictionsPayload votes({BabyGender? mine}) => PredictionsPayload(
      maleVotes: 3,
      femaleVotes: 2,
      viewerGenderVote: mine,
      birthdateHistogram: const [],
      genderVoters: const [],
    );

    test('a first vote adds one', () {
      final v = votes().withGenderVote(BabyGender.female);
      expect((v.maleVotes, v.femaleVotes, v.viewerGenderVote),
          (3, 3, BabyGender.female));
    });

    test('a changed vote moves from the old side', () {
      final v = votes(mine: BabyGender.male).withGenderVote(BabyGender.female);
      expect((v.maleVotes, v.femaleVotes), (2, 3));
    });

    test('the same vote is unchanged', () {
      final before = votes(mine: BabyGender.male);
      expect(before.withGenderVote(BabyGender.male), same(before));
    });
  });

  group('names like', () {
    const baby = BabySummary(
      id: 'baby-1',
      name: 'Parker',
      lifecycle: BabyLifecycle.expecting,
      role: 'follower',
    );

    Future<_Fun> pumpNames(WidgetTester tester) async {
      final fun = _Fun(
        NamesPayload(suggestions: [_name('Leo', BabyGender.male, likes: 1)]),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Provider<FunRepository>.value(
              value: fun,
              child: const NamesTab(baby: baby),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return fun;
    }

    testWidgets('shows the like at once, without a spinner', (tester) async {
      final fun = await pumpNames(tester);
      fun.like = Completer<bool>();
      await tester.tap(find.byIcon(Icons.favorite_border));
      await tester.pump();

      expect(find.byIcon(Icons.favorite), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      fun.payload = NamesPayload(
        suggestions: [_name('Leo', BabyGender.male, likes: 2, liked: true)],
        viewerLikedMaleId: 'Leo',
      );
      fun.like!.complete(true);
      await tester.pumpAndSettle();
      expect(fun.fetches, 2, reason: 'confirmed by a quiet reload');
      expect(find.text('2'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('reverts the like and explains when it fails', (tester) async {
      final fun = await pumpNames(tester);
      fun.like = Completer<bool>();
      await tester.tap(find.byIcon(Icons.favorite_border));
      await tester.pump();
      expect(find.text('2'), findsOneWidget);

      fun.like!.completeError(ApiException('boom', statusCode: 500));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(fun.fetches, 1);
    });
  });
}
