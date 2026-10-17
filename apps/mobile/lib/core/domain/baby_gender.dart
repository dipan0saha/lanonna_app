import 'package:lanonna/l10n/app_localizations.dart';

/// Server-owned baby gender (`baby_profiles.gender`, name suggestions, votes).
enum BabyGender {
  male('male'),
  female('female'),
  unknown('unknown');

  const BabyGender(this.apiValue);

  final String apiValue;

  /// Missing or unrecognised values are [unknown].
  static BabyGender fromApi(String? raw) => tryFromApi(raw) ?? BabyGender.unknown;

  /// For optional choices (a vote, an announcement): `null` when the value is
  /// missing or unrecognised.
  static BabyGender? tryFromApi(String? raw) {
    for (final g in values) {
      if (g.apiValue == raw) return g;
    }
    return null;
  }

  String label(AppLocalizations l10n) => switch (this) {
        BabyGender.male => l10n.genderBoy,
        BabyGender.female => l10n.genderGirl,
        BabyGender.unknown => l10n.genderNotSure,
      };
}
