class InviteRelationshipOption {
  const InviteRelationshipOption({
    required this.pickerLabel,
    required this.membershipLabel,
    required this.grantsCoOwner,
  });

  final String pickerLabel;
  final String membershipLabel;
  final bool grantsCoOwner;
}

const List<InviteRelationshipOption> _followerRelationshipOptions = [
  InviteRelationshipOption(
    pickerLabel: 'Grandma',
    membershipLabel: 'Grandma',
    grantsCoOwner: false,
  ),
  InviteRelationshipOption(
    pickerLabel: 'Grandpa',
    membershipLabel: 'Grandpa',
    grantsCoOwner: false,
  ),
  InviteRelationshipOption(
    pickerLabel: 'Aunt',
    membershipLabel: 'Aunt',
    grantsCoOwner: false,
  ),
  InviteRelationshipOption(
    pickerLabel: 'Uncle',
    membershipLabel: 'Uncle',
    grantsCoOwner: false,
  ),
  InviteRelationshipOption(
    pickerLabel: 'Godmother',
    membershipLabel: 'Godmother',
    grantsCoOwner: false,
  ),
  InviteRelationshipOption(
    pickerLabel: 'Godfather',
    membershipLabel: 'Godfather',
    grantsCoOwner: false,
  ),
  InviteRelationshipOption(
    pickerLabel: 'Family Friend',
    membershipLabel: 'Family Friend',
    grantsCoOwner: false,
  ),
];

/// Owner onboarding batch invite (S07): co-owner via Wife/Husband picker labels.
const List<InviteRelationshipOption> kInviteRelationshipOptions = [
  InviteRelationshipOption(
    pickerLabel: 'Wife',
    membershipLabel: 'Mother',
    grantsCoOwner: true,
  ),
  InviteRelationshipOption(
    pickerLabel: 'Husband',
    membershipLabel: 'Father',
    grantsCoOwner: true,
  ),
  ..._followerRelationshipOptions,
];

/// Post-onboarding batch invite (`/invite-family`); co-owner via Mother/Father labels.
const List<InviteRelationshipOption> kAppBatchInviteRelationshipOptions = [
  InviteRelationshipOption(
    pickerLabel: 'Mother',
    membershipLabel: 'Mother',
    grantsCoOwner: true,
  ),
  InviteRelationshipOption(
    pickerLabel: 'Father',
    membershipLabel: 'Father',
    grantsCoOwner: true,
  ),
  ..._followerRelationshipOptions,
];

InviteRelationshipOption inviteRelationshipByPickerLabel(String label) {
  for (final option in kInviteRelationshipOptions) {
    if (option.pickerLabel == label) return option;
  }
  for (final option in kAppBatchInviteRelationshipOptions) {
    if (option.pickerLabel == label) return option;
  }
  return kInviteRelationshipOptions[2];
}
