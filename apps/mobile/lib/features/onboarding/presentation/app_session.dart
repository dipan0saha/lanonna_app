import 'package:flutter/foundation.dart';

import '../../../core/network/connectivity_service.dart';
import '../data/models/onboarding_status.dart';
import '../data/onboarding_repository.dart';
import '../data/onboarding_storage.dart';
import '../domain/onboarding_path.dart';
import '../../legal/domain/legal_routes.dart';
import '../domain/onboarding_routes.dart';
import '../domain/onboarding_step.dart';
import 'onboarding_coordinator.dart';

/// Whether the latest onboarding status is usable for routing.
enum OnboardingStatusPhase {
  /// No fetch has finished and nothing is cached.
  unknown,

  /// [_status] is a server payload, possibly the last cached one.
  loaded,

  /// The status fetch failed and there is no cached server payload.
  unavailable,
}

class AppSession extends ChangeNotifier {
  AppSession({
    required OnboardingRepository repository,
    required OnboardingStorage storage,
    required OnboardingCoordinator coordinator,
    String? Function()? currentUserId,
  }) : _repository = repository,
       _storage = storage,
       _coordinator = coordinator,
       _currentUserId = currentUserId;

  final OnboardingRepository _repository;
  final OnboardingStorage _storage;
  final OnboardingCoordinator _coordinator;
  final String? Function()? _currentUserId;

  OnboardingStatus? _status;

  /// Firebase uid [_status] was loaded for. A status is never used for
  /// another signed-in account (account switch without sign-out, #400).
  String? _statusUid;
  var _phase = OnboardingStatusPhase.unknown;
  var _statusStale = false;
  bool _loading = false;
  ConnectivityService? _connectivity;
  var _wasOffline = false;

  OnboardingStatus? get status => _ownsStatus ? _status : null;

  bool get _ownsStatus => _statusUid == _currentUserId?.call();
  OnboardingStatusPhase get statusPhase => _phase;

  /// Cached server status used because the latest fetch failed.
  bool get statusStale => _statusStale;
  bool get isLoading => _loading;

  bool get ownerOnboardingComplete =>
      _storage.isCompleted || (status?.ownerOnboardingCompleted ?? false);

  /// Server contract only. Device-local onboarding completion must not
  /// admit a co-owner or follower, or skip owner onboarding the server
  /// still requires.
  bool get canAccessMainApp => status?.canAccessMainApp == true;

  /// Test-only hook to set onboarding status without calling the API.
  @visibleForTesting
  void debugSetStatus(OnboardingStatus? status) {
    _status = status;
    _statusUid = _currentUserId?.call();
    _statusStale = false;
    _phase = status == null
        ? OnboardingStatusPhase.unknown
        : OnboardingStatusPhase.loaded;
  }

  /// Re-fetches status when connectivity returns while the last result is
  /// missing or stale. Does not grant access from a device-local flag.
  void bindConnectivity(ConnectivityService connectivity) {
    if (_connectivity == connectivity) return;
    _connectivity?.removeListener(_onConnectivity);
    _connectivity = connectivity;
    _wasOffline = !connectivity.isOnline;
    connectivity.addListener(_onConnectivity);
  }

  void _onConnectivity() {
    final online = _connectivity?.isOnline ?? true;
    if (online && _wasOffline) {
      _wasOffline = false;
      if (_phase == OnboardingStatusPhase.unavailable || _statusStale) {
        refreshFromApi();
      }
    } else if (!online) {
      _wasOffline = true;
    }
  }

  /// Loads the signed-in user's cached server status if nothing usable is in
  /// memory (another account's status is dropped first). Synchronous, so the
  /// first redirect and the startup prefetch decide from it before any fetch.
  void restoreCachedStatus() {
    if (_status != null && _ownsStatus) return;
    if (_status != null) {
      // Loaded for the previous account: forget it before routing this one.
      _status = null;
      _statusUid = null;
      _phase = OnboardingStatusPhase.unknown;
      _statusStale = false;
    }
    final uid = _currentUserId?.call();
    if (uid == null || uid.isEmpty) return;
    final cached = _storage.readCachedOnboardingStatus(uid);
    if (cached == null) return;
    _status = cached;
    _statusUid = uid;
    _phase = OnboardingStatusPhase.loaded;
    _statusStale = true;
  }

  Future<void> _applyLoadedStatus(
    OnboardingStatus status, {
    required bool fresh,
  }) async {
    if (fresh) {
      await _coordinator.syncCompletedFromServer(
        status.ownerOnboardingCompleted,
      );
      await _coordinator.abandonStaleInvitePathIfNeeded(
        hasOwnerBaby: status.hasOwnerBaby,
        hasBabyMembership: status.hasBabyMembership,
      );
    }
    final ownerBabyId = status.ownerOnboardingBabyProfileId;
    if (ownerBabyId != null && ownerBabyId.isNotEmpty) {
      await _coordinator.setCreatedBabyId(ownerBabyId);
    }
  }

  /// Canonical signed-in destination from server status and local coordinator
  /// state (#409). Used by [redirectFor] (carousel, sign-in entry routes,
  /// leaving the resolving screen, and any main-app route the user may not
  /// use) and by invite exit navigation.
  ///
  /// | state | destination |
  /// |---|---|
  /// | email not verified | email verify |
  /// | no status yet (fetch in flight or failed, nothing cached) | session screen (spinner / offline retry), never a guessed step |
  /// | profile incomplete | complete profile |
  /// | may use the main app | /home |
  /// | invite handoff to resume | invite step |
  /// | no owned baby and no membership | create baby (with the invite note) |
  /// | otherwise | owner onboarding resume step |
  String signedInResumeLocation({required bool emailVerified}) {
    final resolved = status;
    if (!_coordinator.skipEmailVerify && !emailVerified) {
      return OnboardingRoutes.emailVerify;
    }
    if (resolved == null) return OnboardingRoutes.sessionOffline;
    if (!resolved.profileComplete) return OnboardingRoutes.completeProfile;
    if (resolved.canAccessMainApp) return '/home';
    if (_coordinator.shouldResumeInviteFlow(
      hasBabyMembership: resolved.hasBabyMembership,
    )) {
      return _inviteResumePath();
    }
    if (!resolved.hasOwnerBaby && !resolved.hasBabyMembership) {
      return OnboardingRoutes.ownerCreateBaby;
    }
    return _onboardingResumePath(resolved);
  }

  Future<void> refreshFromApi() async {
    _loading = true;
    restoreCachedStatus();
    notifyListeners();
    final uid = _currentUserId?.call();
    try {
      final fresh = await _repository.fetchStatus();
      // The account changed while this was in flight: the payload is not
      // the current user's.
      if (_currentUserId?.call() != uid) return;
      _status = fresh;
      _statusUid = uid;
      _phase = OnboardingStatusPhase.loaded;
      _statusStale = false;
      if (uid != null && uid.isNotEmpty) {
        await _storage.saveCachedOnboardingStatus(uid, fresh);
      }
      await _applyLoadedStatus(fresh, fresh: true);
    } catch (_) {
      if (_currentUserId?.call() != uid) return;
      restoreCachedStatus();
      if (_status == null) {
        _phase = OnboardingStatusPhase.unavailable;
        _statusStale = false;
      } else {
        _phase = OnboardingStatusPhase.loaded;
        _statusStale = true;
        await _applyLoadedStatus(_status!, fresh: false);
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _connectivity?.removeListener(_onConnectivity);
    super.dispose();
  }

  static const _invitePublic = {
    OnboardingRoutes.inviteAccept,
    OnboardingRoutes.followerInvite,
    OnboardingRoutes.coOwnerInvite,
    OnboardingRoutes.wrongEmail,
  };

  static const _inviteSignedIn = {
    OnboardingRoutes.inviteAccept,
    OnboardingRoutes.followerInvite,
    OnboardingRoutes.coOwnerInvite,
    OnboardingRoutes.signup,
    OnboardingRoutes.login,
    OnboardingRoutes.emailVerify,
    OnboardingRoutes.completeProfile,
    OnboardingRoutes.confirmRelationship,
    OnboardingRoutes.followerCarousel,
    OnboardingRoutes.coOwnerWelcome,
    OnboardingRoutes.wrongEmail,
  };

  static const _ownerPostBabyAllowed = {
    OnboardingRoutes.emailVerify,
    OnboardingRoutes.completeProfile,
    OnboardingRoutes.ownerCreateBaby,
    OnboardingRoutes.ownerFirstMoment,
    OnboardingRoutes.ownerInvite,
    ..._invitePublic,
  };

  String? redirectFor({
    required bool isSignedIn,
    required bool emailVerified,
    required String location,
  }) {
    if (isSignedIn) {
      restoreCachedStatus();
    }

    final path = location.split('?').first;

    if (path == OnboardingRoutes.roleSelection) {
      return OnboardingRoutes.ownerCarousel;
    }
    if (path == '/login') {
      return OnboardingRoutes.login;
    }

    if (LegalRoutes.paths.contains(path)) {
      return null;
    }

    if (!isSignedIn) {
      final pendingInvite = _signedOutPendingInviteRedirect(path);
      if (pendingInvite != null) return pendingInvite;
      const public = {
        OnboardingRoutes.ownerCarousel,
        OnboardingRoutes.signup,
        OnboardingRoutes.login,
        ..._invitePublic,
      };
      if (public.contains(path)) return null;
      return OnboardingRoutes.ownerCarousel;
    }

    if (!_coordinator.isHydrated) {
      return null;
    }

    final status = this.status;
    final canonical = signedInResumeLocation(emailVerified: emailVerified);
    // Already there: no redirect (a redirect to the same location loops).
    final resume = canonical == path ? null : canonical;

    // A failed or still-running status fetch is not an incomplete profile:
    // the session screen waits (spinner, or offline retry) and is left only
    // for the canonical destination once a server status is known.
    if (path == OnboardingRoutes.sessionOffline) {
      if (status == null) return null;
      return resume;
    }
    if (_phase == OnboardingStatusPhase.unavailable) {
      return OnboardingRoutes.sessionOffline;
    }

    // The welcome carousel is the signed-out entry (and the default cold-start
    // location). No signed-in session may remain on it (#400, #409).
    if (path == OnboardingRoutes.ownerCarousel) {
      return resume;
    }

    // An invite landing with nothing to land on (no token, no preview) is a
    // stale path, e.g. a follower who left or was removed (#408).
    if ((path == OnboardingRoutes.followerInvite ||
            path == OnboardingRoutes.coOwnerInvite) &&
        !_coordinator.hasInviteHandoff) {
      return resume;
    }

    if (canAccessMainApp) {
      // Both flags can be true: a follower who also created a baby
      // (joined_via = created) may use Home and still finish owner onboarding.
      final keepOwnerOnboarding = status?.needsOwnerOnboarding == true;
      if (!keepOwnerOnboarding &&
          OnboardingRoutes.isOnboardingPath(path) &&
          path != OnboardingRoutes.inviteAccept &&
          !_inviteSignedIn.contains(path)) {
        return '/home';
      }
      return null;
    }

    // Signed in with a complete profile: sign-up and login are signed-out
    // entry screens too (#409). Main-app sessions were handled above and keep
    // them, so an existing member can sign in to accept another invite.
    if (status != null &&
        status.profileComplete &&
        (path == OnboardingRoutes.signup || path == OnboardingRoutes.login)) {
      return resume;
    }

    if (_coordinator.shouldResumeInviteFlow(
      hasBabyMembership: status?.hasBabyMembership ?? false,
    )) {
      if (!_coordinator.skipEmailVerify && !emailVerified) {
        if (_inviteSignedIn.contains(path)) return null;
        return OnboardingRoutes.emailVerify;
      }
      if (status != null && !status.profileComplete) {
        if (_inviteSignedIn.contains(path)) return null;
        return OnboardingRoutes.completeProfile;
      }
      if (_inviteSignedIn.contains(path)) return null;
      return _inviteResumePath();
    }

    if (!_coordinator.skipEmailVerify && !emailVerified) {
      const allowed = {
        OnboardingRoutes.emailVerify,
        OnboardingRoutes.signup,
        OnboardingRoutes.login,
        ..._invitePublic,
      };
      if (allowed.contains(path)) return null;
      return OnboardingRoutes.emailVerify;
    }

    if (status != null) {
      if (!status.profileComplete) {
        const allowed = {
          OnboardingRoutes.signup,
          OnboardingRoutes.login,
          OnboardingRoutes.emailVerify,
          OnboardingRoutes.completeProfile,
          ..._invitePublic,
        };
        if (allowed.contains(path)) return null;
        return OnboardingRoutes.completeProfile;
      }
      if (!status.hasOwnerBaby && !status.hasBabyMembership) {
        const allowed = {
          OnboardingRoutes.emailVerify,
          OnboardingRoutes.completeProfile,
          OnboardingRoutes.ownerCreateBaby,
          OnboardingRoutes.ownerFirstMoment,
          OnboardingRoutes.ownerInvite,
          ..._invitePublic,
        };
        if (allowed.contains(path)) return null;
        return OnboardingRoutes.ownerCreateBaby;
      }
      if (!_coordinator.isInvitePath && status.needsOwnerOnboarding) {
        if (_ownerPostBabyAllowed.contains(path)) return null;
        return _onboardingResumePath(status);
      }
    }

    if (path == OnboardingRoutes.signup || path == OnboardingRoutes.login) {
      return null;
    }

    if (OnboardingRoutes.isOnboardingPath(path)) {
      return null;
    }

    // A main-app route (e.g. the signed-in cold start at /home) the user may
    // not use yet. With no status this is the session screen, so Home never
    // builds or loads before the server says it may.
    return resume;
  }

  /// Signed-out resume for a stored invite token. Runs before the public
  /// allowlist because a cold start without a link lands on
  /// [OnboardingRoutes.ownerCarousel] (#388). Login, sign-up and the invite
  /// landing routes are left alone so the user can always sign in or create
  /// an account; a stale token is cleared from the landing's problem state
  /// (`leaveInvitationFlow`), which is the way out to the carousel.
  String? _signedOutPendingInviteRedirect(String path) {
    if (_coordinator.pendingInviteToken == null) return null;
    if (path == OnboardingRoutes.login ||
        path == OnboardingRoutes.signup ||
        _invitePublic.contains(path)) {
      return null;
    }
    final resume = _inviteResumePath();
    // Steps past sign-up (verify email, complete profile) need a session;
    // signed out, the invite landing is the resume point.
    if (resume == OnboardingRoutes.login ||
        resume == OnboardingRoutes.signup ||
        _invitePublic.contains(resume)) {
      return resume;
    }
    return _inviteLandingPath();
  }

  String _inviteLandingPath() =>
      _coordinator.onboardingPath == OnboardingPath.coOwner
          ? OnboardingRoutes.coOwnerInvite
          : OnboardingRoutes.followerInvite;

  String _inviteResumePath() {
    final step = _coordinator.activeStep;
    if (step != null) {
      return OnboardingRoutes.pathForStep(step);
    }
    return _inviteLandingPath();
  }

  String _resumePathForOwnerOnboardingStep() {
    final step = _coordinator.activeStep;
    if (step == OnboardingStep.createBaby) {
      return OnboardingRoutes.ownerCreateBaby;
    }
    if (step == OnboardingStep.batchInvite) {
      return OnboardingRoutes.ownerInvite;
    }
    return OnboardingRoutes.ownerFirstMoment;
  }

  /// First-moment and batch-invite routes assume baby id is rehydrated via
  /// [refreshFromApi] (status field) and [OwnerOnboardingBabyResolver].
  String _onboardingResumePath(OnboardingStatus? status) {
    if (status == null) return OnboardingRoutes.completeProfile;
    if (!status.profileComplete) return OnboardingRoutes.completeProfile;
    if (!status.hasOwnerBaby) {
      if (_coordinator.createdBabyId != null) {
        return _resumePathForOwnerOnboardingStep();
      }
      return OnboardingRoutes.ownerCreateBaby;
    }
    if (status.needsOwnerOnboarding) {
      return _resumePathForOwnerOnboardingStep();
    }
    return OnboardingRoutes.ownerInvite;
  }
}
