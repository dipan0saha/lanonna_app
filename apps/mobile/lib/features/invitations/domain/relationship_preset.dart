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
