class InvitationAcceptResult {
  const InvitationAcceptResult({
    this.alreadyMember = false,
    this.babyProfileId,
    this.role,
    this.babyName,
    this.error,
    this.inviteeEmail,
    this.signedInEmail,
  });

  final bool alreadyMember;
  final String? babyProfileId;
  final String? role;
  final String? babyName;
  final String? error;
  final String? inviteeEmail;
  final String? signedInEmail;

  factory InvitationAcceptResult.fromJson(Map<String, dynamic> json) {
    return InvitationAcceptResult(
      alreadyMember: json['already_member'] as bool? ?? false,
      babyProfileId: json['baby_profile_id']?.toString(),
      role: json['role'] as String?,
      babyName: json['baby_name'] as String?,
      error: json['error'] as String?,
      inviteeEmail: json['invitee_email'] as String?,
      signedInEmail: json['signed_in_email'] as String?,
    );
  }
}
