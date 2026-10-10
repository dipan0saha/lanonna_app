import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../features/home/data/home_refresh_signal.dart';
import '../../features/home/data/selected_baby_store.dart';
import '../../features/shell/shell_branch_index.dart';

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
    '/search',
    '/invite-family',
    '/invite-accept',
  ];
  final ok = allowedPrefixes.any((p) => path == p || path.startsWith(p));
  if (!ok) return null;
  return path;
}

/// Paths under the main tab shell must use [GoRouter.go], not root [GoRouter.push].
bool isShellDeepLinkPath(String path) {
  final uri = Uri.tryParse(path);
  if (uri == null) return false;
  final p = uri.path;
  if (p == '/home' || p.startsWith('/home/')) return true;
  if (p.startsWith('/gallery')) return true;
  if (p.startsWith('/calendar')) return true;
  if (p.startsWith('/registry')) return true;
  if (p.startsWith('/gamification')) return true;
  return false;
}

/// Tab branch for a shell deep link (must match [app_router] branch order).
int? shellBranchIndexForDeepLinkPath(String path) {
  final p = Uri.parse(path).path;
  if (p == '/home' || p.startsWith('/home/')) return ShellBranchIndex.home;
  if (p.startsWith('/gallery')) return ShellBranchIndex.gallery;
  if (p.startsWith('/calendar')) return ShellBranchIndex.calendar;
  if (p.startsWith('/registry')) return ShellBranchIndex.registry;
  if (p.startsWith('/gamification')) return ShellBranchIndex.fun;
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

  if (isShellDeepLinkPath(path)) {
    final shell = StatefulNavigationShell.maybeOf(context);
    final branch = shellBranchIndexForDeepLinkPath(path);
    if (shell != null && branch != null && shell.currentIndex != branch) {
      shell.goBranch(branch, initialLocation: false);
    }
    context.go(path);
  } else {
    context.push(path);
  }
}
