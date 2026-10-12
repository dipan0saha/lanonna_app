import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/features/onboarding/data/models/onboarding_status.dart';
import 'package:lanonna/features/onboarding/data/onboarding_repository.dart';
import 'package:lanonna/features/onboarding/data/onboarding_storage.dart';
import 'package:lanonna/features/onboarding/domain/owner_onboarding_baby_resolver.dart';
import 'package:lanonna/features/onboarding/presentation/app_session.dart';
import 'package:lanonna/features/onboarding/presentation/onboarding_coordinator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeOnboardingRepository extends OnboardingRepository {
  _FakeOnboardingRepository(this.status) : super(ApiClient(idTokenProvider: () async => null));

  OnboardingStatus status;

  @override
  Future<OnboardingStatus> fetchStatus() async => status;
}

OnboardingStatus _midOnboarding({String? babyId}) {
  return OnboardingStatus(
    emailVerified: true,
    profileComplete: true,
    hasOwnerBaby: true,
    hasBabyMembership: true,
    ownerOnboardingCompleted: false,
    needsOwnerOnboarding: true,
    canAccessMainApp: false,
    ownerOnboardingBabyProfileId: babyId,
  );
}

Future<({
  OnboardingCoordinator coordinator,
  AppSession session,
  _FakeOnboardingRepository repository,
})> _fixtures({OnboardingStatus? initialStatus}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final storage = OnboardingStorage(prefs);
  final repository = _FakeOnboardingRepository(
    initialStatus ?? _midOnboarding(babyId: 'server-baby-id'),
  );
  final coordinator = OnboardingCoordinator(
    storage: storage,
    repository: repository,
  );
  await coordinator.hydrate();
  final session = AppSession(
    repository: repository,
    storage: storage,
    coordinator: coordinator,
  );
  return (coordinator: coordinator, session: session, repository: repository);
}

void main() {
  test('resolve returns local createdBabyId without refresh', () async {
    final f = await _fixtures();
    await f.coordinator.setCreatedBabyId('local-baby-id');
    final id = await OwnerOnboardingBabyResolver.resolve(
      coordinator: f.coordinator,
      readStatus: () => f.session.status,
    );
    expect(id, 'local-baby-id');
  });

  test('resolve uses status baby id and persists to coordinator', () async {
    final f = await _fixtures();
    f.session.debugSetStatus(_midOnboarding(babyId: 'from-status'));
    final id = await OwnerOnboardingBabyResolver.resolve(
      coordinator: f.coordinator,
      readStatus: () => f.session.status,
    );
    expect(id, 'from-status');
    expect(f.coordinator.createdBabyId, 'from-status');
  });

  test('refreshFromApi syncs owner baby id into coordinator', () async {
    final f = await _fixtures();
    await f.session.refreshFromApi();
    expect(f.coordinator.createdBabyId, 'server-baby-id');
    expect(f.session.status?.ownerOnboardingBabyProfileId, 'server-baby-id');
  });

  test('resolve refreshes once when needs owner onboarding and id missing locally', () async {
    final f = await _fixtures(initialStatus: _midOnboarding(babyId: 'after-refresh'));
    f.session.debugSetStatus(_midOnboarding(babyId: null));
    var refreshCount = 0;
    final id = await OwnerOnboardingBabyResolver.resolve(
      coordinator: f.coordinator,
      readStatus: () => f.session.status,
      refreshStatus: () async {
        refreshCount++;
        await f.session.refreshFromApi();
      },
    );
    expect(refreshCount, 1);
    expect(id, 'after-refresh');
  });
}
