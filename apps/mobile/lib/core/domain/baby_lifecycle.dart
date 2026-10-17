import 'package:lanonna/l10n/app_localizations.dart';

/// Server-owned baby lifecycle (`baby_profiles.lifecycle_status`).
enum BabyLifecycle {
  expecting('expecting'),
  born('born');

  const BabyLifecycle(this.apiValue);

  final String apiValue;

  /// Unknown or missing values fall back to [expecting] (the API default).
  static BabyLifecycle fromApi(String? raw) =>
      raw == born.apiValue ? born : expecting;

  String label(AppLocalizations l10n) => switch (this) {
        BabyLifecycle.expecting => l10n.stageExpecting,
        BabyLifecycle.born => l10n.lifecycleBorn,
      };
}
