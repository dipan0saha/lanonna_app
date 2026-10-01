import '../../../core/api/api_client.dart';
import 'models/invitation_accept_result.dart';
import 'models/invitation_preview.dart';

class InvitationsRepository {
  InvitationsRepository(this._api);

  final ApiClient _api;

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
