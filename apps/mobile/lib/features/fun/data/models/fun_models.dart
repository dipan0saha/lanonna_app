import '../../../../core/json/json_readers.dart';
import 'package:lanonna/core/domain/baby_gender.dart';

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
  final BabyGender gender;
  final int likeCount;
  final bool viewerHasLiked;
  final bool isMine;
  final bool canDelete;
  final String authorDisplayName;

  NameSuggestion copyWith({bool? viewerHasLiked, int? likeCount}) {
    return NameSuggestion(
      id: id,
      suggestedName: suggestedName,
      gender: gender,
      likeCount: likeCount ?? this.likeCount,
      viewerHasLiked: viewerHasLiked ?? this.viewerHasLiked,
      isMine: isMine,
      canDelete: canDelete,
      authorDisplayName: authorDisplayName,
    );
  }

  factory NameSuggestion.fromJson(Map<String, dynamic> json) {
    final isMine = json['is_mine'] as bool? ?? false;
    return NameSuggestion(
      id: json['id'] as String,
      suggestedName: json['suggested_name'] as String,
      gender: BabyGender.fromApi(json['gender'] as String?),
      likeCount: readInt(json['like_count']),
      viewerHasLiked: json['viewer_has_liked'] as bool? ?? false,
      isMine: isMine,
      canDelete: json['can_delete'] as bool? ?? isMine,
      authorDisplayName:
          json['author_display_name'] as String? ?? '',
    );
  }
}

class NamesPayload {
  NamesPayload({
    required this.suggestions,
    this.viewerLikedMaleId,
    this.viewerLikedFemaleId,
    this.namesClosed = false,
  });

  final List<NameSuggestion> suggestions;
  final String? viewerLikedMaleId;
  final String? viewerLikedFemaleId;
  final bool namesClosed;

  /// The payload after the viewer toggles the like on [suggestionId], by the
  /// server's rule: one like per gender, so liking a name moves the viewer's
  /// like off any other name of that gender.
  NamesPayload withLikeToggled(String suggestionId) {
    final target = suggestions.where((s) => s.id == suggestionId).firstOrNull;
    if (target == null) return this;
    final liking = !target.viewerHasLiked;
    final gender = target.gender;
    final updated = [
      for (final s in suggestions)
        if (s.id == suggestionId)
          s.copyWith(
            viewerHasLiked: liking,
            likeCount: liking ? s.likeCount + 1 : _decrement(s.likeCount),
          )
        else if (liking && s.gender == gender && s.viewerHasLiked)
          s.copyWith(viewerHasLiked: false, likeCount: _decrement(s.likeCount))
        else
          s,
    ];
    final likedId = liking ? suggestionId : null;
    return NamesPayload(
      suggestions: updated,
      viewerLikedMaleId: gender == BabyGender.male
          ? likedId
          : viewerLikedMaleId,
      viewerLikedFemaleId: gender == BabyGender.female
          ? likedId
          : viewerLikedFemaleId,
      namesClosed: namesClosed,
    );
  }

  static int _decrement(int count) => count > 0 ? count - 1 : 0;

  factory NamesPayload.fromJson(Map<String, dynamic> json) {
    final list = json['suggestions'] as List<dynamic>? ?? [];
    final liked = json['viewer_liked_by_gender'] as Map<String, dynamic>? ?? {};
    return NamesPayload(
      suggestions: list
          .whereType<Map<String, dynamic>>()
          .map(NameSuggestion.fromJson)
          .toList(),
      viewerLikedMaleId: liked[BabyGender.male.apiValue] as String?,
      viewerLikedFemaleId: liked[BabyGender.female.apiValue] as String?,
      namesClosed: json['names_closed'] as bool? ?? false,
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
    this.predictionsClosed = false,
  });

  final int maleVotes;
  final int femaleVotes;
  /// `null` until the viewer votes; otherwise male or female.
  final BabyGender? viewerGenderVote;
  final String? viewerBirthdateVote;
  final List<BirthdateVoteCount> birthdateHistogram;
  final List<GenderVoterRow> genderVoters;

  /// True when the baby is born and votes can no longer be cast or changed.
  final bool predictionsClosed;

  /// The totals after the viewer votes [gender] (an upsert on the server: a
  /// changed vote moves from the old gender to the new one). The voter list
  /// is left as is until the next load.
  PredictionsPayload withGenderVote(BabyGender gender) {
    final previous = viewerGenderVote;
    if (previous == gender) return this;
    int adjust(int votes, BabyGender side) {
      if (side == gender) return votes + 1;
      if (side == previous && votes > 0) return votes - 1;
      return votes;
    }

    return PredictionsPayload(
      maleVotes: adjust(maleVotes, BabyGender.male),
      femaleVotes: adjust(femaleVotes, BabyGender.female),
      viewerGenderVote: gender,
      viewerBirthdateVote: viewerBirthdateVote,
      birthdateHistogram: birthdateHistogram,
      genderVoters: genderVoters,
      predictionsClosed: predictionsClosed,
    );
  }

  factory PredictionsPayload.fromJson(Map<String, dynamic> json) {
    final totals = json['gender_totals'] as Map<String, dynamic>? ?? {};
    final hist = json['birthdate_histogram'] as List<dynamic>? ?? [];
    final voters = json['gender_voters'] as List<dynamic>? ?? [];
    return PredictionsPayload(
      maleVotes: readInt(totals[BabyGender.male.apiValue]),
      femaleVotes: readInt(totals[BabyGender.female.apiValue]),
      viewerGenderVote: BabyGender.tryFromApi(json['viewer_gender_vote'] as String?),
      viewerBirthdateVote: json['viewer_birthdate_vote'] as String?,
      birthdateHistogram: hist
          .whereType<Map<String, dynamic>>()
          .map(BirthdateVoteCount.fromJson)
          .toList(),
      genderVoters: voters
          .whereType<Map<String, dynamic>>()
          .map(GenderVoterRow.fromJson)
          .toList(),
      predictionsClosed: json['predictions_closed'] as bool? ?? false,
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
      count: readInt(json['count']),
    );
  }
}

class GenderVoterRow {
  GenderVoterRow({required this.gender, required this.displayName});

  final BabyGender gender;
  final String displayName;

  factory GenderVoterRow.fromJson(Map<String, dynamic> json) {
    return GenderVoterRow(
      gender: BabyGender.fromApi(json['gender'] as String?),
      displayName: json['display_name'] as String? ?? '',
    );
  }
}
