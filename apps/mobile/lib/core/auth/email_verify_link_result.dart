enum EmailVerifyLinkOutcome {
  success,
  alreadyVerified,
  invalidOrExpired,
  wrongMode,
  noSignedInUser,
}

class EmailVerifyLinkResult {
  const EmailVerifyLinkResult(this.outcome, {this.message});

  final EmailVerifyLinkOutcome outcome;
  final String? message;
}
