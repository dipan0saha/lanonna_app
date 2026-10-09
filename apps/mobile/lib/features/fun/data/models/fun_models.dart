class NameSuggestion {
  NameSuggestion({
    required this.id,
    required this.suggestedName,
    required this.gender,
    required this.likeCount,
    required this.viewerHasLiked,
    required this.isMine,
    required this.canDelete,
    required this.authorDisplayName,
  });

  final String id;
  final String suggestedName;
  final String gender;
  final int likeCount;
  final bool viewerHasLiked;
  final bool isMine;
  final bool canDelete;
  final String authorDisplayName;

  factory NameSuggestion.fromJson(Map<String, dynamic> json) {
    final isMine = json['is_mine'] as bool? ?? false;
    return NameSuggestion(
      id: json['id'] as String,
      suggestedName: json['suggested_name'] as String,
      gender: json['gender'] as String? ?? 'unknown',
      likeCount: json['like_count'] as int? ?? 0,
      viewerHasLiked: json['viewer_has_liked'] as bool? ?? false,
      isMine: isMine,
      canDelete: json['can_delete'] as bool? ?? isMine,
      authorDisplayName:
          json['author_display_name'] as String? ?? 'Family member',
    );
  }
}

class NamesPayload {
  NamesPayload({
    required this.suggestions,
    this.viewerLikedMaleId,
    this.viewerLikedFemaleId,
  });

  final List<NameSuggestion> suggestions;
  final String? viewerLikedMaleId;
  final String? viewerLikedFemaleId;

  factory NamesPayload.fromJson(Map<String, dynamic> json) {
    final list = json['suggestions'] as List<dynamic>? ?? [];
    final liked = json['viewer_liked_by_gender'] as Map<String, dynamic>? ?? {};
    return NamesPayload(
      suggestions: list
          .whereType<Map<String, dynamic>>()
          .map(NameSuggestion.fromJson)
          .toList(),
      viewerLikedMaleId: liked['male'] as String?,
      viewerLikedFemaleId: liked['female'] as String?,
    );
  }
}

class PredictionsPayload {
  PredictionsPayload({
    required this.maleVotes,
    required this.femaleVotes,
    this.viewerGenderVote,
    this.viewerBirthdateVote,
    required this.birthdateHistogram,
    required this.genderVoters,
  });

  final int maleVotes;
  final int femaleVotes;
  final String? viewerGenderVote;
  final String? viewerBirthdateVote;
  final List<BirthdateVoteCount> birthdateHistogram;
  final List<GenderVoterRow> genderVoters;

  factory PredictionsPayload.fromJson(Map<String, dynamic> json) {
    final totals = json['gender_totals'] as Map<String, dynamic>? ?? {};
    final hist = json['birthdate_histogram'] as List<dynamic>? ?? [];
    final voters = json['gender_voters'] as List<dynamic>? ?? [];
    return PredictionsPayload(
      maleVotes: totals['male'] as int? ?? 0,
      femaleVotes: totals['female'] as int? ?? 0,
      viewerGenderVote: json['viewer_gender_vote'] as String?,
      viewerBirthdateVote: json['viewer_birthdate_vote'] as String?,
      birthdateHistogram: hist
          .whereType<Map<String, dynamic>>()
          .map(BirthdateVoteCount.fromJson)
          .toList(),
      genderVoters: voters
          .whereType<Map<String, dynamic>>()
          .map(GenderVoterRow.fromJson)
          .toList(),
    );
  }
}

class BirthdateVoteCount {
  BirthdateVoteCount({required this.date, required this.count});

  final String date;
  final int count;

  factory BirthdateVoteCount.fromJson(Map<String, dynamic> json) {
    return BirthdateVoteCount(
      date: json['date'] as String,
      count: json['count'] as int? ?? 0,
    );
  }
}

class GenderVoterRow {
  GenderVoterRow({
    required this.gender,
    required this.displayName,
  });

  final String gender;
  final String displayName;

  factory GenderVoterRow.fromJson(Map<String, dynamic> json) {
    return GenderVoterRow(
      gender: json['gender'] as String? ?? '',
      displayName: json['display_name'] as String? ?? 'Anonymous',
    );
  }
}
