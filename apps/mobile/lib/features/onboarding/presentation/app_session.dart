import 'package:flutter/foundation.dart';

import '../data/models/onboarding_status.dart';
import '../data/onboarding_repository.dart';
import '../data/onboarding_storage.dart';
import '../domain/onboarding_path.dart';
import '../domain/onboarding_routes.dart';
import '../domain/onboarding_step.dart';
import 'onboarding_coordinator.dart';

class AppSession extends ChangeNotifier {
  AppSession({
    required OnboardingRepository repository,
    required OnboardingStorage storage,
    required OnboardingCoordinator coordinator,
  })  : _repository = repository,
        _storage = storage,
        _coordinator = coordinator;

  final OnboardingRepository _repository;
  final OnboardingStorage _storage;
  final OnboardingCoordinator _coordinator;

  OnboardingStatus? _status;
  bool _loading = false;

  OnboardingStatus? get status => _status;
  bool get isLoading => _loading;

  bool get ownerOnboardingComplete =>
      _storage.isCompleted || (_status?.ownerOnboardingCompleted ?? false);

  bool get hasBabyAccess => _status?.hasBabyMembership ?? false;

  bool get canAccessMainApp {
    if (ownerOnboardingComplete) return true;
    if (_coordinator.inviteOnboardingCompleted) return true;
    if (_coordinator.isInvitePath) return false;
    return hasBabyAccess && (_status?.profileComplete ?? false);
  }

  Future<void> refreshFromApi() async {
    _loading = true;
    notifyListeners();
    try {
      _status = await _repository.fetchStatus();
      await _coordinator.syncCompletedFromServer(_status!.ownerOnboardingCompleted);
    } catch (_) {
      _status = null;
    } finally {
      _loading = false;
      notifyListeners();
    }
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

  String? redirectFor({
    required bool isSignedIn,
    required bool emailVerified,
    required String location,
  }) {
    final path = location.split('?').first;

    if (path == OnboardingRoutes.roleSelection) {
      return OnboardingRoutes.ownerCarousel;
    }
    if (path == '/login') {
      return OnboardingRoutes.login;
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

    if (canAccessMainApp) {
      if (OnboardingRoutes.isOnboardingPath(path) &&
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

  String _onboardingResumePath(OnboardingStatus? status) {
    if (status == null) return OnboardingRoutes.completeProfile;
    if (!status.profileComplete) return OnboardingRoutes.completeProfile;
    if (!status.hasOwnerBaby) {
      if (_coordinator.createdBabyId != null) {
        final step = _coordinator.activeStep;
        if (step == OnboardingStep.batchInvite) {
          return OnboardingRoutes.ownerInvite;
        }
        return OnboardingRoutes.ownerFirstMoment;
      }
      return OnboardingRoutes.ownerCreateBaby;
    }
    return OnboardingRoutes.ownerInvite;
  }
}
