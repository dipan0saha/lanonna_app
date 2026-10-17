enum EmailVerifyLinkOutcome {
  success,
  alreadyVerified,
  invalidOrExpired,
  wrongMode,
  noSignedInUser,
}

class EmailVerifyLinkResult {
  const EmailVerifyLinkResult(
    this.outcome, {
    this.firebaseErrorCode,
    this.promptTapContinue = false,
  });

  final EmailVerifyLinkOutcome outcome;
  /// Firebase error code when the link was rejected (`invalid-action-code`, …).
  final String? firebaseErrorCode;
  final bool promptTapContinue;
}
