import '../../../core/domain/relationship_preset.dart';

/// Owner demographics used to derive default baby profile name (#316).
class BabyNameParentContext {
  const BabyNameParentContext({
    this.ownerLastName,
    this.relationshipLabel,
  });

  final String? ownerLastName;
  final String? relationshipLabel;
}

/// Last name from a stored profile `display_name` (same split as complete profile).
String? profileLastNameFromDisplayName(String displayName) {
  final parts = displayName.trim().split(RegExp(r'\s+'));
  if (parts.length < 2) return null;
  final last = parts.sublist(1).join(' ');
  if (last.trim().isEmpty) return null;
  return last.trim();
}

bool _isMotherOrFatherRelationship(String? relationshipLabel) {
  final label = relationshipLabel?.trim();
  return label == RelationshipPreset.father.membershipLabel ||
      label == RelationshipPreset.mother.membershipLabel;
}

/// Surname for expecting + unknown gender when both boy and girl names are set.
String? babyProfileSurnameWhenBothTentativeNamesFilled(
  BabyNameParentContext? parentContext,
) {
  if (parentContext == null) return null;
  final last = parentContext.ownerLastName?.trim();
  if (last == null || last.isEmpty) return null;
  if (!_isMotherOrFatherRelationship(parentContext.relationshipLabel)) {
    return null;
  }
  return last;
}
