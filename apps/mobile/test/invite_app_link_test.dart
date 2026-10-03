import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/deep_links/invite_app_link.dart';

void main() {
  test('maps valid invite app link', () {
    final uri = Uri.parse('lanonna://app/invite-accept?token=abc123');
    expect(
      inviteAppLinkToRouterLocation(uri),
      '/invite-accept?token=abc123',
    );
  });

  test('preserves role query param', () {
    final uri = Uri.parse(
      'lanonna://app/invite-accept?token=tok&role=owner',
    );
    expect(
      inviteAppLinkToRouterLocation(uri),
      '/invite-accept?token=tok&role=owner',
    );
  });

  test('rejects missing token', () {
    final uri = Uri.parse('lanonna://app/invite-accept');
    expect(inviteAppLinkToRouterLocation(uri), isNull);
  });

  test('rejects wrong host', () {
    final uri = Uri.parse('lanonna://other/invite-accept?token=x');
    expect(inviteAppLinkToRouterLocation(uri), isNull);
  });

  test('rejects https', () {
    final uri = Uri.parse('https://app/invite-accept?token=x');
    expect(inviteAppLinkToRouterLocation(uri), isNull);
  });

  test('rejects non-invite path', () {
    final uri = Uri.parse('lanonna://app/home?token=x');
    expect(inviteAppLinkToRouterLocation(uri), isNull);
  });
}
