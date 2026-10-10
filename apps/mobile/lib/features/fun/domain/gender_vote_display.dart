/// Presentation metrics for boy/girl gender vote totals (Fun + Home insight).
class GenderVoteDisplay {
  GenderVoteDisplay({required this.maleVotes, required this.femaleVotes});

  final int maleVotes;
  final int femaleVotes;

  int get total => maleVotes + femaleVotes;

  /// Rounded percent for male column; null when nobody has voted.
  int? get malePercent =>
      total > 0 ? ((maleVotes / total) * 100).round() : null;

  int? get femalePercent =>
      malePercent != null ? 100 - malePercent! : null;

  /// Progress bar fill for male share; null hides misleading 50% empty state.
  double? get maleProgress => total > 0 ? maleVotes / total : null;

  int displayPercentForMale() => malePercent ?? 0;

  int displayPercentForFemale() => femalePercent ?? 0;
}

GenderVoteDisplay genderVoteDisplay({required int maleVotes, required int femaleVotes}) {
  return GenderVoteDisplay(maleVotes: maleVotes, femaleVotes: femaleVotes);
}
