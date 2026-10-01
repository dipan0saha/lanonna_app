import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/features/invitations/presentation/invite_accept_messages.dart';

void main() {
  test('inviteAcceptUserMessage maps known API errors', () {
    expect(inviteAcceptUserMessage('expired'), contains('expired'));
    expect(inviteAcceptUserMessage('email_mismatch'), contains('email'));
  });
}
