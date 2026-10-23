import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/api/api_exception.dart';
import 'package:lanonna/core/network/connectivity_service.dart';
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

Future<
  ({
    AppSession session,
    OnboardingCoordinator coordinator,
    OnboardingStorage storage,
  })
>
_fixtures({
  OnboardingPath path = OnboardingPath.owner,
  bool inviteOnboardingCompleted = false,
  bool localOwnerCompleted = false,
  OnboardingRepository? statusRepository,
  String? userId,
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
  final repository =
      statusRepository ??
      OnboardingRepository(ApiClient(idTokenProvider: () async => null));
  final coordinator = OnboardingCoordinator(
    storage: storage,
    repository: repository,
  );
  await coordinator.hydrate();
  final session = AppSession(
    repository: repository,
    storage: storage,
    coordinator: coordinator,
    currentUserId: () => userId,
  );
  return (session: session, coordinator: coordinator, storage: storage);
}

OnboardingStatus _ownerMidOnboarding({bool ownerOnboardingCompleted = false}) {
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
  test(
    'owner with baby but incomplete onboarding cannot access main app',
    () async {
      final f = await _fixtures();
      f.session.debugSetStatus(_ownerMidOnboarding());
      expect(f.session.canAccessMainApp, isFalse);
    },
  );

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

  test(
    'owner /home redirects to first moment when step is firstMoment',
    () async {
      final f = await _fixtures();
      f.session.debugSetStatus(_ownerMidOnboarding());
      await f.coordinator.setStep(OnboardingStep.firstMoment);
      final redirect = f.session.redirectFor(
        isSignedIn: true,
        emailVerified: true,
        location: '/home',
      );
      expect(redirect, OnboardingRoutes.ownerFirstMoment);
    },
  );

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

  test(
    'completed owner onboarding can access main app and leaves onboarding',
    () async {
      final f = await _fixtures(localOwnerCompleted: true);
      f.session.debugSetStatus(
        _ownerMidOnboarding(ownerOnboardingCompleted: true),
      );
      expect(f.session.canAccessMainApp, isTrue);
      final redirect = f.session.redirectFor(
        isSignedIn: true,
        emailVerified: true,
        location: OnboardingRoutes.ownerFirstMoment,
      );
      expect(redirect, '/home');
    },
  );

  test(
    'follower with baby membership can access main app from server flag',
    () async {
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
    },
  );

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

  test(
    'follower invite path with incomplete profile redirects to complete profile',
    () async {
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
    },
  );

  test(
    'co-owner via invite can access home without creator onboarding',
    () async {
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
    },
  );

  test(
    'local onboarding completion does not override the server gate',
    () async {
      final f = await _fixtures(localOwnerCompleted: true);
      f.session.debugSetStatus(
        const OnboardingStatus(
          emailVerified: true,
          profileComplete: true,
          hasOwnerBaby: true,
          hasBabyMembership: true,
          ownerOnboardingCompleted: false,
          needsOwnerOnboarding: true,
          canAccessMainApp: false,
        ),
      );
      expect(f.session.canAccessMainApp, isFalse);
      expect(
        f.session.redirectFor(
          isSignedIn: true,
          emailVerified: true,
          location: '/home',
        ),
        OnboardingRoutes.ownerFirstMoment,
      );
    },
  );

  test('server can_access_main_app admits a fresh-device co-owner', () async {
    final f = await _fixtures();
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
    expect(
      f.session.redirectFor(
        isSignedIn: true,
        emailVerified: true,
        location: OnboardingRoutes.ownerCreateBaby,
      ),
      '/home',
    );
  });

  test(
    'signed-in user with no baby leaves the carousel for create-baby (#409)',
    () async {
      final f = await _fixtures();
      f.session.debugSetStatus(
        const OnboardingStatus(
          emailVerified: true,
          profileComplete: true,
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
          location: OnboardingRoutes.ownerCarousel,
        ),
        OnboardingRoutes.ownerCreateBaby,
      );
      expect(
        f.session.redirectFor(
          isSignedIn: true,
          emailVerified: true,
          location: OnboardingRoutes.signup,
        ),
        OnboardingRoutes.ownerCreateBaby,
      );
    },
  );

  test(
    'former follower with stale invite path resumes at create-baby (#408)',
    () async {
      final f = await _fixtures(
        path: OnboardingPath.follower,
        inviteOnboardingCompleted: true,
      );
      await f.coordinator.setStep(OnboardingStep.followerInvite);
      f.session.debugSetStatus(
        const OnboardingStatus(
          emailVerified: true,
          profileComplete: true,
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
          location: OnboardingRoutes.followerInvite,
        ),
        OnboardingRoutes.ownerCreateBaby,
      );
    },
  );

  test('signedInResumeLocation covers main session states', () async {
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
      f.session.signedInResumeLocation(emailVerified: true),
      OnboardingRoutes.completeProfile,
    );
    f.session.debugSetStatus(
      const OnboardingStatus(
        emailVerified: true,
        profileComplete: true,
        hasOwnerBaby: false,
        hasBabyMembership: true,
        ownerOnboardingCompleted: true,
        needsOwnerOnboarding: false,
        canAccessMainApp: true,
      ),
    );
    expect(
      f.session.signedInResumeLocation(emailVerified: true),
      '/home',
    );
  });

  test(
    'follower who also created a baby leaves the signed-out carousel on cold start',
    () async {
      final f = await _fixtures();
      f.session.debugSetStatus(
        const OnboardingStatus(
          emailVerified: true,
          profileComplete: true,
          hasOwnerBaby: true,
          hasBabyMembership: true,
          ownerOnboardingCompleted: false,
          needsOwnerOnboarding: true,
          canAccessMainApp: true,
        ),
      );
      expect(
        f.session.redirectFor(
          isSignedIn: true,
          emailVerified: true,
          location: OnboardingRoutes.ownerCarousel,
        ),
        '/home',
      );
    },
  );

  test('a main-app user never stays on the signed-out carousel', () async {
    final f = await _fixtures();
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
    expect(
      f.session.redirectFor(
        isSignedIn: true,
        emailVerified: true,
        location: OnboardingRoutes.ownerCarousel,
      ),
      '/home',
    );
  });

  test("another account's status is never used for routing", () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = OnboardingStorage(prefs);
    final repository = OnboardingRepository(
      ApiClient(idTokenProvider: () async => null),
    );
    final coordinator = OnboardingCoordinator(
      storage: storage,
      repository: repository,
    );
    await coordinator.hydrate();
    var uid = 'uid-a';
    final session = AppSession(
      repository: repository,
      storage: storage,
      coordinator: coordinator,
      currentUserId: () => uid,
    );
    session.debugSetStatus(
      const OnboardingStatus(
        emailVerified: true,
        profileComplete: true,
        hasOwnerBaby: true,
        hasBabyMembership: true,
        ownerOnboardingCompleted: true,
        needsOwnerOnboarding: false,
        canAccessMainApp: true,
      ),
    );
    expect(session.canAccessMainApp, isTrue);

    uid = 'uid-b';

    expect(session.status, isNull);
    expect(session.canAccessMainApp, isFalse);
    expect(
      session.redirectFor(
        isSignedIn: true,
        emailVerified: true,
        location: '/home',
      ),
      isNot('/home'),
    );
    expect(session.statusPhase, OnboardingStatusPhase.unknown);
  });

  test(
    'follower who also created a baby keeps home and owner onboarding',
    () async {
      final f = await _fixtures();
      f.session.debugSetStatus(
        const OnboardingStatus(
          emailVerified: true,
          profileComplete: true,
          hasOwnerBaby: true,
          hasBabyMembership: true,
          ownerOnboardingCompleted: false,
          needsOwnerOnboarding: true,
          canAccessMainApp: true,
        ),
      );
      expect(f.session.canAccessMainApp, isTrue);
      expect(
        f.session.redirectFor(
          isSignedIn: true,
          emailVerified: true,
          location: '/home',
        ),
        isNull,
      );
      expect(
        f.session.redirectFor(
          isSignedIn: true,
          emailVerified: true,
          location: OnboardingRoutes.ownerFirstMoment,
        ),
        isNull,
      );
    },
  );

  test('fromJson keeps explicit onboarding flags', () {
    final status = OnboardingStatus.fromJson({
      'email_verified': true,
      'profile_complete': true,
      'has_owner_baby': true,
      'has_baby_membership': true,
      'owner_onboarding_completed': false,
      'needs_owner_onboarding': false,
      'can_access_main_app': true,
    });
    expect(status.needsOwnerOnboarding, isFalse);
    expect(status.canAccessMainApp, isTrue);

    final both = OnboardingStatus.fromJson({
      'email_verified': true,
      'profile_complete': true,
      'has_owner_baby': true,
      'has_baby_membership': true,
      'owner_onboarding_completed': false,
      'needs_owner_onboarding': true,
      'can_access_main_app': true,
    });
    expect(both.needsOwnerOnboarding, isTrue);
    expect(both.canAccessMainApp, isTrue);
  });

  test('failed status fetch keeps a cached co-owner on home', () async {
    const cached = OnboardingStatus(
      emailVerified: true,
      profileComplete: true,
      hasOwnerBaby: true,
      hasBabyMembership: true,
      ownerOnboardingCompleted: false,
      needsOwnerOnboarding: false,
      canAccessMainApp: true,
    );
    final repo = _ThrowingStatusRepository(cached);
    final f = await _fixtures(statusRepository: repo, userId: 'user-1');
    await f.storage.saveCachedOnboardingStatus('user-1', cached);
    await f.session.refreshFromApi();

    expect(f.session.statusPhase, OnboardingStatusPhase.loaded);
    expect(f.session.statusStale, isTrue);
    expect(f.session.canAccessMainApp, isTrue);
    expect(
      f.session.redirectFor(
        isSignedIn: true,
        emailVerified: true,
        location: '/home',
      ),
      isNull,
    );
    expect(
      f.session.redirectFor(
        isSignedIn: true,
        emailVerified: true,
        location: OnboardingRoutes.ownerCreateBaby,
      ),
      '/home',
    );
    expect(
      f.session.redirectFor(
        isSignedIn: true,
        emailVerified: true,
        location: OnboardingRoutes.ownerCarousel,
      ),
      '/home',
    );
  });

  test('failed status fetch with no cache opens the offline screen', () async {
    final repo = _ThrowingStatusRepository(_ownerMidOnboarding());
    final f = await _fixtures(
      statusRepository: repo,
      userId: 'user-1',
      localOwnerCompleted: true,
    );
    await f.session.refreshFromApi();

    expect(f.session.statusPhase, OnboardingStatusPhase.unavailable);
    expect(f.session.canAccessMainApp, isFalse);
    for (final location in [
      '/home',
      OnboardingRoutes.completeProfile,
      OnboardingRoutes.ownerCreateBaby,
    ]) {
      expect(
        f.session.redirectFor(
          isSignedIn: true,
          emailVerified: true,
          location: location,
        ),
        OnboardingRoutes.sessionOffline,
      );
    }
  });

  test(
    'reconnect refreshes a failed status and leaves the offline screen',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      const ready = OnboardingStatus(
        emailVerified: true,
        profileComplete: true,
        hasOwnerBaby: true,
        hasBabyMembership: true,
        ownerOnboardingCompleted: false,
        needsOwnerOnboarding: false,
        canAccessMainApp: true,
      );
      final repo = _ThrowingStatusRepository(ready);
      final f = await _fixtures(statusRepository: repo, userId: 'user-1');
      final connectivity = ConnectivityService.forTesting(isOnline: false);
      f.session.bindConnectivity(connectivity);
      await f.session.refreshFromApi();
      expect(f.session.statusPhase, OnboardingStatusPhase.unavailable);

      repo.fail = false;
      connectivity.debugSetOnline(true);
      for (var i = 0; i < 50 && !f.session.canAccessMainApp; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      expect(repo.calls, 2);
      expect(f.session.canAccessMainApp, isTrue);
      expect(
        f.session.redirectFor(
          isSignedIn: true,
          emailVerified: true,
          location: OnboardingRoutes.sessionOffline,
        ),
        '/home',
      );
      f.session.dispose();
      connectivity.dispose();
    },
  );

  test('invite preview stays available from the create-baby step', () async {
    final f = await _fixtures();
    f.session.debugSetStatus(
      const OnboardingStatus(
        emailVerified: true,
        profileComplete: true,
        hasOwnerBaby: false,
        hasBabyMembership: false,
        ownerOnboardingCompleted: false,
        needsOwnerOnboarding: false,
        canAccessMainApp: false,
      ),
    );
    await f.coordinator.setStep(OnboardingStep.createBaby);
    expect(
      f.session.redirectFor(
        isSignedIn: true,
        emailVerified: true,
        location: OnboardingRoutes.ownerCreateBaby,
      ),
      isNull,
    );
    expect(
      f.session.redirectFor(
        isSignedIn: true,
        emailVerified: true,
        location: '${OnboardingRoutes.inviteAccept}?token=abc123',
      ),
      isNull,
    );
  });

  test(
    'owner with baby allows create-baby when step is createBaby',
    () async {
      final f = await _fixtures();
      f.session.debugSetStatus(_ownerMidOnboarding());
      await f.coordinator.setStep(OnboardingStep.createBaby);
      final redirect = f.session.redirectFor(
        isSignedIn: true,
        emailVerified: true,
        location: OnboardingRoutes.ownerCreateBaby,
      );
      expect(redirect, isNull);
    },
  );

  test(
    'owner with baby resumes first moment when step is firstMoment',
    () async {
      final f = await _fixtures();
      f.session.debugSetStatus(_ownerMidOnboarding());
      await f.coordinator.setStep(OnboardingStep.firstMoment);
      final redirect = f.session.redirectFor(
        isSignedIn: true,
        emailVerified: true,
        location: OnboardingRoutes.ownerCarousel,
      );
      expect(redirect, OnboardingRoutes.ownerFirstMoment);
    },
  );

  test(
    'signed-out cold start resumes pending invite from owner carousel',
    () async {
      final f = await _fixtures(path: OnboardingPath.follower);
      await f.storage.savePendingInviteToken('invite-token-abc');
      await f.coordinator.hydrate();
      final redirect = f.session.redirectFor(
        isSignedIn: false,
        emailVerified: false,
        location: OnboardingRoutes.ownerCarousel,
      );
      expect(redirect, OnboardingRoutes.followerInvite);
    },
  );

  test(
    'signed-out pending invite keeps explicit login and signup routes',
    () async {
      final f = await _fixtures(path: OnboardingPath.follower);
      await f.storage.savePendingInviteToken('invite-token-abc');
      await f.coordinator.hydrate();
      expect(
        f.session.redirectFor(
          isSignedIn: false,
          emailVerified: false,
          location: OnboardingRoutes.login,
        ),
        isNull,
      );
      expect(
        f.session.redirectFor(
          isSignedIn: false,
          emailVerified: false,
          location: OnboardingRoutes.signup,
        ),
        isNull,
      );
    },
  );

  test(
    'signed-out pending invite resumes signup step after accept',
    () async {
      final f = await _fixtures(path: OnboardingPath.follower);
      await f.storage.savePendingInviteToken('invite-token-abc');
      await f.coordinator.setStep(OnboardingStep.signup);
      final redirect = f.session.redirectFor(
        isSignedIn: false,
        emailVerified: false,
        location: OnboardingRoutes.ownerCarousel,
      );
      expect(redirect, OnboardingRoutes.signup);
    },
  );

  test(
    'signed-out pending invite past sign-up resumes on the invite landing',
    () async {
      final f = await _fixtures(path: OnboardingPath.coOwner);
      await f.storage.savePendingInviteToken('invite-token-abc');
      await f.coordinator.setStep(OnboardingStep.emailVerify);
      final redirect = f.session.redirectFor(
        isSignedIn: false,
        emailVerified: false,
        location: OnboardingRoutes.ownerCarousel,
      );
      expect(redirect, OnboardingRoutes.coOwnerInvite);
    },
  );

  test(
    'signed-out pending invite leaves the invite landing alone (no loop)',
    () async {
      final f = await _fixtures(path: OnboardingPath.follower);
      await f.storage.savePendingInviteToken('invite-token-abc');
      await f.coordinator.hydrate();
      expect(
        f.session.redirectFor(
          isSignedIn: false,
          emailVerified: false,
          location: OnboardingRoutes.followerInvite,
        ),
        isNull,
      );
    },
  );

  test(
    'signed out with the invite cleared, the owner carousel is reachable',
    () async {
      final f = await _fixtures(path: OnboardingPath.follower);
      await f.storage.savePendingInviteToken('invite-token-abc');
      await f.coordinator.hydrate();
      await f.coordinator.clearPendingInvite();
      expect(
        f.session.redirectFor(
          isSignedIn: false,
          emailVerified: false,
          location: OnboardingRoutes.ownerCarousel,
        ),
        isNull,
      );
    },
  );

  test(
    'owner with baby resume path returns create-baby for createBaby step',
    () async {
      final f = await _fixtures();
      f.session.debugSetStatus(_ownerMidOnboarding());
      await f.coordinator.setStep(OnboardingStep.createBaby);
      final redirect = f.session.redirectFor(
        isSignedIn: true,
        emailVerified: true,
        location: OnboardingRoutes.ownerCarousel,
      );
      expect(redirect, OnboardingRoutes.ownerCreateBaby);
    },
  );
}

class _ThrowingStatusRepository extends OnboardingRepository {
  _ThrowingStatusRepository(this.status)
    : super(ApiClient(idTokenProvider: () async => null));

  OnboardingStatus status;
  var fail = true;
  var calls = 0;

  @override
  Future<OnboardingStatus> fetchStatus() async {
    calls += 1;
    if (fail) {
      throw ApiException(
        'network_unavailable',
        detail: const {'error': 'network_unavailable'},
      );
    }
    return status;
  }
}
