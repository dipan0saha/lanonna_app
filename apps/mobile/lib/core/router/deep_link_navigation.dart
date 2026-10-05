import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Normalizes API `deep_link` paths to registered [GoRoute] locations.
String? normalizeAppDeepLinkPath(String? deepLink) {
  if (deepLink == null || deepLink.trim().isEmpty) return null;
  var path = deepLink.trim();
  if (!path.startsWith('/')) {
    path = '/$path';
  }
  if (path == '/account') {
    path = '/profile';
  } else if (path == '/notifications') {
    path = '/notifications/inbox';
  }
  const allowedPrefixes = [
    '/home',
    '/gallery',
    '/calendar',
    '/registry',
    '/gamification',
    '/profile',
    '/account/',
    '/settings',
    '/baby/',
    '/notifications/',
    '/search',
    '/invite-family',
    '/invite-accept',
  ];
  final ok = allowedPrefixes.any((p) => path == p || path.startsWith(p));
  if (!ok) return null;
  return path;
}

/// Navigate to an in-app path from API `deep_link` values.
void navigateAppDeepLink(BuildContext context, String? deepLink) {
  final path = normalizeAppDeepLinkPath(deepLink);
  if (path == null) return;
  context.push(path);
}
