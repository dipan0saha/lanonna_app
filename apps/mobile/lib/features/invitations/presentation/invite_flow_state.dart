import 'package:flutter/foundation.dart';

import '../../onboarding/domain/onboarding_path.dart';

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
  String? _resumeInvitePreviewJson;

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

  /// Preserves invite context across sign-out when switching accounts (not in URLs).
  void setInviteResume({
    required String token,
    required OnboardingPath path,
    String? previewJson,
  }) {
    _resumeInviteToken = token.trim();
    _resumeOnboardingPath = path;
    _resumeInvitePreviewJson = previewJson;
    notifyListeners();
  }

  ({String token, OnboardingPath path, String? previewJson})? takeInviteResume() {
    final token = _resumeInviteToken;
    final path = _resumeOnboardingPath;
    final previewJson = _resumeInvitePreviewJson;
    _resumeInviteToken = null;
    _resumeOnboardingPath = null;
    _resumeInvitePreviewJson = null;
    if (token == null || token.isEmpty || path == null) return null;
    return (token: token, path: path, previewJson: previewJson);
  }

  void clear() {
    _emailMismatch = null;
    _loginPrefillEmail = null;
    _signupPrefillEmail = null;
    _resumeInviteToken = null;
    _resumeOnboardingPath = null;
    _resumeInvitePreviewJson = null;
    notifyListeners();
  }
}
