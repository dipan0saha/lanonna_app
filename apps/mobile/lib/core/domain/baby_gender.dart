import 'package:lanonna/l10n/app_localizations.dart';

/// Server-owned baby gender (`baby_profiles.gender`, name suggestions, votes).
enum BabyGender {
  male('male'),
  female('female'),
  unknown('unknown');

  const BabyGender(this.apiValue);

  final String apiValue;

  /// Missing or unrecognised values are [unknown].
  static BabyGender fromApi(String? raw) => values.firstWhere(
        (g) => g.apiValue == raw,
        orElse: () => BabyGender.unknown,
      );

  String label(AppLocalizations l10n) => switch (this) {
        BabyGender.male => l10n.genderBoy,
        BabyGender.female => l10n.genderGirl,
        BabyGender.unknown => l10n.genderNotSure,
      };
}

/// First-moment name suggestions store `male` / `female` in drafts and API payloads.
BabyGender nameSuggestionGenderFromDraft(String value) {
  return value == 'female' ? BabyGender.female : BabyGender.male;
}
