import '../../features/onboarding/domain/onboarding_routes.dart';

/// Maps `lanonna://app/invite-accept?token=…` to a GoRouter location.
String? inviteAppLinkToRouterLocation(Uri uri) {
  if (uri.scheme != 'lanonna') return null;
  if (uri.host != 'app') return null;

  final path = uri.path.isEmpty && uri.pathSegments.isNotEmpty
      ? '/${uri.pathSegments.join('/')}'
      : uri.path;
  final normalized = path.startsWith('/') ? path : '/$path';
  if (normalized != OnboardingRoutes.inviteAccept) return null;

  final token = uri.queryParameters['token']?.trim();
  if (token == null || token.isEmpty) return null;

  final params = <String, String>{'token': token};
  final role = uri.queryParameters['role'];
  if (role != null && role.isNotEmpty) {
    params['role'] = role;
  }
  return '${OnboardingRoutes.inviteAccept}?${Uri(queryParameters: params).query}';
}
