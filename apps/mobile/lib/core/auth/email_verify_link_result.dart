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
    this.message,
    this.promptTapContinue = false,
  });

  final EmailVerifyLinkOutcome outcome;
  final String? message;
  final bool promptTapContinue;
}
