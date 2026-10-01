import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/onboarding_path.dart';
import '../domain/onboarding_step.dart';
import 'create_baby_draft.dart';
import 'onboarding_form_drafts.dart';

abstract final class OnboardingStorageKeys {
  static const completed = 'owner_onboarding_completed';
  static const step = 'owner_onboarding_step';
  static const createdBabyId = 'owner_onboarding_baby_id';
  static const usedOAuth = 'owner_onboarding_used_oauth';
  static const babyLifecycle = 'owner_onboarding_baby_lifecycle';
  static const createBabyDraft = 'owner_onboarding_create_baby_draft';
  static const firstMomentDraft = 'owner_onboarding_first_moment_draft';
  static const completeProfileDraft = 'owner_onboarding_complete_profile_draft';
  static const signupEmailDraft = 'owner_onboarding_signup_email_draft';
  static const loginEmailDraft = 'owner_onboarding_login_email_draft';
  static const batchInviteDraft = 'owner_onboarding_batch_invite_draft';
  static const pendingInviteToken = 'pending_invite_token';
  static const onboardingPath = 'onboarding_path';
  static const inviteOnboardingCompleted = 'invite_onboarding_completed';
  static const invitedBabyId = 'invited_baby_id';
  static const invitePreviewJson = 'invite_preview_json';
}

class OnboardingStorage {
  OnboardingStorage(this._prefs);

  final SharedPreferences _prefs;

  SharedPreferences get sharedPreferences => _prefs;

  static Future<OnboardingStorage> create() async {
    final prefs = await SharedPreferences.getInstance();
    return OnboardingStorage(prefs);
  }

  bool get isCompleted => _prefs.getBool(OnboardingStorageKeys.completed) ?? false;

  Future<void> setCompleted(bool value) async {
    await _prefs.setBool(OnboardingStorageKeys.completed, value);
    if (value) {
      await clearProgress();
    }
  }

  OnboardingStep? get savedStep =>
      OnboardingStepStorage.fromStorage(_prefs.getString(OnboardingStorageKeys.step));

  Future<void> saveStep(OnboardingStep step) async {
    await _prefs.setString(OnboardingStorageKeys.step, step.storageKey);
  }

  String? get createdBabyId => _prefs.getString(OnboardingStorageKeys.createdBabyId);

  Future<void> saveCreatedBabyId(String id) async {
    await _prefs.setString(OnboardingStorageKeys.createdBabyId, id);
  }

  bool get usedOAuth => _prefs.getBool(OnboardingStorageKeys.usedOAuth) ?? false;

  Future<void> setUsedOAuth(bool value) async {
    await _prefs.setBool(OnboardingStorageKeys.usedOAuth, value);
  }

  String? get babyLifecycle => _prefs.getString(OnboardingStorageKeys.babyLifecycle);

  Future<void> saveBabyLifecycle(String value) async {
    await _prefs.setString(OnboardingStorageKeys.babyLifecycle, value);
  }

  CreateBabyDraft? get createBabyDraft {
    final raw = _prefs.getString(OnboardingStorageKeys.createBabyDraft);
    if (raw == null) return null;
    return CreateBabyDraft.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveCreateBabyDraft(CreateBabyDraft draft) async {
    await _prefs.setString(
      OnboardingStorageKeys.createBabyDraft,
      jsonEncode(draft.toJson()),
    );
  }

  FirstMomentDraft? get firstMomentDraft {
    final raw = _prefs.getString(OnboardingStorageKeys.firstMomentDraft);
    if (raw == null) return null;
    return FirstMomentDraft.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveFirstMomentDraft(FirstMomentDraft draft) async {
    await _prefs.setString(
      OnboardingStorageKeys.firstMomentDraft,
      jsonEncode(draft.toJson()),
    );
  }

  CompleteProfileDraft? get completeProfileDraft {
    final raw = _prefs.getString(OnboardingStorageKeys.completeProfileDraft);
    if (raw == null) return null;
    return CompleteProfileDraft.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveCompleteProfileDraft(CompleteProfileDraft draft) async {
    await _prefs.setString(
      OnboardingStorageKeys.completeProfileDraft,
      jsonEncode(draft.toJson()),
    );
  }

  AuthEmailDraft? get signupEmailDraft => _readEmailDraft(OnboardingStorageKeys.signupEmailDraft);

  Future<void> saveSignupEmailDraft(AuthEmailDraft draft) async {
    await _saveEmailDraft(OnboardingStorageKeys.signupEmailDraft, draft);
  }

  AuthEmailDraft? get loginEmailDraft => _readEmailDraft(OnboardingStorageKeys.loginEmailDraft);

  Future<void> saveLoginEmailDraft(AuthEmailDraft draft) async {
    await _saveEmailDraft(OnboardingStorageKeys.loginEmailDraft, draft);
  }

  BatchInviteDraft? get batchInviteDraft {
    final raw = _prefs.getString(OnboardingStorageKeys.batchInviteDraft);
    if (raw == null) return null;
    return BatchInviteDraft.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  String? get pendingInviteToken => _prefs.getString(OnboardingStorageKeys.pendingInviteToken);

  bool get inviteOnboardingCompleted =>
      _prefs.getBool(OnboardingStorageKeys.inviteOnboardingCompleted) ?? false;

  Future<void> setInviteOnboardingCompleted(bool value) async {
    await _prefs.setBool(OnboardingStorageKeys.inviteOnboardingCompleted, value);
    if (value) {
      await _prefs.remove(OnboardingStorageKeys.step);
      await _prefs.remove(OnboardingStorageKeys.pendingInviteToken);
      await _prefs.remove(OnboardingStorageKeys.invitePreviewJson);
    }
  }

  OnboardingPath? get onboardingPath =>
      OnboardingPath.fromStorage(_prefs.getString(OnboardingStorageKeys.onboardingPath));

  Future<void> saveOnboardingPath(OnboardingPath? path) async {
    if (path == null) {
      await _prefs.remove(OnboardingStorageKeys.onboardingPath);
    } else {
      await _prefs.setString(OnboardingStorageKeys.onboardingPath, path.storageKey);
    }
  }

  String? get invitedBabyId => _prefs.getString(OnboardingStorageKeys.invitedBabyId);

  Future<void> saveInvitedBabyId(String? id) async {
    if (id == null || id.isEmpty) {
      await _prefs.remove(OnboardingStorageKeys.invitedBabyId);
    } else {
      await _prefs.setString(OnboardingStorageKeys.invitedBabyId, id);
    }
  }

  String? get invitePreviewJson => _prefs.getString(OnboardingStorageKeys.invitePreviewJson);

  Future<void> saveInvitePreviewJson(String? json) async {
    if (json == null || json.isEmpty) {
      await _prefs.remove(OnboardingStorageKeys.invitePreviewJson);
    } else {
      await _prefs.setString(OnboardingStorageKeys.invitePreviewJson, json);
    }
  }

  Future<void> savePendingInviteToken(String? token) async {
    if (token == null || token.isEmpty) {
      await _prefs.remove(OnboardingStorageKeys.pendingInviteToken);
    } else {
      await _prefs.setString(OnboardingStorageKeys.pendingInviteToken, token);
    }
  }

  Future<void> saveBatchInviteDraft(BatchInviteDraft draft) async {
    await _prefs.setString(
      OnboardingStorageKeys.batchInviteDraft,
      jsonEncode(draft.toJson()),
    );
  }

  AuthEmailDraft? _readEmailDraft(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    return AuthEmailDraft.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> _saveEmailDraft(String key, AuthEmailDraft draft) async {
    await _prefs.setString(key, jsonEncode(draft.toJson()));
  }

  Future<void> clearProgress() async {
    await _prefs.remove(OnboardingStorageKeys.step);
    await _prefs.remove(OnboardingStorageKeys.createdBabyId);
    await _prefs.remove(OnboardingStorageKeys.usedOAuth);
    await _prefs.remove(OnboardingStorageKeys.babyLifecycle);
    await _prefs.remove(OnboardingStorageKeys.createBabyDraft);
    await _prefs.remove(OnboardingStorageKeys.firstMomentDraft);
    await _prefs.remove(OnboardingStorageKeys.completeProfileDraft);
    await _prefs.remove(OnboardingStorageKeys.signupEmailDraft);
    await _prefs.remove(OnboardingStorageKeys.loginEmailDraft);
    await _prefs.remove(OnboardingStorageKeys.batchInviteDraft);
    await _prefs.remove(OnboardingStorageKeys.pendingInviteToken);
  }
}
