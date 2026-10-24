import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/domain/baby_gender.dart';
import 'package:lanonna/core/domain/name_suggestion_draft.dart';
import 'package:lanonna/core/theme/app_theme.dart';
import 'package:lanonna/features/onboarding/data/create_baby_draft.dart';
import 'package:lanonna/features/onboarding/data/onboarding_repository.dart';
import 'package:lanonna/features/onboarding/data/onboarding_storage.dart';
import 'package:lanonna/features/onboarding/presentation/onboarding_coordinator.dart';
import 'package:lanonna/features/onboarding/presentation/screens/onboarding_first_moment_screen.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// First-moment drafts persist on change, not in dispose() (#436).
void main() {
  Future<OnboardingStorage> pumpScreen(
    WidgetTester tester, {
    FirstMomentDraft? saved,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final storage = OnboardingStorage(await SharedPreferences.getInstance());
    await storage.saveBabyLifecycle('expecting');
    if (saved != null) await storage.saveFirstMomentDraft(saved);
    final coordinator = OnboardingCoordinator(
      storage: storage,
      repository: OnboardingRepository(
        ApiClient(idTokenProvider: () async => null),
      ),
    );
    await coordinator.hydrate();

    await tester.pumpWidget(
      ChangeNotifierProvider<OnboardingCoordinator>.value(
        value: coordinator,
        child: MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const OnboardingFirstMomentScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return storage;
  }

  testWidgets('restoring a saved draft does not overwrite it', (tester) async {
    final storage = await pumpScreen(
      tester,
      saved: const FirstMomentDraft(
        nameDrafts: [
          NameSuggestionDraft(name: 'Ava', gender: BabyGender.female),
        ],
        nameInput: 'Mi',
        nameGender: BabyGender.female,
      ),
    );

    expect(find.text('Mi'), findsOneWidget);
    final draft = storage.firstMomentDraft!;
    expect(draft.nameGender, BabyGender.female);
    expect(draft.nameInput, 'Mi');
    expect(draft.nameDrafts.single.name, 'Ava');
  });

  testWidgets('typing a name persists the draft without leaving the screen', (
    tester,
  ) async {
    final storage = await pumpScreen(tester);

    await tester.enterText(find.byType(TextField), 'Noa');
    await tester.pump();

    expect(storage.firstMomentDraft!.nameInput, 'Noa');
  });
}
