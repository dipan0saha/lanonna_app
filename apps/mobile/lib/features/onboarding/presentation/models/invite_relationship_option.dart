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

InviteRelationshipOption inviteRelationshipByPickerLabel(String label) {
  return kInviteRelationshipOptions.firstWhere(
    (o) => o.pickerLabel == label,
    orElse: () => kInviteRelationshipOptions[2],
  );
}
