import '../../../core/api/api_client.dart';
import 'models/invitation_accept_result.dart';
import 'models/invitation_preview.dart';

class MembershipCheckResult {
  MembershipCheckResult({
    required this.isMember,
    required this.hasPendingInvite,
  });

  final bool isMember;
  final bool hasPendingInvite;

  factory MembershipCheckResult.fromJson(Map<String, dynamic> json) {
    return MembershipCheckResult(
      isMember: json['is_member'] as bool? ?? false,
      hasPendingInvite: json['has_pending_invite'] as bool? ?? false,
    );
  }
}

class InvitationsRepository {
  InvitationsRepository(this._api);

  final ApiClient _api;

  Future<MembershipCheckResult> checkMembership(
    String babyId,
    String email,
  ) async {
    final query = Uri(queryParameters: {'email': email.trim()}).query;
    final json = await _api.getJson('/v1/babies/$babyId/membership-check?$query');
    return MembershipCheckResult.fromJson(json);
  }

  Future<InvitationPreview> fetchPreview(String token) async {
    final encoded = Uri(queryParameters: {'token': token.trim()}).query;
    final json = await _api.getJsonPublic('/v1/invitations/preview?$encoded');
    return InvitationPreview.fromJson(json);
  }

  Future<InvitationAcceptResult> accept(String token) async {
    final json = await _api.postJson('/v1/invitations/accept', body: {
      'token': token.trim(),
    });
    return InvitationAcceptResult.fromJson(json);
  }
}
