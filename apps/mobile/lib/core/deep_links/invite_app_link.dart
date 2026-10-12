import '../auth/auth_link_config.dart';
import '../../features/onboarding/domain/onboarding_routes.dart';

/// Maps an invite link to a GoRouter location.
///
/// Accepts the custom scheme (`lanonna://app/invite-accept`) and the HTTPS
/// landing URL (`https://{project}.firebaseapp.com/invite`). The token is
/// copied into the router query and must not be logged.
String? inviteAppLinkToRouterLocation(Uri uri) {
  if (!_isInviteUri(uri)) return null;

  final token = uri.queryParameters['token']?.trim();
  if (token == null || token.isEmpty) return null;

  final params = <String, String>{'token': token};
  final role = uri.queryParameters['role'];
  if (role != null && role.isNotEmpty) {
    params['role'] = role;
  }
  return '${OnboardingRoutes.inviteAccept}?${Uri(queryParameters: params).query}';
}

bool _isInviteUri(Uri uri) {
  final path = _normalizedPath(uri);
  if (uri.scheme == 'lanonna' && uri.host == 'app') {
    return path == OnboardingRoutes.inviteAccept;
  }
  if (uri.scheme == 'https' && uri.host == AuthLinkConfig.authActionHost) {
    return path == '/invite' || path.startsWith('/invite/');
  }
  return false;
}

String _normalizedPath(Uri uri) {
  final path = uri.path.isEmpty && uri.pathSegments.isNotEmpty
      ? '/${uri.pathSegments.join('/')}'
      : uri.path;
  if (path.isEmpty) return '/';
  return path.startsWith('/') ? path : '/$path';
}
