import 'baby_gender.dart';

/// A name idea the owner entered before the baby exists on the server
/// (create-baby boy/girl fields, first-moment "Suggest a name"). Sent as
/// `{name, gender}` rows (`profile_name_suggestions`, first-moment
/// `name_suggestions`) and kept in local onboarding drafts in the same shape.
class NameSuggestionDraft {
  const NameSuggestionDraft({required this.name, required this.gender});

  final String name;

  /// [BabyGender.male] or [BabyGender.female]; the name-idea toggle has no
  /// "not sure" option.
  final BabyGender gender;

  Map<String, String> toJson() => {'name': name, 'gender': gender.apiValue};

  factory NameSuggestionDraft.fromJson(Map<dynamic, dynamic> json) {
    return NameSuggestionDraft(
      name: json['name']?.toString() ?? '',
      gender: nameIdeaGender(BabyGender.fromApi(json['gender']?.toString())),
    );
  }
}

/// Name ideas are boy or girl; anything else (older drafts) reads as boy,
/// the toggle's default.
BabyGender nameIdeaGender(BabyGender gender) =>
    gender == BabyGender.female ? BabyGender.female : BabyGender.male;
