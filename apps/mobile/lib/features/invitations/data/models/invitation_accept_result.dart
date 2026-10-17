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

  /// A successful `POST /v1/invitations/accept` body.
  factory InvitationAcceptResult.fromJson(Map<String, dynamic> json) {
    return InvitationAcceptResult(
      alreadyMember: json['already_member'] as bool? ?? false,
      babyProfileId: json['baby_profile_id']?.toString(),
      role: json['role'] as String?,
      babyName: json['baby_name'] as String?,
    );
  }

  /// A refused accept: the coded error `detail` (`{error, message, params}`).
  /// `email_mismatch` carries both addresses in `params`.
  factory InvitationAcceptResult.fromErrorDetail(Map<String, dynamic> detail) {
    final params = detail['params'];
    String? param(String key) =>
        params is Map ? params[key] as String? : null;
    return InvitationAcceptResult(
      error: detail['error'] as String?,
      inviteeEmail: param('invitee_email'),
      signedInEmail: param('signed_in_email'),
    );
  }
}
