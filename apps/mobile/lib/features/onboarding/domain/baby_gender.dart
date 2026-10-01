enum BabyGender {
  male,
  female,
  unknown,
}

extension BabyGenderApi on BabyGender {
  String get apiValue => name;
}

BabyGender babyGenderFromPill(String pill) {
  switch (pill) {
    case 'Boy':
      return BabyGender.male;
    case 'Girl':
      return BabyGender.female;
    default:
      return BabyGender.unknown;
  }
}

/// First-moment name suggestions store `male` / `female` in drafts and API payloads.
BabyGender nameSuggestionGenderFromDraft(String value) {
  return value == 'female' ? BabyGender.female : BabyGender.male;
}
