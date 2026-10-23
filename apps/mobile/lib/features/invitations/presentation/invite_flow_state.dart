import 'package:flutter/foundation.dart';

import '../../onboarding/domain/onboarding_path.dart';
import '../data/models/invitation_preview.dart';

/// In-memory invite flow data (M-54). Do not put PII or tokens in GoRouter query strings.
class InviteEmailMismatch {
  const InviteEmailMismatch({
    required this.inviteeEmail,
    required this.signedInEmail,
  });

  final String inviteeEmail;
  final String signedInEmail;
}

class InviteFlowState extends ChangeNotifier {
  InviteEmailMismatch? _emailMismatch;
  String? _loginPrefillEmail;
  String? _signupPrefillEmail;
  String? _resumeInviteToken;
  OnboardingPath? _resumeOnboardingPath;
  InvitationPreview? _resumeInvitePreview;

  InviteEmailMismatch? get emailMismatch => _emailMismatch;

  void setEmailMismatch({
    required String inviteeEmail,
    required String signedInEmail,
  }) {
    _emailMismatch = InviteEmailMismatch(
      inviteeEmail: inviteeEmail,
      signedInEmail: signedInEmail,
    );
    notifyListeners();
  }

  void clearEmailMismatch() {
    _emailMismatch = null;
    notifyListeners();
  }

  void setLoginPrefillEmail(String? email) {
    final trimmed = email?.trim();
    _loginPrefillEmail =
        trimmed == null || trimmed.isEmpty ? null : trimmed;
    notifyListeners();
  }

  String? takeLoginPrefillEmail() {
    final value = _loginPrefillEmail;
    _loginPrefillEmail = null;
    return value;
  }

  void setSignupPrefillEmail(String? email) {
    final trimmed = email?.trim();
    _signupPrefillEmail =
        trimmed == null || trimmed.isEmpty ? null : trimmed;
    notifyListeners();
  }

  String? takeSignupPrefillEmail() {
    final value = _signupPrefillEmail;
    _signupPrefillEmail = null;
    return value;
  }

  /// Preserves invite context across sign-out when switching accounts (not in
  /// URLs). In memory only, and only until the login screen takes it; the
  /// preview is the parsed model, persisted again through the coordinator's
  /// field allowlist (no invitee email).
  void setInviteResume({
    required String token,
    required OnboardingPath path,
    InvitationPreview? preview,
  }) {
    _resumeInviteToken = token.trim();
    _resumeOnboardingPath = path;
    _resumeInvitePreview = preview;
    notifyListeners();
  }

  ({String token, OnboardingPath path, InvitationPreview? preview})?
  takeInviteResume() {
    final token = _resumeInviteToken;
    final path = _resumeOnboardingPath;
    final preview = _resumeInvitePreview;
    _resumeInviteToken = null;
    _resumeOnboardingPath = null;
    _resumeInvitePreview = null;
    if (token == null || token.isEmpty || path == null) return null;
    return (token: token, path: path, preview: preview);
  }

  void clear() {
    _emailMismatch = null;
    _loginPrefillEmail = null;
    _signupPrefillEmail = null;
    _resumeInviteToken = null;
    _resumeOnboardingPath = null;
    _resumeInvitePreview = null;
    notifyListeners();
  }
}
