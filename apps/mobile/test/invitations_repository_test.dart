import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/api/api_client.dart';
import 'package:lanonna/core/api/api_exception.dart';
import 'package:lanonna/features/invitations/data/invitations_repository.dart';

void main() {
  test('accept maps structured API error detail to result', () async {
    final repo = InvitationsRepository(_AcceptErrorApi());
    final result = await repo.accept('token-12345678');
    expect(result.error, 'email_mismatch');
    expect(result.inviteeEmail, 'invited@test.com');
    expect(result.signedInEmail, 'signed@test.com');
  });
}

class _AcceptErrorApi extends ApiClient {
  _AcceptErrorApi() : super(idTokenProvider: () async => 'token');

  @override
  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    throw ApiException(
      'email_mismatch',
      statusCode: 403,
      detail: {
        'error': 'email_mismatch',
        'invitee_email': 'invited@test.com',
        'signed_in_email': 'signed@test.com',
      },
    );
  }
}
