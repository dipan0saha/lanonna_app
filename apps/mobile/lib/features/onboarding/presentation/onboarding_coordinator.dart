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
  }) : _storage = storage,
       _repository = repository;

  final OnboardingStorage _storage;
  final OnboardingRepository _repository;

  OnboardingStep? _activeStep;
  String? _createdBabyId;
  bool _hydrated = false;

  OnboardingStep? get activeStep => _activeStep;
  String? get createdBabyId => _createdBabyId ?? _storage.createdBabyId;
  bool get isHydrated => _hydrated;

  OnboardingPath get onboardingPath =>
      _storage.onboardingPath ?? OnboardingPath.owner;

  bool get isInvitePath =>
      onboardingPath == OnboardingPath.follower ||
      onboardingPath == OnboardingPath.coOwner;

  bool get hasInviteHandoff =>
      (pendingInviteToken != null && pendingInviteToken!.isNotEmpty) ||
      cachedInvitePreview != null;

  /// True when redirect should send the user back into the invite funnel.
  /// Landing steps need a token or cached preview; mid-flow steps may resume
  /// without them until invite onboarding completes (#408).
  bool shouldResumeInviteFlow({required bool hasBabyMembership}) {
    if (!isInvitePath) return false;
    if (hasInviteHandoff) return true;
    if (inviteOnboardingCompleted) return false;
    if (hasBabyMembership) return false;
    return switch (_activeStep) {
      OnboardingStep.signup ||
      OnboardingStep.login ||
      OnboardingStep.emailVerify ||
      OnboardingStep.completeProfile ||
      OnboardingStep.confirmRelationship ||
      OnboardingStep.followerCarousel ||
      OnboardingStep.coOwnerWelcome =>
        true,
      _ => false,
    };
  }

  /// Re-binds the invite after an account switch (#406). The preview is
  /// stored through [_previewToJson], the same field allowlist as
  /// [bindInviteFromPreview], so the invitee email is never persisted.
  Future<void> restoreInviteHandoff({
    required String token,
    required OnboardingPath path,
    InvitationPreview? preview,
  }) async {
    await setPendingInviteToken(token);
    await saveOnboardingPath(path);
    if (preview != null) {
      await _storage.saveInvitePreviewJson(jsonEncode(_previewToJson(preview)));
    }
    notifyListeners();
  }

  /// Drops a stale follower/co-owner path after the server says no baby and
  /// there is no invite token or preview to resume (#408).
  Future<void> abandonStaleInvitePathIfNeeded({
    required bool hasOwnerBaby,
    required bool hasBabyMembership,
  }) async {
    if (!isInvitePath || hasInviteHandoff) return;
    if (hasOwnerBaby || hasBabyMembership) return;
    await saveOnboardingPath(OnboardingPath.owner);
    _activeStep = null;
    await _storage.clearSavedStep();
    notifyListeners();
  }

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
  CompleteProfileDraft? get completeProfileDraft =>
      _storage.completeProfileDraft;
  AuthEmailDraft? get signupEmailDraft => _storage.signupEmailDraft;
  AuthEmailDraft? get loginEmailDraft => _storage.loginEmailDraft;
  BatchInviteDraft? get batchInviteDraft => _storage.batchInviteDraft;
  String? get pendingInviteToken => _storage.pendingInviteToken;

  InvitationPreview? get cachedInvitePreview {
    final raw = _storage.invitePreviewJson;
    if (raw == null) return null;
    try {
      return InvitationPreview.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> bindInviteFromPreview(
    String token,
    InvitationPreview preview,
  ) async {
    await _storage.savePendingInviteToken(token.trim());
    await _storage.saveOnboardingPath(
      OnboardingPath.fromInvitedRole(preview.invitedRole),
    );
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
      'status': preview.status.apiValue,
      'baby_name': preview.babyName,
      'inviter_display_name': preview.inviterDisplayName,
      'relationship_label': preview.relationshipLabel,
      'invited_role': preview.invitedRole,
      'baby_profile_id': preview.babyProfileId,
      'lifecycle_status': preview.lifecycle?.apiValue,
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

  /// Full local wipe for sign-out / account delete (invites, drafts, onboarding progress).
  Future<void> clearLocalSessionForSignOut() async {
    await _storage.setCompleted(false);
    await _storage.setInviteOnboardingCompleted(false);
    await clearPendingInvite();
    await _storage.clearProgress();
    await _storage.clearCachedOnboardingStatuses();
    _activeStep = null;
    _createdBabyId = null;
    notifyListeners();
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
