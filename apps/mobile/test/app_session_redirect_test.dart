import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/features/onboarding/data/models/onboarding_status.dart';
import 'package:lanonna/features/onboarding/data/onboarding_repository.dart';
import 'package:lanonna/features/onboarding/data/onboarding_storage.dart';
import 'package:lanonna/features/onboarding/domain/onboarding_path.dart';
import 'package:lanonna/features/legal/domain/legal_routes.dart';
import 'package:lanonna/features/onboarding/domain/onboarding_routes.dart';
import 'package:lanonna/features/onboarding/domain/onboarding_step.dart';
import 'package:lanonna/features/onboarding/presentation/app_session.dart';
import 'package:lanonna/features/onboarding/presentation/onboarding_coordinator.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<({
  AppSession session,
  OnboardingCoordinator coordinator,
})> _fixtures({
  OnboardingPath path = OnboardingPath.owner,
  bool inviteOnboardingCompleted = false,
  bool localOwnerCompleted = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final storage = OnboardingStorage(prefs);
  if (localOwnerCompleted) {
    await storage.setCompleted(true);
  }
  if (inviteOnboardingCompleted) {
    await storage.setInviteOnboardingCompleted(true);
  }
  if (path != OnboardingPath.owner) {
    await storage.saveOnboardingPath(path);
  }
  final repository = OnboardingRepository(ApiClient(idTokenProvider: () async => null));
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
  return (session: session, coordinator: coordinator);
}

OnboardingStatus _ownerMidOnboarding({
  bool ownerOnboardingCompleted = false,
}) {
  return OnboardingStatus(
    emailVerified: true,
    profileComplete: true,
    hasOwnerBaby: true,
    hasBabyMembership: true,
    ownerOnboardingCompleted: ownerOnboardingCompleted,
    needsOwnerOnboarding: !ownerOnboardingCompleted,
    canAccessMainApp: ownerOnboardingCompleted,
  );
}

void main() {
  test('owner with baby but incomplete onboarding cannot access main app', () async {
    final f = await _fixtures();
    f.session.debugSetStatus(_ownerMidOnboarding());
    expect(f.session.canAccessMainApp, isFalse);
  });

  test('owner first-moment route is allowed mid onboarding', () async {
    final f = await _fixtures();
    f.session.debugSetStatus(_ownerMidOnboarding());
    await f.coordinator.setStep(OnboardingStep.firstMoment);
    final redirect = f.session.redirectFor(
      isSignedIn: true,
      emailVerified: true,
      location: OnboardingRoutes.ownerFirstMoment,
    );
    expect(redirect, isNull);
  });

  test('owner /home redirects to first moment when step is firstMoment', () async {
    final f = await _fixtures();
    f.session.debugSetStatus(_ownerMidOnboarding());
    await f.coordinator.setStep(OnboardingStep.firstMoment);
    final redirect = f.session.redirectFor(
      isSignedIn: true,
      emailVerified: true,
      location: '/home',
    );
    expect(redirect, OnboardingRoutes.ownerFirstMoment);
  });

  test('owner /home redirects to invite when step is batchInvite', () async {
    final f = await _fixtures();
    f.session.debugSetStatus(_ownerMidOnboarding());
    await f.coordinator.setStep(OnboardingStep.batchInvite);
    final redirect = f.session.redirectFor(
      isSignedIn: true,
      emailVerified: true,
      location: '/home',
    );
    expect(redirect, OnboardingRoutes.ownerInvite);
  });

  test('completed owner onboarding can access main app and leaves onboarding', () async {
    final f = await _fixtures(localOwnerCompleted: true);
    f.session.debugSetStatus(_ownerMidOnboarding(ownerOnboardingCompleted: true));
    expect(f.session.canAccessMainApp, isTrue);
    final redirect = f.session.redirectFor(
      isSignedIn: true,
      emailVerified: true,
      location: OnboardingRoutes.ownerFirstMoment,
    );
    expect(redirect, '/home');
  });

  test('follower with baby membership can access main app from server flag', () async {
    final f = await _fixtures(path: OnboardingPath.follower);
    f.session.debugSetStatus(
      const OnboardingStatus(
        emailVerified: true,
        profileComplete: true,
        hasOwnerBaby: false,
        hasBabyMembership: true,
        ownerOnboardingCompleted: false,
        needsOwnerOnboarding: false,
        canAccessMainApp: true,
      ),
    );
    expect(f.session.canAccessMainApp, isTrue);
    final redirect = f.session.redirectFor(
      isSignedIn: true,
      emailVerified: true,
      location: OnboardingRoutes.ownerCreateBaby,
    );
    expect(redirect, '/home');
  });

  test('legal routes allowed while profile incomplete', () async {
    final f = await _fixtures();
    f.session.debugSetStatus(
      const OnboardingStatus(
        emailVerified: true,
        profileComplete: false,
        hasOwnerBaby: false,
        hasBabyMembership: false,
        ownerOnboardingCompleted: false,
        needsOwnerOnboarding: false,
        canAccessMainApp: false,
      ),
    );
    expect(
      f.session.redirectFor(
        isSignedIn: true,
        emailVerified: true,
        location: LegalRoutes.terms,
      ),
      isNull,
    );
    expect(
      f.session.redirectFor(
        isSignedIn: true,
        emailVerified: true,
        location: LegalRoutes.privacy,
      ),
      isNull,
    );
  });

  test('follower invite path with incomplete profile redirects to complete profile', () async {
    final f = await _fixtures(path: OnboardingPath.follower);
    f.session.debugSetStatus(
      const OnboardingStatus(
        emailVerified: true,
        profileComplete: false,
        hasOwnerBaby: false,
        hasBabyMembership: false,
        ownerOnboardingCompleted: false,
        needsOwnerOnboarding: false,
        canAccessMainApp: false,
      ),
    );
    final redirect = f.session.redirectFor(
      isSignedIn: true,
      emailVerified: true,
      location: '/home',
    );
    expect(redirect, OnboardingRoutes.completeProfile);
  });

  test('co-owner via invite can access home without creator onboarding', () async {
    final f = await _fixtures(path: OnboardingPath.coOwner);
    f.session.debugSetStatus(
      const OnboardingStatus(
        emailVerified: true,
        profileComplete: true,
        hasOwnerBaby: true,
        hasBabyMembership: true,
        ownerOnboardingCompleted: false,
        needsOwnerOnboarding: false,
        canAccessMainApp: true,
      ),
    );
    expect(f.session.canAccessMainApp, isTrue);
    final redirect = f.session.redirectFor(
      isSignedIn: true,
      emailVerified: true,
      location: '/home',
    );
    expect(redirect, isNull);
  });

  test('owner with baby redirects create-baby to first moment by default', () async {
    final f = await _fixtures();
    f.session.debugSetStatus(_ownerMidOnboarding());
    final redirect = f.session.redirectFor(
      isSignedIn: true,
      emailVerified: true,
      location: OnboardingRoutes.ownerCreateBaby,
    );
    expect(redirect, OnboardingRoutes.ownerFirstMoment);
  });
}
