import '../auth/auth_link_config.dart';

/// Parsed Firebase email verification action link (`mode=verifyEmail`).
class EmailVerifyActionLink {
  const EmailVerifyActionLink({required this.oobCode});

  final String oobCode;
}

/// Returns link details when [uri] is a Firebase Auth action URL for email verify.
EmailVerifyActionLink? parseEmailVerifyActionLink(Uri uri) {
  if (uri.host != AuthLinkConfig.authActionHost) return null;
  if (!uri.path.startsWith('/__/auth/action')) return null;

  final mode = uri.queryParameters['mode'];
  if (mode != 'verifyEmail') return null;

  final oobCode = uri.queryParameters['oobCode']?.trim();
  if (oobCode == null || oobCode.isEmpty) return null;

  return EmailVerifyActionLink(oobCode: oobCode);
}
