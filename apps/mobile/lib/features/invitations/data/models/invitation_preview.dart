import '../../../../core/domain/baby_lifecycle.dart';
import '../../domain/invitation_status.dart';

class InvitationPreview {
  const InvitationPreview({
    required this.status,
    this.babyName,
    this.inviterDisplayName,
    this.inviteeEmail,
    this.relationshipLabel,
    this.invitedRole,
    this.babyProfileId,
    this.lifecycle,
    this.expectedBirthDate,
    this.actualBirthDate,
  });

  final InvitationStatus status;
  final String? babyName;
  final String? inviterDisplayName;
  final String? inviteeEmail;
  final String? relationshipLabel;
  final String? invitedRole;
  final String? babyProfileId;
  final BabyLifecycle? lifecycle;
  final String? expectedBirthDate;
  final String? actualBirthDate;

  bool get isPending => status == InvitationStatus.pending;
  bool get isAccepted => status == InvitationStatus.accepted;
  bool get isExpired => status == InvitationStatus.expired;
  bool get isRevoked => status == InvitationStatus.revoked;

  /// Pending or already-accepted invite links may continue onboarding (FR-INV-002).
  bool get canContinueInviteFlow => isPending || isAccepted;
  bool get isCoOwnerInvite => invitedRole == 'owner';
  bool get isBorn => lifecycle == BabyLifecycle.born;

  factory InvitationPreview.fromJson(Map<String, dynamic> json) {
    return InvitationPreview(
      status: InvitationStatus.fromApi(json['status'] as String?),
      babyName: json['baby_name'] as String?,
      inviterDisplayName: json['inviter_display_name'] as String?,
      inviteeEmail: json['invitee_email'] as String?,
      relationshipLabel: json['relationship_label'] as String?,
      invitedRole: json['invited_role'] as String?,
      babyProfileId: json['baby_profile_id']?.toString(),
      lifecycle: json['lifecycle_status'] == null
          ? null
          : BabyLifecycle.fromApi(json['lifecycle_status'] as String?),
      expectedBirthDate: json['expected_birth_date']?.toString(),
      actualBirthDate: json['actual_birth_date']?.toString(),
    );
  }
}
