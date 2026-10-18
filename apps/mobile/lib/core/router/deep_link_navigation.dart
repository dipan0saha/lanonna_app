import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../features/home/data/home_refresh_signal.dart';
import '../../features/home/data/selected_baby_store.dart';

/// Normalizes API `deep_link` paths to registered [GoRoute] locations.
String? normalizeAppDeepLinkPath(String? deepLink) {
  if (deepLink == null || deepLink.trim().isEmpty) return null;
  var path = deepLink.trim();
  if (!path.startsWith('/')) {
    path = '/$path';
  }
  if (path == '/account') {
    path = '/profile';
  } else if (path == '/profile/edit') {
    path = '/account/edit';
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
    '/invite-family',
    '/invite-accept',
  ];
  final ok = allowedPrefixes.any((p) => path == p || path.startsWith(p));
  if (!ok) return null;
  return path;
}

/// The main-tab branch that shows [path], or `null` when [path] is not a tab
/// page.
///
/// Read from the route tree itself: a page is a tab page when it renders inside
/// a [StatefulShellBranch] (tab roots and their in-tab children). Drill-down
/// details (photo, event), account pages, the Inbox and the activity feed live
/// on the root navigator and return `null`.
int? tabBranchForLocation(RouteConfiguration configuration, String path) {
  final uri = Uri.tryParse(path);
  if (uri == null) return null;
  final matchList = configuration.findMatch(uri);
  if (matchList.isError || matchList.isEmpty) return null;
  // A page placed on another navigator (the root) is not shown in a tab.
  if (matchList.last.route.parentNavigatorKey != null) return null;
  for (final match in matchList.matches) {
    final route = match.route;
    if (match is! ShellRouteMatch || route is! StatefulShellRoute) continue;
    final branchRoot = match.matches.first.route;
    final index = route.branches.indexWhere(
      (b) => b.routes.contains(branchRoot),
    );
    return index < 0 ? null : index;
  }
  return null;
}

/// Switches selected baby when a notification targets a different profile.
Future<void> ensureDeepLinkBabyContext(
  BuildContext context,
  String? babyProfileId,
) async {
  final id = babyProfileId?.trim();
  if (id == null || id.isEmpty) return;
  final store = context.read<SelectedBabyStore>();
  if (store.selectedBabyId == id) return;
  await store.setSelectedBabyId(id);
  if (!context.mounted) return;
  context.read<HomeRefreshSignal>().notifyBabyContextChanged();
}

/// Navigate to an in-app path from API `deep_link` values.
Future<void> navigateAppDeepLink(
  BuildContext context,
  String? deepLink, {
  String? babyProfileId,
}) async {
  final path = normalizeAppDeepLinkPath(deepLink);
  if (path == null) return;
  await ensureDeepLinkBabyContext(context, babyProfileId);
  if (!context.mounted) return;

  // Tab pages switch tab; everything else opens over the current screen, so
  // Back returns to it (e.g. Inbox -> photo -> Back -> Inbox).
  final branch = tabBranchForLocation(GoRouter.of(context).configuration, path);
  if (branch == null) {
    context.push(path);
    return;
  }
  // Select the branch first so its navigator is built before the location
  // changes (a cold branch would otherwise show an empty body).
  final shell = StatefulNavigationShell.maybeOf(context);
  if (shell != null && shell.currentIndex != branch) {
    shell.goBranch(branch, initialLocation: false);
  }
  context.go(path);
}
