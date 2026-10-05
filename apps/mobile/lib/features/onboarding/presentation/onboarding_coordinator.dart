import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../invitations/data/models/invitation_preview.dart';
import '../data/create_baby_draft.dart';
import '../data/onboarding_form_drafts.dart';
import '../data/onboarding_repository.dart';
import '../data/onboarding_storage.dart';
import '../domain/onboarding_path.dart';
import '../domain/onboarding_step.dart';

class OnboardingCoordinator extends ChangeNotifier {
  OnboardingCoordinator({
    required OnboardingStorage storage,
    required OnboardingRepository repository,
  })  : _storage = storage,
        _repository = repository;

  final OnboardingStorage _storage;
  final OnboardingRepository _repository;

  OnboardingStep? _activeStep;
  String? _createdBabyId;
  bool _hydrated = false;

  OnboardingStep? get activeStep => _activeStep;
  String? get createdBabyId => _createdBabyId ?? _storage.createdBabyId;
  bool get isHydrated => _hydrated;

  OnboardingPath get onboardingPath => _storage.onboardingPath ?? OnboardingPath.owner;

  bool get isInvitePath =>
      onboardingPath == OnboardingPath.follower || onboardingPath == OnboardingPath.coOwner;

  bool get inviteOnboardingCompleted => _storage.inviteOnboardingCompleted;

  String? get invitedBabyId => _storage.invitedBabyId;

  Future<void> hydrate() async {
    _activeStep = _storage.savedStep;
    _createdBabyId = _storage.createdBabyId;
    _hydrated = true;
    notifyListeners();
  }

  Future<void> setStep(OnboardingStep step) async {
    _activeStep = step;
    await _storage.saveStep(step);
    notifyListeners();
  }

  Future<void> setCreatedBabyId(String id) async {
    _createdBabyId = id;
    await _storage.saveCreatedBabyId(id);
    notifyListeners();
  }

  Future<void> markOAuthSignIn() async {
    await _storage.setUsedOAuth(true);
  }

  bool get skipEmailVerify => _storage.usedOAuth;

  String? get babyLifecycle => _storage.babyLifecycle;
  CreateBabyDraft? get createBabyDraft => _storage.createBabyDraft;
  FirstMomentDraft? get firstMomentDraft => _storage.firstMomentDraft;
  CompleteProfileDraft? get completeProfileDraft => _storage.completeProfileDraft;
  AuthEmailDraft? get signupEmailDraft => _storage.signupEmailDraft;
  AuthEmailDraft? get loginEmailDraft => _storage.loginEmailDraft;
  BatchInviteDraft? get batchInviteDraft => _storage.batchInviteDraft;
  String? get pendingInviteToken => _storage.pendingInviteToken;

  InvitationPreview? get cachedInvitePreview {
    final raw = _storage.invitePreviewJson;
    if (raw == null) return null;
    try {
      return InvitationPreview.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> bindInviteFromPreview(
    String token,
    InvitationPreview preview,
  ) async {
    await _storage.savePendingInviteToken(token.trim());
    await _storage.saveOnboardingPath(OnboardingPath.fromInvitedRole(preview.invitedRole));
    await _storage.saveInvitePreviewJson(jsonEncode(_previewToJson(preview)));
    if (preview.babyProfileId != null) {
      await _storage.saveInvitedBabyId(preview.babyProfileId);
    }
    final step = preview.isCoOwnerInvite
        ? OnboardingStep.coOwnerInvite
        : OnboardingStep.followerInvite;
    await setStep(step);
  }

  Map<String, dynamic> _previewToJson(InvitationPreview preview) {
    return {
      'status': preview.status,
      'baby_name': preview.babyName,
      'inviter_display_name': preview.inviterDisplayName,
      'invitee_email': preview.inviteeEmail,
      'relationship_label': preview.relationshipLabel,
      'invited_role': preview.invitedRole,
      'baby_profile_id': preview.babyProfileId,
      'lifecycle_status': preview.lifecycleStatus,
      'expected_birth_date': preview.expectedBirthDate,
      'actual_birth_date': preview.actualBirthDate,
    };
  }

  Future<void> setPendingInviteToken(String? token) async {
    await _storage.savePendingInviteToken(token?.trim());
    notifyListeners();
  }

  Future<void> saveOnboardingPath(OnboardingPath path) async {
    await _storage.saveOnboardingPath(path);
    notifyListeners();
  }

  Future<void> clearPendingInvite() async {
    await _storage.savePendingInviteToken(null);
    await _storage.saveOnboardingPath(null);
    await _storage.saveInvitePreviewJson(null);
    await _storage.saveInvitedBabyId(null);
    notifyListeners();
  }

  Future<void> setInvitedBabyId(String? id) async {
    await _storage.saveInvitedBabyId(id);
    notifyListeners();
  }

  Future<void> saveBabyContext({required String lifecycle}) async {
    await _storage.saveBabyLifecycle(lifecycle);
    notifyListeners();
  }

  Future<void> saveCreateBabyDraft(CreateBabyDraft draft) async {
    await _storage.saveCreateBabyDraft(draft);
  }

  Future<void> saveFirstMomentDraft(FirstMomentDraft draft) async {
    await _storage.saveFirstMomentDraft(draft);
  }

  Future<void> saveCompleteProfileDraft(CompleteProfileDraft draft) async {
    await _storage.saveCompleteProfileDraft(draft);
  }

  Future<void> saveSignupEmailDraft(AuthEmailDraft draft) async {
    await _storage.saveSignupEmailDraft(draft);
  }

  Future<void> saveLoginEmailDraft(AuthEmailDraft draft) async {
    await _storage.saveLoginEmailDraft(draft);
  }

  Future<void> saveBatchInviteDraft(BatchInviteDraft draft) async {
    await _storage.saveBatchInviteDraft(draft);
  }

  Future<void> completeOnboarding() async {
    await _repository.completeOwnerOnboarding();
    await _storage.setCompleted(true);
    _activeStep = null;
    notifyListeners();
  }

  /// Clears local owner completion so the next signed-in user is not treated as onboarded.
  Future<void> resetOwnerCompletionForSignOut() async {
    await _storage.setCompleted(false);
  }

  Future<void> completeInviteOnboarding() async {
    await _storage.setInviteOnboardingCompleted(true);
    _activeStep = null;
    notifyListeners();
  }

  Future<void> syncCompletedFromServer(bool completed) async {
    if (completed) {
      await _storage.setCompleted(true);
      _activeStep = null;
      notifyListeners();
    }
  }
}
