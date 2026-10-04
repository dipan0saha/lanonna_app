import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/deep_links/auth_action_app_link.dart';

void main() {
  test('parses verifyEmail action link for lanonna-dev', () {
    final uri = Uri.parse(
      'https://lanonna-dev.firebaseapp.com/__/auth/action'
      '?mode=verifyEmail&oobCode=abc123&apiKey=fake',
    );
    final parsed = parseEmailVerifyActionLink(uri);
    expect(parsed, isNotNull);
    expect(parsed!.oobCode, 'abc123');
  });

  test('rejects wrong mode', () {
    final uri = Uri.parse(
      'https://lanonna-dev.firebaseapp.com/__/auth/action'
      '?mode=resetPassword&oobCode=abc',
    );
    expect(parseEmailVerifyActionLink(uri), isNull);
  });

  test('rejects missing oobCode', () {
    final uri = Uri.parse(
      'https://lanonna-dev.firebaseapp.com/__/auth/action?mode=verifyEmail',
    );
    expect(parseEmailVerifyActionLink(uri), isNull);
  });

  test('rejects wrong host', () {
    final uri = Uri.parse(
      'https://evil.example/__/auth/action?mode=verifyEmail&oobCode=x',
    );
    expect(parseEmailVerifyActionLink(uri), isNull);
  });
}
