import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/auth/auth_email_verification.dart';
import 'package:lanonna/core/auth/auth_link_config.dart';

void main() {
  test('email verification continue URL uses hosting success page', () {
    final url = AuthLinkConfig.emailVerificationContinueUrl;
    expect(url.host, AuthLinkConfig.authActionHost);
    expect(url.path, '/email-verified');
  });

  test('ActionCodeSettings uses same continue URL', () {
    final settings = buildEmailVerificationActionCodeSettings();
    expect(
      settings.url,
      AuthLinkConfig.emailVerificationContinueUrl.toString(),
    );
    expect(settings.handleCodeInApp, isTrue);
  });
}
