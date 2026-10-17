import 'package:lanonna/l10n/app_localizations.dart';

/// Relationship choices offered when inviting family.
///
/// [membershipLabel] is the value stored as `baby_memberships.relationship_label`
/// (free text on the server, so existing rows keep these canonical spellings);
/// [label] is what the picker shows in the viewer's locale.
enum RelationshipPreset {
  wife('Mother', grantsCoOwner: true),
  husband('Father', grantsCoOwner: true),
  mother('Mother', grantsCoOwner: true),
  father('Father', grantsCoOwner: true),
  grandma('Grandma'),
  grandpa('Grandpa'),
  aunt('Aunt'),
  uncle('Uncle'),
  godmother('Godmother'),
  godfather('Godfather'),
  familyFriend('Family Friend');

  const RelationshipPreset(this.membershipLabel, {this.grantsCoOwner = false});

  final String membershipLabel;
  final bool grantsCoOwner;

  /// Default row selection for a new invite.
  static const RelationshipPreset initial = grandma;

  static const List<RelationshipPreset> _followers = [
    grandma,
    grandpa,
    aunt,
    uncle,
    godmother,
    godfather,
    familyFriend,
  ];

  /// Owner onboarding batch invite (S07): co-owner via Wife/Husband.
  static const List<RelationshipPreset> onboardingOptions = [
    wife,
    husband,
    ..._followers,
  ];

  /// Post-onboarding batch invite (`/invite-family`): co-owner via Mother/Father.
  static const List<RelationshipPreset> appOptions = [
    mother,
    father,
    ..._followers,
  ];

  /// Presets that own a stored spelling. Wife/Husband are picker aliases that
  /// store `Mother`/`Father`, so a stored value reads back as Mother/Father.
  static const List<RelationshipPreset> _storedValues = appOptions;

  /// The preset whose [membershipLabel] is [stored] (case-insensitive), or
  /// null for free text that is not one of the presets.
  static RelationshipPreset? fromMembershipLabel(String? stored) {
    final normalized = stored?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) return null;
    for (final p in _storedValues) {
      if (p.membershipLabel.toLowerCase() == normalized) return p;
    }
    return null;
  }

  /// Restores a persisted draft value ([name]); [initial] when unknown.
  static RelationshipPreset fromDraft(String? raw) {
    for (final p in values) {
      if (p.name == raw) return p;
    }
    return initial;
  }

  String label(AppLocalizations l10n) => switch (this) {
        RelationshipPreset.wife => l10n.relationshipWife,
        RelationshipPreset.husband => l10n.relationshipHusband,
        RelationshipPreset.mother => l10n.relationshipMother,
        RelationshipPreset.father => l10n.relationshipFather,
        RelationshipPreset.grandma => l10n.relationshipGrandma,
        RelationshipPreset.grandpa => l10n.relationshipGrandpa,
        RelationshipPreset.aunt => l10n.relationshipAunt,
        RelationshipPreset.uncle => l10n.relationshipUncle,
        RelationshipPreset.godmother => l10n.relationshipGodmother,
        RelationshipPreset.godfather => l10n.relationshipGodfather,
        RelationshipPreset.familyFriend => l10n.relationshipFamilyFriend,
      };
}

/// What the app shows for a stored `relationship_label` (members, invites,
/// babies list, invite preview): the localized preset label when the value is
/// a preset, otherwise the stored text as typed; null when there is none.
///
/// Every screen goes through this so the API keeps one canonical value and
/// the viewer's locale decides the wording.
String? relationshipDisplayLabel(AppLocalizations l10n, String? stored) {
  final trimmed = stored?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return RelationshipPreset.fromMembershipLabel(trimmed)?.label(l10n) ?? trimmed;
}
