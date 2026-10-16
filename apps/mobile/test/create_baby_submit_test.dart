import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/domain/baby_summary.dart';
import 'package:lanonna/features/baby/domain/baby_profile_write_payload.dart';
import 'package:lanonna/features/baby/domain/create_baby_submit.dart';
import 'package:lanonna/features/home/data/home_repository.dart';
import 'package:lanonna/features/onboarding/data/onboarding_repository.dart';
import 'package:lanonna/features/onboarding/data/onboarding_storage.dart';
import 'package:lanonna/features/onboarding/domain/baby_gender.dart';
import 'package:lanonna/features/onboarding/domain/baby_lifecycle.dart';
import 'package:lanonna/features/onboarding/presentation/onboarding_coordinator.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _baby = BabySummary(
  id: 'baby-revise-1',
  name: 'Baby',
  lifecycleStatus: 'expecting',
  role: 'owner',
  gender: 'boy',
  expectedBirthDate: '2026-08-01',
);

class _TrackingOnboardingRepository extends OnboardingRepository {
  _TrackingOnboardingRepository() : super(ApiClient(idTokenProvider: () async => null));

  var createCalls = 0;

  @override
  Future<BabySummary> createBaby({
    required String name,
    String? gender,
    String? expectedBirthDate,
    String? actualBirthDate,
    String lifecycleStatus = 'expecting',
    String? relationshipLabel,
    List<Map<String, String>> profileNameSuggestions = const [],
  }) async {
    createCalls += 1;
    return _baby;
  }
}

class _TrackingHomeRepository extends HomeRepository {
  _TrackingHomeRepository() : super(ApiClient(idTokenProvider: () async => null));

  var updateCalls = 0;

  @override
  Future<BabySummary> updateBaby(
    String babyId, {
    String? name,
    String? gender,
    String? lifecycleStatus,
    String? expectedBirthDate,
    String? actualBirthDate,
    String? avatarUrl,
    List<Map<String, String>>? profileNameSuggestions,
  }) async {
    updateCalls += 1;
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
      boyName: 'Baby',
      girlName: '',
    );

    late BuildContext capturedContext;
    await tester.pumpWidget(
      MaterialApp(
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
  });
}
