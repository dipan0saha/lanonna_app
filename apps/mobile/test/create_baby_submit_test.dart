import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/domain/baby_summary.dart';
import 'package:lanonna/features/baby/domain/baby_profile_write_payload.dart';
import 'package:lanonna/features/baby/domain/create_baby_submit.dart';
import 'package:lanonna/features/home/data/home_repository.dart';
import 'package:lanonna/features/onboarding/data/onboarding_repository.dart';
import 'package:lanonna/features/onboarding/data/onboarding_storage.dart';
import 'package:lanonna/core/domain/baby_gender.dart';
import 'package:lanonna/core/domain/baby_lifecycle.dart';
import 'package:lanonna/core/domain/name_suggestion_draft.dart';
import 'package:lanonna/features/onboarding/presentation/onboarding_coordinator.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _baby = BabySummary(
  id: 'baby-revise-1',
  name: 'Liam',
  lifecycle: BabyLifecycle.expecting,
  role: 'owner',
  gender: BabyGender.male,
  expectedBirthDate: '2026-08-01',
);

class _TrackingOnboardingRepository extends OnboardingRepository {
  _TrackingOnboardingRepository() : super(ApiClient(idTokenProvider: () async => null));

  var createCalls = 0;
  String? createdName = 'not called';

  @override
  Future<BabySummary> createBaby({
    String? name,
    BabyGender gender = BabyGender.unknown,
    String? expectedBirthDate,
    String? actualBirthDate,
    BabyLifecycle lifecycle = BabyLifecycle.expecting,
    String? relationshipLabel,
    List<NameSuggestionDraft> profileNameSuggestions = const [],
  }) async {
    createCalls += 1;
    createdName = name;
    return _baby;
  }
}

class _TrackingHomeRepository extends HomeRepository {
  _TrackingHomeRepository() : super(ApiClient(idTokenProvider: () async => null));

  var updateCalls = 0;
  String? nameWrite;

  @override
  Future<BabySummary> updateBaby(
    String babyId, {
    String? name,
    BabyGender? gender,
    BabyLifecycle? lifecycle,
    String? expectedBirthDate,
    String? actualBirthDate,
    String? avatarUrl,
    List<NameSuggestionDraft> profileNameSuggestions = const [],
  }) async {
    updateCalls += 1;
    nameWrite = name;
    expect(babyId, 'baby-revise-1');
    return _baby;
  }
}

void main() {
  testWidgets('owner onboarding revise submit updates baby without POST create', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = OnboardingStorage(prefs);
    final repository = _TrackingOnboardingRepository();
    final homeRepo = _TrackingHomeRepository();
    final coordinator = OnboardingCoordinator(storage: storage, repository: repository);
    await coordinator.hydrate();
    await coordinator.setCreatedBabyId('baby-revise-1');

    final input = CreateBabyFormInput(
      status: BabyLifecycle.expecting,
      gender: BabyGender.male,
      selectedDate: DateTime(2026, 8, 1),
      boyName: 'Liam',
      girlName: '',
    );

    late BuildContext capturedContext;
    await tester.pumpWidget(
      MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
home: Builder(
          builder: (context) {
            capturedContext = context;
            return const SizedBox();
          },
        ),
      ),
    );

    await submitOwnerOnboardingBaby(
      context: capturedContext,
      input: input,
      repository: repository,
      homeRepo: homeRepo,
      api: ApiClient(idTokenProvider: () async => null),
      coordinator: coordinator,
    );

    expect(repository.createCalls, 0);
    expect(homeRepo.updateCalls, 1);
    expect(homeRepo.nameWrite, 'Liam');
  });

  Future<BuildContext> pumpContext(WidgetTester tester) async {
    late BuildContext capturedContext;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            capturedContext = context;
            return const SizedBox();
          },
        ),
      ),
    );
    return capturedContext;
  }

  const unnamedInput = CreateBabyFormInput(
    status: BabyLifecycle.expecting,
    gender: BabyGender.unknown,
    selectedDate: null,
    boyName: '',
    girlName: '',
  );

  testWidgets('create without a name sends no name (never the "Baby" fallback)', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = OnboardingStorage(await SharedPreferences.getInstance());
    final repository = _TrackingOnboardingRepository();
    final coordinator = OnboardingCoordinator(storage: storage, repository: repository);
    await coordinator.hydrate();
    final context = await pumpContext(tester);

    await submitOwnerOnboardingBaby(
      context: context,
      input: unnamedInput,
      repository: repository,
      homeRepo: _TrackingHomeRepository(),
      api: ApiClient(idTokenProvider: () async => null),
      coordinator: coordinator,
    );

    expect(repository.createCalls, 1);
    expect(repository.createdName, isNull);
  });

  testWidgets('revise with the name cleared sends an empty name', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = OnboardingStorage(await SharedPreferences.getInstance());
    final repository = _TrackingOnboardingRepository();
    final homeRepo = _TrackingHomeRepository();
    final coordinator = OnboardingCoordinator(storage: storage, repository: repository);
    await coordinator.hydrate();
    await coordinator.setCreatedBabyId('baby-revise-1');
    final context = await pumpContext(tester);

    await submitOwnerOnboardingBaby(
      context: context,
      input: unnamedInput,
      repository: repository,
      homeRepo: homeRepo,
      api: ApiClient(idTokenProvider: () async => null),
      coordinator: coordinator,
    );

    expect(homeRepo.updateCalls, 1);
    expect(homeRepo.nameWrite, isEmpty);
  });
}
