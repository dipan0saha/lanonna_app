import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/domain/baby_summary.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/features/fun/data/fun_repository.dart';
import 'package:lanonna/features/fun/data/models/fun_models.dart';
import 'package:lanonna/features/fun/presentation/names_tab.dart';
import 'package:provider/provider.dart';

class _FakeFunRepository extends FunRepository {
  _FakeFunRepository(this.payload) : super(ApiClient(idTokenProvider: () async => null));

  final NamesPayload payload;

  @override
  Future<NamesPayload> fetchNames(String babyId) async => payload;
}

void main() {
  const baby = BabySummary(
    id: 'baby-1',
    name: 'Parker',
    lifecycleStatus: 'expecting',
    role: 'follower',
  );

  final payload = NamesPayload(
    suggestions: [
      NameSuggestion(
        id: 'mine',
        suggestedName: 'Mine',
        gender: 'male',
        likeCount: 0,
        viewerHasLiked: false,
        isMine: true,
        canDelete: true,
        authorDisplayName: 'Alex',
      ),
      NameSuggestion(
        id: 'theirs',
        suggestedName: 'Theirs',
        gender: 'male',
        likeCount: 1,
        viewerHasLiked: false,
        isMine: false,
        canDelete: false,
        authorDisplayName: 'Sarah',
      ),
    ],
  );

  testWidgets('follower sees remove only on own suggestion', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Provider<FunRepository>.value(
            value: _FakeFunRepository(payload),
            child: const NamesTab(baby: baby),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mine'), findsOneWidget);
    expect(find.text('Theirs'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
  });
}
