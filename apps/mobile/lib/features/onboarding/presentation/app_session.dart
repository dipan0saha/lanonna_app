import 'package:flutter/foundation.dart';

import '../../../core/data/single_flight.dart';
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
  var _phase = OnboardingStatusPhase.unknown;
  var _statusStale = false;
  bool _loading = false;
  ConnectivityService? _connectivity;
  var _wasOffline = false;
  final _refresh = SingleFlight<void>();

  OnboardingStatus? get status => _status;
  OnboardingStatusPhase get statusPhase => _phase;

  /// Cached server status used because the latest fetch failed.
  bool get statusStale => _statusStale;
  bool get isLoading => _loading;

  bool get ownerOnboardingComplete =>
      _storage.isCompleted || (_status?.ownerOnboardingCompleted ?? false);

  /// Server contract only. Device-local onboarding completion must not
  /// admit a co-owner or follower, or skip owner onboarding the server
  /// still requires.
  bool get canAccessMainApp => _status?.canAccessMainApp == true;

  /// Test-only hook to set onboarding status without calling the API.
  @visibleForTesting
  void debugSetStatus(OnboardingStatus? status) {
    _status = status;
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

  void _restoreCachedStatus() {
    if (_status != null) return;
    final uid = _currentUserId?.call();
    if (uid == null || uid.isEmpty) return;
    final cached = _storage.readCachedOnboardingStatus(uid);
    if (cached == null) return;
    _status = cached;
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
    }
    final ownerBabyId = status.ownerOnboardingBabyProfileId;
    if (ownerBabyId != null && ownerBabyId.isNotEmpty) {
      await _coordinator.setCreatedBabyId(ownerBabyId);
    }
  }

  Future<void> refreshFromApi() {
    return _refresh.run(_refreshFromApiOnce);
  }

  Future<void> _refreshFromApiOnce() async {
    _loading = true;
    if (_status == null) _restoreCachedStatus();
    notifyListeners();
    try {
      final fresh = await _repository.fetchStatus();
      _status = fresh;
      _phase = OnboardingStatusPhase.loaded;
      _statusStale = false;
      final uid = _currentUserId?.call();
      if (uid != null && uid.isNotEmpty) {
        await _storage.saveCachedOnboardingStatus(uid, fresh);
      }
      await _applyLoadedStatus(fresh, fresh: true);
    } catch (_) {
      if (_status == null) _restoreCachedStatus();
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
    OnboardingRoutes.ownerCarousel,
    OnboardingRoutes.signup,
    OnboardingRoutes.login,
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
      _restoreCachedStatus();
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
      const public = {
        OnboardingRoutes.ownerCarousel,
        OnboardingRoutes.signup,
        OnboardingRoutes.login,
        ..._invitePublic,
      };
      if (public.contains(path)) return null;
      if (_coordinator.pendingInviteToken != null) {
        return _coordinator.onboardingPath == OnboardingPath.coOwner
            ? OnboardingRoutes.coOwnerInvite
            : OnboardingRoutes.followerInvite;
      }
      return OnboardingRoutes.ownerCarousel;
    }

    // A failed status fetch is not an incomplete profile. Never resume
    // owner onboarding until a loaded server status says to.
    if (path == OnboardingRoutes.sessionOffline) {
      if (_phase == OnboardingStatusPhase.unavailable) return null;
      if (canAccessMainApp && _status?.needsOwnerOnboarding != true) {
        return '/home';
      }
      if (_status != null) return _onboardingResumePath(_status);
      return null;
    }
    if (_phase == OnboardingStatusPhase.unavailable) {
      return OnboardingRoutes.sessionOffline;
    }

    if (canAccessMainApp) {
      // Both flags can be true: a follower who also created a baby
      // (joined_via = created) may use Home and still finish owner onboarding.
      final keepOwnerOnboarding = _status?.needsOwnerOnboarding == true;
      if (!keepOwnerOnboarding &&
          OnboardingRoutes.isOnboardingPath(path) &&
          path != OnboardingRoutes.inviteAccept &&
          !_inviteSignedIn.contains(path)) {
        return '/home';
      }
      return null;
    }

    if (!_coordinator.isHydrated) {
      return null;
    }

    if (_coordinator.isInvitePath) {
      if (!_coordinator.skipEmailVerify && !emailVerified) {
        if (_inviteSignedIn.contains(path)) return null;
        return OnboardingRoutes.emailVerify;
      }
      final status = _status;
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
        OnboardingRoutes.ownerCarousel,
        ..._invitePublic,
      };
      if (allowed.contains(path)) return null;
      return OnboardingRoutes.emailVerify;
    }

    final status = _status;
    if (status != null) {
      if (!status.profileComplete) {
        const allowed = {
          OnboardingRoutes.ownerCarousel,
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
          OnboardingRoutes.ownerCarousel,
          OnboardingRoutes.signup,
          OnboardingRoutes.login,
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
        if (path == OnboardingRoutes.ownerCarousel) {
          return _onboardingResumePath(status);
        }
        if (_ownerPostBabyAllowed.contains(path)) return null;
        if (path == OnboardingRoutes.ownerCreateBaby) {
          return _onboardingResumePath(status);
        }
        if (OnboardingRoutes.isOnboardingPath(path)) {
          return _onboardingResumePath(status);
        }
        return _onboardingResumePath(status);
      }
    }

    if (path == OnboardingRoutes.signup || path == OnboardingRoutes.login) {
      return null;
    }
    if (path == OnboardingRoutes.ownerCarousel) {
      return _onboardingResumePath(status);
    }

    if (OnboardingRoutes.isOnboardingPath(path)) {
      return null;
    }

    return _onboardingResumePath(status);
  }

  String _inviteResumePath() {
    final step = _coordinator.activeStep;
    if (step != null) {
      return OnboardingRoutes.pathForStep(step);
    }
    return _coordinator.onboardingPath == OnboardingPath.coOwner
        ? OnboardingRoutes.coOwnerInvite
        : OnboardingRoutes.followerInvite;
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
