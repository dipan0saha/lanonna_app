class InvitationPreview {
  const InvitationPreview({
    required this.status,
    this.babyName,
    this.inviterDisplayName,
    this.inviteeEmail,
    this.relationshipLabel,
    this.invitedRole,
    this.babyProfileId,
    this.lifecycleStatus,
    this.expectedBirthDate,
    this.actualBirthDate,
  });

  final String status;
  final String? babyName;
  final String? inviterDisplayName;
  final String? inviteeEmail;
  final String? relationshipLabel;
  final String? invitedRole;
  final String? babyProfileId;
  final String? lifecycleStatus;
  final String? expectedBirthDate;
  final String? actualBirthDate;

  bool get isPending => status == 'pending';
  bool get isExpired => status == 'expired';
  bool get isCoOwnerInvite => invitedRole == 'owner';
  bool get isBorn => lifecycleStatus == 'born';

  factory InvitationPreview.fromJson(Map<String, dynamic> json) {
    return InvitationPreview(
      status: json['status'] as String? ?? 'expired',
      babyName: json['baby_name'] as String?,
      inviterDisplayName: json['inviter_display_name'] as String?,
      inviteeEmail: json['invitee_email'] as String?,
      relationshipLabel: json['relationship_label'] as String?,
      invitedRole: json['invited_role'] as String?,
      babyProfileId: json['baby_profile_id']?.toString(),
      lifecycleStatus: json['lifecycle_status'] as String?,
      expectedBirthDate: json['expected_birth_date']?.toString(),
      actualBirthDate: json['actual_birth_date']?.toString(),
    );
  }
}
